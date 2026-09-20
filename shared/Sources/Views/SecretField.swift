import DoomKitSecrets
import SwiftUI

/// A settings row for one secret: a field to paste a key into, a button to store it and one to remove it. The value is never shown once
/// stored; the row only says that something is there.
struct SecretField: View {
    let label: String
    let key: SecretKey
    var store: any SecretStore = AppSecrets.shared

    @State private var draft = ""
    @State private var isStored = false
    @State private var failure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SecureField(self.label, text: self.$draft)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                Button("Save") {
                    self.save()
                }
                .disabled(self.draft.isEmpty == true)
                if self.isStored == true {
                    Button("Remove", role: .destructive) {
                        self.remove()
                    }
                }
            }
            HStack {
                Text(self.status)
                    .font(.footnote)
                    .foregroundColor(self.failure == nil ? .gray : .red)
                Spacer()
            }
        }
        .onAppear {
            self.isStored = self.store.contains(self.key)
        }
    }

    private var status: String {
        if let failure = self.failure {
            return failure
        }
        return self.isStored == true ? "A key is stored in the keychain and syncs to your other devices." : "No key stored."
    }

    private func save() -> Void {
        do {
            try self.store.write(self.draft, for: self.key)
            self.draft = ""
            self.isStored = true
            self.failure = nil
        }
        catch {
            self.failure = "The key could not be stored: \(error)"
        }
    }

    private func remove() -> Void {
        do {
            try self.store.delete(self.key)
            self.isStored = false
            self.failure = nil
        }
        catch {
            self.failure = "The key could not be removed: \(error)"
        }
    }
}
