import SwiftUI

struct SubscriptionRequiredView: View {
    @Environment(AppState.self) private var appState
    @State private var navigateToSubscription = false
    var title: String
    var message: String
    var icon: String = "lock.fill"
    var showSubscribeButton: Bool = true
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(.gray)
                    .padding(.bottom, 4)
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
            
            if showSubscribeButton {
                Button {
                    navigateToSubscription = true
                } label: {
                    Text(appState.subscription?.isActive == true 
                         ? "subscription.upgrade".localized 
                         : "subscription.subscribe_now".localized)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.top, 8)
                }
                .padding(.horizontal, 32)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .navigationDestination(isPresented: $navigateToSubscription) {
            SubscriptionView()
        }
    }
}