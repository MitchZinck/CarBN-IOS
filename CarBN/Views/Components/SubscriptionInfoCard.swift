import SwiftUI

struct SubscriptionInfoCard: View {
    var subscription: SubscriptionInfo?
    var compact: Bool = false
    
    var body: some View {
        VStack(spacing: compact ? 8 : 12) {
            // Subscription status
            if let subscription = subscription, subscription.isActive {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("subscription.info.active".localized)
                            .font(compact ? .subheadline : .headline)
                            .foregroundStyle(.white)
                        
                        Text(formattedExpirationDate)
                            .font(compact ? .caption : .subheadline)
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                    ProBadgeView()
                }
            }
            
            // Scan credits
            HStack {
                Image(systemName: "camera.viewfinder")
                    .font(compact ? .body : .title2)
                    .foregroundStyle(.white)
                
                Text("subscription.info.scans_available".localizedFormat(scanCreditsRemaining))
                    .font(compact ? .subheadline : .title3)
                    .foregroundStyle(.white)
                
                Spacer()
            }
        }
        .padding(compact ? 12 : 16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var scanCreditsRemaining: Int {
        return subscription?.scanCreditsRemaining ?? 0
    }
    
    private var formattedExpirationDate: String {
        guard let expirationDate = subscription?.subscriptionEnd else {
            return "subscription.info.not_subscribed".localized
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "subscription.info.expires".localizedFormat(formatter.string(from: expirationDate))
    }
}
