import SwiftUI
import MihonSourceAPI

// MARK: - SourcePreferencesScreen

/// Dynamically renders the preferences for a ConfigurableSource.
/// Each preference is stored in UserDefaults under the key prefix `source.<sourceId>.`.
struct SourcePreferencesScreen: View {
    private let source: any ConfigurableSource

    /// Resolved preference definitions from the source.
    private let preferences: [SourcePreference]

    init(source: any ConfigurableSource) {
        self.source = source
        self.preferences = source.getPreferenceDefinitions()
    }

    var body: some View {
        List {
            if preferences.isEmpty {
                Section {
                    Text("This source has no configurable preferences.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(Array(preferences.enumerated()), id: \.offset) { _, pref in
                    preferenceRow(for: pref)
                }
            }
        }
        .navigationTitle("\(source.name) Preferences")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Row builder

    @ViewBuilder
    private func preferenceRow(for preference: SourcePreference) -> some View {
        switch preference {
        case let .toggle(key, title, summary, defaultValue):
            TogglePreferenceRow(
                storageKey: prefKey(key),
                title: title,
                summary: summary,
                defaultValue: defaultValue
            )

        case let .textField(key, title, summary, defaultValue):
            TextFieldPreferenceRow(
                storageKey: prefKey(key),
                title: title,
                summary: summary,
                defaultValue: defaultValue
            )

        case let .select(key, title, entries, entryValues, defaultValue):
            SelectPreferenceRow(
                storageKey: prefKey(key),
                title: title,
                entries: entries,
                entryValues: entryValues,
                defaultValue: defaultValue
            )

        case let .multiSelect(key, title, entries, entryValues, defaultValues):
            MultiSelectPreferenceRow(
                storageKey: prefKey(key),
                title: title,
                entries: entries,
                entryValues: entryValues,
                defaultValues: defaultValues
            )
        }
    }

    // MARK: - Key builder

    /// Namespaces a preference key under `source.<id>.` to avoid collisions.
    private func prefKey(_ key: String) -> String {
        "source.\(source.id).\(key)"
    }
}

// MARK: - Toggle Row

private struct TogglePreferenceRow: View {
    let storageKey: String
    let title: String
    let summary: String
    let defaultValue: Bool

    @State private var value: Bool

    init(storageKey: String, title: String, summary: String, defaultValue: Bool) {
        self.storageKey = storageKey
        self.title = title
        self.summary = summary
        self.defaultValue = defaultValue
        _value = State(initialValue: UserDefaults.standard.object(forKey: storageKey) as? Bool ?? defaultValue)
    }

    var body: some View {
        Toggle(isOn: $value) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: value) { newValue in
            UserDefaults.standard.set(newValue, forKey: storageKey)
        }
    }
}

// MARK: - TextField Row

private struct TextFieldPreferenceRow: View {
    let storageKey: String
    let title: String
    let summary: String
    let defaultValue: String

    @State private var value: String
    @FocusState private var isFocused: Bool

    init(storageKey: String, title: String, summary: String, defaultValue: String) {
        self.storageKey = storageKey
        self.title = title
        self.summary = summary
        self.defaultValue = defaultValue
        _value = State(initialValue: UserDefaults.standard.string(forKey: storageKey) ?? defaultValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.body)
            if !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TextField(defaultValue, text: $value)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: value) { newValue in
                    UserDefaults.standard.set(newValue, forKey: storageKey)
                }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Select Row

private struct SelectPreferenceRow: View {
    let storageKey: String
    let title: String
    let entries: [String]
    let entryValues: [String]
    let defaultValue: String

    @State private var selectedValue: String

    init(
        storageKey: String,
        title: String,
        entries: [String],
        entryValues: [String],
        defaultValue: String
    ) {
        self.storageKey = storageKey
        self.title = title
        self.entries = entries
        self.entryValues = entryValues
        self.defaultValue = defaultValue
        _selectedValue = State(
            initialValue: UserDefaults.standard.string(forKey: storageKey) ?? defaultValue
        )
    }

    private var selectedLabel: String {
        if let idx = entryValues.firstIndex(of: selectedValue), idx < entries.count {
            return entries[idx]
        }
        return selectedValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.body)
            Picker(title, selection: $selectedValue) {
                ForEach(Array(zip(entries, entryValues)), id: \.1) { label, value in
                    Text(label).tag(value)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .padding(.vertical, 2)
        .onChange(of: selectedValue) { newValue in
            UserDefaults.standard.set(newValue, forKey: storageKey)
        }
    }
}

// MARK: - MultiSelect Row

private struct MultiSelectPreferenceRow: View {
    let storageKey: String
    let title: String
    let entries: [String]
    let entryValues: [String]
    let defaultValues: Set<String>

    @State private var selectedValues: Set<String>

    init(
        storageKey: String,
        title: String,
        entries: [String],
        entryValues: [String],
        defaultValues: Set<String>
    ) {
        self.storageKey = storageKey
        self.title = title
        self.entries = entries
        self.entryValues = entryValues
        self.defaultValues = defaultValues

        let stored = UserDefaults.standard.array(forKey: storageKey) as? [String]
        _selectedValues = State(initialValue: stored.map(Set.init) ?? defaultValues)
    }

    var body: some View {
        NavigationLink {
            MultiSelectDetailView(
                title: title,
                entries: entries,
                entryValues: entryValues,
                selectedValues: $selectedValues
            )
            .onChange(of: selectedValues) { newValues in
                UserDefaults.standard.set(Array(newValues), forKey: storageKey)
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var summaryText: String {
        let selected = entryValues.enumerated()
            .filter { selectedValues.contains($0.element) }
            .map { entries[$0.offset] }
        if selected.isEmpty { return "None selected" }
        return selected.joined(separator: ", ")
    }
}

private struct MultiSelectDetailView: View {
    let title: String
    let entries: [String]
    let entryValues: [String]
    @Binding var selectedValues: Set<String>

    var body: some View {
        List {
            ForEach(Array(zip(entries, entryValues)), id: \.1) { label, value in
                Button {
                    if selectedValues.contains(value) {
                        selectedValues.remove(value)
                    } else {
                        selectedValues.insert(value)
                    }
                } label: {
                    HStack {
                        Text(label)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedValues.contains(value) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
