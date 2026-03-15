import SwiftUI
import ShinsouDomain
import ShinsouI18n

struct MangaNotesSheet: View {
    @ObservedObject var viewModel: MangaDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draftText: String = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $draftText)
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            }
            .navigationTitle(MR.strings.mangaNotes)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(MR.strings.commonCancel) { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            isSaving = true
                            await viewModel.saveNotes(draftText)
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(MR.strings.commonSave)
                                .bold()
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .onAppear {
            draftText = viewModel.manga?.notes ?? ""
        }
    }
}
