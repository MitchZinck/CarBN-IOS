import SwiftUI

struct TradeHistoryItemView: View {
    let trade: Trade
    let onRespond: (Bool) -> Void
    private let currentUserId = UserManager.shared.currentUser?.id
    @State private var viewModel = TradeHistoryItemViewModel()
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    statusBadge
                    UserNameButton(
                        name: viewModel.fromUser?.displayName,
                        userId: trade.fromUserId,
                        currentUserId: currentUserId
                    )
                    Label("", systemImage: "arrow.left.arrow.right")
                    .foregroundStyle(Color.accentColor)
                    .background(Color.accentColor.opacity(0))
                    UserNameButton(
                        name: viewModel.toUser?.displayName,
                        userId: trade.toUserId,
                        currentUserId: currentUserId
                    )
                }
                tradeCarsSection(
                    title: "trade.history.offering".localized,
                    count: trade.fromUserCarIds.count
                )
                
                tradeCarsSection(
                    title: "trade.history.requesting".localized,
                    count: trade.toUserCarIds.count
                )
                if trade.status == .accepted, let tradedAt = trade.tradedAt {
                    Text("trade.history.traded".localizedFormat(tradedAt.timeAgo()))
                        .font(.caption)
                        .foregroundStyle(.green.opacity(0.8))
                } else {
                    Text(trade.createdAt.timeAgo())
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                if trade.status == .pending {
                    tradeActions
                }
            }
        }
        .task() {
            await viewModel.loadUsers(trade: trade)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var statusBadge: some View {
        Text(trade.status.rawValue.capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(.white)
            .background(trade.status.color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func tradeCarsSection(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            Text("\(count)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
    }
    
    private var tradeActions: some View {
        HStack(spacing: 16) {
            Button {
                onRespond(false)
            } label: {
                Text("trade.action.decline".localized)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if trade.fromUserId != currentUserId {
                Button {
                    onRespond(true)
                } label: {
                    Text("trade.action.accept".localized)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}
