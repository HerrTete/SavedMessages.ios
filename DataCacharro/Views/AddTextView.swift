import SwiftUI

struct AddTextView: View {
    @EnvironmentObject var storage: StorageService
    @Environment(\.dismiss) var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding()
                .navigationTitle("Add Text")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            if !text.isEmpty {
                                storage.addTextItem(text: text)
                            }
                            dismiss()
                        }
                        .disabled(text.isEmpty)
                    }
                }
        }
    }
}
