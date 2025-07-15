import SwiftUI

struct TradeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Bindable private var viewModel: TradeViewModel
    let friendId: Int
    let friendName: String
    let friendCars: [Car]
    private let currentUserId = UserManager.shared.currentUser?.id

    init(friendId: Int, friendName: String, friendCars: [Car]) {
        self.friendId = friendId
        self.friendName = friendName
        self.friendCars = friendCars
        self.viewModel = TradeViewModel(toUserId: friendId)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppConstants.backgroundColor.ignoresSafeArea()
                
                if let subscription = appState.subscription, !subscription.isActive {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.yellow)
                            
                        Text("trade.subscription.required".localized)
                            .font(.title2)
                            .foregroundStyle(.white)
                            
                        Text("trade.subscription.message".localized)
                            .font(.body)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Your cars section
                            tradeSectionContainer(
                                title: "trade.new.your_cars".localized,
                                subtitle: viewModel.fromUserSelectedCars.isEmpty ? nil :
                                    "trade.new.offering".localizedFormat(viewModel.fromUserSelectedCars.count),
                                cars: viewModel.yourCars,
                                selectedCars: viewModel.fromUserSelectedCars,
                                fromUser: true
                            )
                            .padding(.top, 4)
                            
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
                            .padding(.vertical, 16)
                            .padding(.horizontal)
                            
                            // Friend's cars section
                            tradeSectionContainer(
                                title: "trade.new.cars_from".localized,
                                username: friendName,
                                userId: friendId,
                                subtitle: viewModel.toUserSelectedCars.isEmpty ? nil :
                                    "trade.new.requesting".localizedFormat(viewModel.toUserSelectedCars.count),
                                cars: friendCars,
                                selectedCars: viewModel.toUserSelectedCars,
                                fromUser: false
                            )
                            
                            // Submit button
                            Button {
                                Task {
                                    await viewModel.submitTrade()
                                    dismiss()
                                }
                            } label: {
                                Text("trade.new.submit".localized)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        viewModel.isLoading || 
                                        (viewModel.fromUserSelectedCars.isEmpty && viewModel.toUserSelectedCars.isEmpty)
                                        ? Color.accentColor.opacity(0.5)
                                        : Color.accentColor
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(
                                viewModel.isLoading || 
                                (viewModel.fromUserSelectedCars.isEmpty && viewModel.toUserSelectedCars.isEmpty)
                            )
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationTitle("trade.new.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppConstants.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
            }
            .alert("common.error".localized, isPresented: $viewModel.showError) {
                Button("common.ok".localized) { viewModel.showError = false }
            } message: {
                Text(viewModel.errorMessage ?? "trade.error.unknown".localized)
            }
            .task {
                // Only refresh subscription since cars are loaded in viewModel init
                await appState.refreshSubscription()
            }
        }
    }
    
    private func tradeSectionContainer(
        title: String,
        username: String? = nil,
        userId: Int? = nil,
        subtitle: String?,
        cars: [Car],
        selectedCars: Set<Car>,
        fromUser: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    if let username = username, let userId = userId {
                        UserNameButton(
                            name: username,
                            userId: userId,
                            currentUserId: currentUserId
                        )
                    }
                }
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.horizontal)
            
            if fromUser && viewModel.isLoadingCars {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            } else if cars.isEmpty {
                Text("No cars available")
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            } else {
                TradeCarSelectionView(
                    cars: cars,
                    selectedCars: fromUser ? viewModel.fromUserSelectedCars : viewModel.toUserSelectedCars,
                    onCarSelected: { car in
                        viewModel.toggleCarSelection(car: car, fromUser: fromUser)
                    }
                )
                .frame(height: 200)
            }
        }
    }
}
