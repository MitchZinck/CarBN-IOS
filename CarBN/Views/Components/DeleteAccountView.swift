// filepath: Views/Components/DeleteAccountView.swift
import SwiftUI
import Foundation

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var confirmationText: String = ""
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSuccessAlert: Bool = false
    @State private var isDeleting: Bool = false

    var body: some View {
        ZStack {
            // Add app background color
            AppConstants.backgroundColor
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Deleting your account is irreversible. All personal data will be removed. Cars will be anonymized.")
                    .padding(.top)
                    .foregroundColor(.white)
                    
                Text("Please type DELETE below to confirm account deletion.")
                    .font(.headline)
                    .foregroundColor(.white)
                    
                TextField("Type DELETE here", text: $confirmationText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    
                Button(role: .destructive) {
                    isDeleting = true
                    Task {
                        await performDelete()
                        isDeleting = false
                    }
                } label: {
                    HStack {
                        Spacer()
                        if isDeleting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Confirm Delete")
                        }
                        Spacer()
                    }
                }
                .disabled(confirmationText != "DELETE" || isDeleting)
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.vertical)
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
            )
            .padding()
        }
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Account Deleted", isPresented: $showSuccessAlert) {
            Button("OK") {
                Task { 
                    // Clear user data and auth tokens
                    await AuthService.shared.forceLogout()
                    
                    // Clear local caches
                    UserManager.shared.clearUser()
                    await UserCache.shared.clearCache()
                    
                    // Return to auth view by setting authenticated state to false
                    await appState.setAuthenticated(false)
                    
                    // Dismiss any modals that might be open
                    dismiss()
                }
            }
        } message: {
            Text("Your account has been successfully deleted.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func performDelete() async {
        // Don't proceed if the confirmation text isn't correct
        guard confirmationText == "DELETE" else {
            await MainActor.run {
                errorMessage = "Please type DELETE to confirm account deletion."
                showErrorAlert = true
            }
            return
        }
        
        struct DeleteConfirmation: Encodable {
            let confirm: Bool
        }
        
        do {
            let _: MessageResponse = try await APIClient.shared.delete(
                endpoint: "/user/account",
                body: DeleteConfirmation(confirm: true)
            )
            await MainActor.run {
                showSuccessAlert = true
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        DeleteAccountView()
            .environment(AppState.shared)
    }
}
