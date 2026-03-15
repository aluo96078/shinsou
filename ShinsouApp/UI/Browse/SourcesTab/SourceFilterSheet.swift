import SwiftUI
import ShinsouSourceAPI
import ShinsouI18n

// MARK: - Filter State (mutable wrapper around Filter enum)

/// Observable wrapper that holds the current filter states for editing.
@MainActor
final class FilterState: ObservableObject {
    @Published var filters: FilterList

    /// The original (default) filters — used for reset.
    let defaults: FilterList

    init(filters: FilterList) {
        self.filters = filters
        self.defaults = filters
    }

    func reset() {
        filters = defaults
    }

    /// Whether any filter has been modified from its default.
    var isModified: Bool {
        !filtersEqual(filters, defaults)
    }

    // MARK: - Mutators

    func updateSelect(at path: IndexPath, newState: Int) {
        updateFilter(at: path) { filter in
            if case .select(let name, let values, _) = filter {
                return .select(name: name, values: values, state: newState)
            }
            return filter
        }
    }

    func updateText(at path: IndexPath, newState: String) {
        updateFilter(at: path) { filter in
            if case .text(let name, _) = filter {
                return .text(name: name, state: newState)
            }
            return filter
        }
    }

    func updateCheckBox(at path: IndexPath, newState: Bool) {
        updateFilter(at: path) { filter in
            if case .checkBox(let name, _) = filter {
                return .checkBox(name: name, state: newState)
            }
            return filter
        }
    }

    func updateTriState(at path: IndexPath) {
        updateFilter(at: path) { filter in
            if case .triState(let name, let state) = filter {
                let next: Filter.TriStateValue
                switch state {
                case .ignore: next = .include
                case .include: next = .exclude
                case .exclude: next = .ignore
                }
                return .triState(name: name, state: next)
            }
            return filter
        }
    }

    func updateSort(at path: IndexPath, index: Int, ascending: Bool) {
        updateFilter(at: path) { filter in
            if case .sort(let name, let values, _) = filter {
                return .sort(name: name, values: values, selection: Filter.SortSelection(index: index, ascending: ascending))
            }
            return filter
        }
    }

    // MARK: - Private

    /// IndexPath: section = top-level index, row = child index within group (or -1 for top-level)
    private func updateFilter(at path: IndexPath, transform: (Filter) -> Filter) {
        if path.section < filters.count {
            if path.row < 0 {
                filters[path.section] = transform(filters[path.section])
            } else if case .group(let name, var children) = filters[path.section],
                      path.row < children.count {
                children[path.row] = transform(children[path.row])
                filters[path.section] = .group(name: name, filters: children)
            }
        }
    }

    private func filtersEqual(_ a: FilterList, _ b: FilterList) -> Bool {
        guard a.count == b.count else { return false }
        for (fa, fb) in zip(a, b) {
            if !filterEqual(fa, fb) { return false }
        }
        return true
    }

    private func filterEqual(_ a: Filter, _ b: Filter) -> Bool {
        switch (a, b) {
        case (.select(_, _, let sa), .select(_, _, let sb)): return sa == sb
        case (.text(_, let sa), .text(_, let sb)): return sa == sb
        case (.checkBox(_, let sa), .checkBox(_, let sb)): return sa == sb
        case (.triState(_, let sa), .triState(_, let sb)): return sa == sb
        case (.sort(_, _, let sa), .sort(_, _, let sb)): return sa == sb
        case (.group(_, let fa), .group(_, let fb)): return filtersEqual(fa, fb)
        case (.header, .header), (.separator, .separator): return true
        default: return false
        }
    }
}

// MARK: - Filter Sheet View

struct SourceFilterSheet: View {
    @ObservedObject var filterState: FilterState
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(filterState.filters.enumerated()), id: \.offset) { index, filter in
                    FilterRowView(
                        filter: filter,
                        path: IndexPath(row: -1, section: index),
                        filterState: filterState
                    )
                }
            }
            .navigationTitle(MR.strings.actionFilter)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(MR.strings.browseShowAllReset) {
                        filterState.reset()
                    }
                    .disabled(!filterState.isModified)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(MR.strings.commonDone) {
                        onApply()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Filter Row (separate struct to reduce type-checker complexity)

private struct FilterRowView: View {
    let filter: Filter
    let path: IndexPath
    @ObservedObject var filterState: FilterState

    var body: some View {
        makeBody()
    }

    // Use AnyView to avoid complex @ViewBuilder type inference that crashes the compiler
    private func makeBody() -> AnyView {
        switch filter {
        case .header(let name):
            return AnyView(Section(name) { EmptyView() })

        case .separator:
            return AnyView(Divider())

        case .select(let name, let values, let state):
            return AnyView(selectRow(name: name, values: values, state: state))

        case .text(let name, let state):
            return AnyView(textRow(name: name, state: state))

        case .checkBox(let name, let state):
            return AnyView(checkBoxRow(name: name, state: state))

        case .triState(let name, let state):
            return AnyView(triStateRow(name: name, state: state))

        case .sort(let name, let values, let selection):
            return AnyView(sortRow(name: name, values: values, selection: selection))

        case .group(let name, let children):
            return AnyView(groupSection(name: name, children: children))
        }
    }

    // MARK: - Select

    private func selectRow(name: String, values: [String], state: Int) -> some View {
        Picker(name, selection: Binding(
            get: { state },
            set: { filterState.updateSelect(at: path, newState: $0) }
        )) {
            ForEach(Array(values.enumerated()), id: \.offset) { idx, value in
                Text(value).tag(idx)
            }
        }
    }

    // MARK: - Text

    private func textRow(name: String, state: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            TextField(name, text: Binding(
                get: { state },
                set: { filterState.updateText(at: path, newState: $0) }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 200)
            .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - CheckBox

    private func checkBoxRow(name: String, state: Bool) -> some View {
        Toggle(name, isOn: Binding(
            get: { state },
            set: { filterState.updateCheckBox(at: path, newState: $0) }
        ))
    }

    // MARK: - TriState

    private func triStateRow(name: String, state: Filter.TriStateValue) -> some View {
        Button {
            filterState.updateTriState(at: path)
        } label: {
            HStack {
                Text(name)
                    .foregroundStyle(.primary)
                Spacer()
                triStateIcon(state)
            }
        }
    }

    @ViewBuilder
    private func triStateIcon(_ state: Filter.TriStateValue) -> some View {
        switch state {
        case .ignore:
            Image(systemName: "square")
                .foregroundStyle(.secondary)
        case .include:
            Image(systemName: "checkmark.square.fill")
                .foregroundStyle(.green)
        case .exclude:
            Image(systemName: "xmark.square.fill")
                .foregroundStyle(.red)
        }
    }

    // MARK: - Sort

    private func sortRow(name: String, values: [String], selection: Filter.SortSelection?) -> some View {
        Section(name) {
            ForEach(Array(values.enumerated()), id: \.offset) { idx, value in
                Button {
                    let isCurrentIndex = selection?.index == idx
                    let newAscending = isCurrentIndex ? !(selection?.ascending ?? true) : true
                    filterState.updateSort(at: path, index: idx, ascending: newAscending)
                } label: {
                    HStack {
                        Text(value)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selection?.index == idx {
                            Image(systemName: selection?.ascending == true ? "arrow.up" : "arrow.down")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Group

    private func groupSection(name: String, children: [Filter]) -> some View {
        Section(name) {
            ForEach(Array(children.enumerated()), id: \.offset) { childIdx, child in
                FilterRowView(
                    filter: child,
                    path: IndexPath(row: childIdx, section: path.section),
                    filterState: filterState
                )
            }
        }
    }
}
