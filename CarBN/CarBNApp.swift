// CarBNApp.swift
import SwiftUI
import GoogleSignIn

@main
struct CarBNApp: App {
    @State private var appState = AppState.shared

    init() {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: APIConstants.googleClientId
        )
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isAuthenticated {
                    MainTabView()
                } else {
                    AuthView()
                }
            }
            .environment(appState)
            .environment(CarService.shared)
            .task {
                // Validate auth status on app launch
                appState.validateAuthStatus()
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}