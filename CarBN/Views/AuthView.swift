import SwiftUI
import GoogleSignInSwift
import AuthenticationServices

struct AuthView: View {
    @State private var viewModel = AuthViewModel()
    @Environment(AppState.self) private var appState
    
    var body: some View {
        NavigationStack {
            ZStack {
                Image("Home-Image")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
                    .ignoresSafeArea()
                
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                        .frame(height: 60)
                    
                    HStack(spacing: 0) {
                        Text("CAR")
                            .font(.custom("SF Pro Display", size: 40))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("BN")
                            .font(.custom("SF Pro Display", size: 40))
                            .italic()
                            .fontWeight(.bold)
                            .foregroundColor(Color.accentColor)
                    }
                    .shadow(color: .black, radius: 0, x: 1, y: 1)
                    
                    Text("app.tagline".localized)
                        .font(.custom("SF Pro Display", size: 16))
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 0, x: 1, y: 1)
                    
                    Spacer()
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        VStack(spacing: 12) {
                            SignInButton(
                                text: "auth.signin.google".localized,
                                icon: "google-icon",
                                action: {
                                    Task {
                                        await viewModel.signInWithGoogle()
                                    }
                                }
                            )
                            .frame(maxWidth: 280)
                            
                            SignInButton(
                                text: "auth.signin.apple".localized,
                                icon: "apple.logo",
                                isSystemImage: true,
                                action: {
                                    Task {
                                        await viewModel.signInWithApple()
                                    }
                                }
                            )
                            .frame(maxWidth: 280)
                        }
                    }
                    
                    if let error = viewModel.error {
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    
                    Spacer()
                        .frame(height: 50)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}
