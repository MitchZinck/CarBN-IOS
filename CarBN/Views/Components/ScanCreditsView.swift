import SwiftUI

struct ScanCreditsView: View {
    @Environment(AppState.self) private var appState
    var compact: Bool = false
    var showSubscribeButton: Bool = true
    @State private var navigateToSubscription = false
    
    var body: some View {
        VStack(spacing: compact ? 4 : 8) {
            HStack(spacing: 6) {
                Image(systemName: "camera.viewfinder")
                    .font(compact ? .body : .title3)
                
                Text("\(appState.subscription?.scanCreditsRemaining ?? 0)")
                    .font(compact ? .body.bold() : .title3.bold())
                
                Text("scan.credits".localized)
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.gray)
                
                if !compact {
                    Spacer()
                }
                
                if showSubscribeButton && (appState.subscription?.scanCreditsRemaining ?? 0) < 5 {
                    Button {
                        navigateToSubscription = true
                    } label: {
                        Text("scan.get_more".localized)
                            .font(compact ? .caption : .subheadline)
                            .padding(.horizontal, compact ? 6 : 10)
                            .padding(.vertical, compact ? 2 : 4)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            
            if !compact && (appState.subscription?.scanCreditsRemaining ?? 0) < 5 {
                Text("scan.credits.low".localized)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(compact ? 8 : 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .navigationDestination(isPresented: $navigateToSubscription) {
            SubscriptionView()
        }
    }
}