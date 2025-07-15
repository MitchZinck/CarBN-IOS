import SwiftUI

enum TradeFilter {
    case all
    case pending
    case accepted
    case declined
}

@Observable
@MainActor
final class TradesViewModel {
    private(set) var trades: [Trade] = []
    private(set) var isLoading = false
    var errorMessage: String?
    var showError = false
    var selectedFilter: TradeFilter = .all
    private var isRefreshing = false // Add this flag

    private var currentPage = 1
    private var hasMorePages = true
    private let pageSize = 20
    private let tradeService: TradeService
    private let subscriptionService: SubscriptionService
    
    var pendingTradesCount: Int {
        trades.filter { $0.status == .pending }.count
    }
    
    @MainActor
    init() {
        self.tradeService = TradeService.shared
        self.subscriptionService = SubscriptionService.shared
        setupNotifications()
    }
    
    init(tradeService: TradeService) {
        self.tradeService = tradeService
        self.subscriptionService = SubscriptionService.shared
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTradeCreated),
            name: TradeService.tradeCreatedNotification,
            object: nil
        )
    }
    
    @objc private func handleTradeCreated() {
        Task {
            await refreshTrades()
        }
    }
    
    var filteredTrades: [Trade] {
        let filtered = switch selectedFilter {
            case .all:
                trades
            case .pending:
                trades.filter { $0.status == .pending }
            case .accepted:
                trades.filter { $0.status == .accepted }
            case .declined:
                trades.filter { $0.status == .declined }
        }
        return filtered.sorted { trade1, trade2 in
            return (trade1.tradedAt ?? trade1.createdAt) > (trade2.tradedAt ?? trade2.createdAt)
        }
    }
    
    func loadInitialTrades() async {
        // This can be called on init or auth change if needed
        guard trades.isEmpty else { return }
        await refreshTrades()
    }
    
    func refreshTrades() async {
        guard !isRefreshing else {
            Logger.info("Skipping refreshTrades: already refreshing")
            return
        }

        isRefreshing = true
        Logger.info("Refreshing trades...")
        
        // Reset state
        currentPage = 1
        trades = []
        hasMorePages = true
        errorMessage = nil
        
        do {
            // Directly fetch trades instead of calling loadMoreTrades()
            let response = try await tradeService.fetchTradeHistory(page: currentPage, pageSize: pageSize)
            trades = response.trades
            hasMorePages = trades.count < response.totalCount
            if hasMorePages {
                currentPage += 1
            }
            Logger.info("Loaded trades. Total: \(trades.count), HasMore: \(hasMorePages)")
        } catch {
            if (error as? URLError)?.code != .cancelled {
                errorMessage = error.localizedDescription
                Logger.error("Failed to load trades: \(error)")
            } else {
                Logger.info("Trade loading cancelled.")
            }
        }
        
        isRefreshing = false
        Logger.info("Refresh complete.")
    }
    
    func loadMoreTrades() async {
        // Prevent loading more if already loading/refreshing or no more pages
        guard !isLoading && !isRefreshing && hasMorePages else {
            Logger.info("Skipping loadMoreTrades: isLoading=\(isLoading), isRefreshing=\(isRefreshing), hasMorePages=\(hasMorePages)")
            return
        }

        isLoading = true
        defer { isLoading = false }

        Logger.info("Loading more trades, page: \(currentPage)")
        do {
            let response = try await tradeService.fetchTradeHistory(page: currentPage, pageSize: pageSize)
            trades.append(contentsOf: response.trades) // Simplified append
            hasMorePages = trades.count < response.totalCount
            if hasMorePages {
                currentPage += 1
            }
            Logger.info("Loaded trades. Total: \(trades.count), HasMore: \(hasMorePages)")
        } catch {
            // Avoid setting error if it was just a cancellation
            if (error as? URLError)?.code != .cancelled {
                errorMessage = error.localizedDescription
                Logger.error("Failed to load trades: \(error)")
            } else {
                Logger.info("Trade loading cancelled.")
            }
        }
    }
    
    func respondToTrade(tradeId: Int, accept: Bool) async {
        // Only check subscription if accepting the trade
        if accept {
            let subscription = try? await subscriptionService.getSubscriptionInfo()
            guard let subscription = subscription, subscription.isActive else {
                errorMessage = "You need an active subscription to accept trades"
                showError = true
                return
            }
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await tradeService.respondToTrade(tradeId: tradeId, accept: accept)
            // Update the local state immediately
            if let index = trades.firstIndex(where: { $0.id == tradeId }) {
                let existingTrade = trades[index]
                trades[index] = Trade(
                    id: existingTrade.id,
                    fromUserId: existingTrade.fromUserId,
                    toUserId: existingTrade.toUserId,
                    status: accept ? TradeStatus.accepted : TradeStatus.declined,
                    fromUserCarIds: existingTrade.fromUserCarIds,
                    toUserCarIds: existingTrade.toUserCarIds,
                    createdAt: existingTrade.createdAt,
                    tradedAt: accept ? Date() : existingTrade.tradedAt
                )
            }
            
            // Refresh the trades list in the background
            Task {
                await refreshTrades()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            Logger.error("Failed to respond to trade: \(error)")
        }
    }
    
    func clearTrades() {
        trades = []
        currentPage = 1
        hasMorePages = true
        isLoading = false
        errorMessage = nil
        showError = false
        // No user cache clearing needed as we're relying on backend caching
    }
}
