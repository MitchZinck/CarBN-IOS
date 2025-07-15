import SwiftUI
import UIKit
import SafariServices

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var selectedLanguage: String = ""
    @State private var showRestartAlert = false
    @State private var navigateToSubscription = false
    @State private var isInitialAppearance = true
    
    // Add all languages your app supports
    private let languages = [
        ("en", "settings.english".localized),
        ("ru", "settings.russian".localized),
        ("uk", "settings.ukrainian".localized),
        ("es", "settings.spanish".localized),
    ]
    
    private func handleLogout() async {
        do {
            try await AuthService.shared.logout()
            Logger.info("[SettingsView] Logout completed successfully")
        } catch {
            Logger.error("[SettingsView] Logout failed: \(error)")
        }
    }
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        // Use modern UIKit approach to present Safari VC
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            let safariVC = SFSafariViewController(url: url)
            rootViewController.present(safariVC, animated: true)
        }
    }
    
    var body: some View {
        ZStack {
            // Background that extends behind the navigation bar
            AppConstants.backgroundColor
                .ignoresSafeArea()
            
            List {
                Section(header: Text("settings.app_settings".localized)
                            .foregroundColor(.white)) {
                    
                    // Language selection
                    Picker("settings.language".localized, selection: $selectedLanguage) {
                        ForEach(languages, id: \.0) { code, name in
                            Text(name).tag(code)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                    .foregroundColor(.white)
                    .tint(.white)
                    .onChange(of: selectedLanguage) { oldValue, newValue in
                        if !isInitialAppearance && oldValue != newValue {
                            // Save the language preference first
                            LocalizationManager.shared.setLanguage(newValue)
                            UserDefaults.standard.set(newValue, forKey: "app_language")
                            appState.currentLanguage = newValue
                            
                            // Show restart alert
                            showRestartAlert = true
                        }
                    }
                                    
                    // Link to subscription using NavigationLink directly
                    NavigationLink(destination: LazyView(SubscriptionView())) {
                        HStack {
                            if let subscription = appState.subscription, subscription.isActive {
                                Label("settings.manage_subscription".localized, systemImage: "star.circle")
                                Spacer()
                                Text("PRO")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            } else {
                                Label("settings.get_subscription".localized, systemImage: "star.circle")
                                Spacer()
                            }
                        }
                        .foregroundColor(.white)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
                
                Section(header: Text("Legal")
                            .foregroundColor(.white)) {
                    Button {
                        openURL("https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                    } label: {
                        HStack {
                            Label("End User License Agreement", systemImage: "doc.text")
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                    
                    Button {
                        openURL("https://carbn-test-01.mzinck.com/privacypolicy.html")
                    } label: {
                        HStack {
                            Label("Privacy Policy", systemImage: "hand.raised")
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
                
                Section {
                    Button(role: .destructive) {
                        Task {
                            await handleLogout()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("auth.logout".localized, systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
                
                // Add danger zone for account deletion
                Section(header: Text("settings.danger_zone".localized)
                            .foregroundColor(.white)) {
                    NavigationLink {
                        DeleteAccountView()
                    } label: {
                        HStack {
                            Spacer()
                            Label("settings.delete_account".localized, systemImage: "trash")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
            }
            .scrollContentBackground(.hidden) // Hide default list background
            .listStyle(.insetGrouped)
        }
        .navigationTitle("settings.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Initialize selectedLanguage after view appears and appState is available
            selectedLanguage = appState.currentLanguage
            // After a brief delay, mark initial appearance as complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInitialAppearance = false
            }
        }
        .alert("settings.language_changed".localized, isPresented: $showRestartAlert) {
            Button("settings.restart".localized) {
                exitApp()
            }
        } message: {
            Text("settings.restart_required".localized)
        }
    }
    
    private func exitApp() {
        // This will exit the app and return to the home screen
        UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
        // A small delay before exiting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exit(0)
        }
    }
    
    private var subscriptionSettingsView: some View {
        // Placeholder for subscription settings
        Text("Subscription Settings Content")
            .navigationTitle("settings.subscription".localized)
    }
}

// Helper to lazily load views that might cause hanging
struct LazyView<Content: View>: View {
    let build: () -> Content
    
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    
    var body: Content {
        build()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AppState.shared)
    }
}