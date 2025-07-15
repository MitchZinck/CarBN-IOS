import SwiftUI

struct TradeDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    let trade: Trade
    let onRespond: (Bool) -> Void
    @State private var viewModel = TradeDetailsViewModel()
    private let currentUserId = UserManager.shared.currentUser?.id
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppConstants.backgroundColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // From user cars
                        if !viewModel.fromUserCars.isEmpty {
                            tradeSectionView(
                                title: "trade.details.offered_by".localized,
                                username: viewModel.fromUser?.displayName,
                                userId: trade.fromUserId,
                                cars: viewModel.fromUserCars
                            )
                        }
                        
                        // Divider with exchange icon
                        HStack {
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 1)
                            
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.title3)
                                .foregroundStyle(.gray)
                                .padding(.horizontal, 8)
                            
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 1)
                        }
                        .padding(.horizontal)
                        
                        // To user cars
                        if !viewModel.toUserCars.isEmpty {
                            tradeSectionView(
                                title: "trade.details.requested_from".localized,
                                username: viewModel.toUser?.displayName,
                                userId: trade.toUserId,
                                cars: viewModel.toUserCars
                            )
                        }
                        
                        if trade.status == .pending {
                            if let subscription = appState.subscription, !subscription.isActive {
                                VStack(spacing: 12) {
                                    Text("trade.details.subscription_required".localized)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    
                                    Text("trade.details.subscription_message".localized)
                                        .font(.subheadline)
                                        .foregroundStyle(.gray)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                            } else {
                                tradeActions
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("trade.details.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppConstants.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("trade.close".localized) {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .task {
                await viewModel.loadTradeDetails(trade: trade)
                await appState.refreshSubscription()
            }
        }
    }
    
    private func tradeSectionView(title: String, username: String?, userId: Int, cars: [Car]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                UserNameButton(
                    name: username,
                    userId: userId,
                    currentUserId: currentUserId
                )
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(cars, id: \.userCarId) { car in
                        CarThumbnailView(car: car)
                            .frame(width: 120, height: 160)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var tradeActions: some View {
        HStack(spacing: 16) {
            Button(role: .destructive) {
                onRespond(false)
                dismiss()
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
                    dismiss()
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
        .padding(.horizontal)
    }
}
