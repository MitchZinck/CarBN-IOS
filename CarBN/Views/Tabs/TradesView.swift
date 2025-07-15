import SwiftUI

struct TradesView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTrade: Trade?
    @State private var selectedFilter: TradeFilter = .all
    
    private var viewModel: TradesViewModel { appState.tradesViewModel }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppConstants.backgroundColor.ignoresSafeArea()
                VStack(alignment: .center, spacing: 0) {
                    filterPicker
                    
                    ScrollView {
                        if viewModel.isLoading && viewModel.trades.isEmpty {
                            ProgressView()
                                .tint(.accentColor)
                                .scaleEffect(1.5)       
                        } else if viewModel.filteredTrades.isEmpty {
                            emptyStateView
                        } else {
                            tradesList
                        }
                    }
                    .refreshable {
                        if AppState.shared.isAuthenticated {
                            await viewModel.refreshTrades()
                        }
                    }
                }
            }
            .navigationTitle("trades.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppConstants.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert("common.error".localized, isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("common.ok".localized) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(item: $selectedTrade) { trade in
                TradeDetailsView(trade: trade, onRespond: { accept in
                    Task {
                        await viewModel.respondToTrade(tradeId: trade.id, accept: accept)
                        selectedTrade = nil
                    }
                })
            }
        }
        .onAppear {
            if AppState.shared.isAuthenticated && viewModel.trades.isEmpty {
                Task {
                    await viewModel.refreshTrades()
                }
            }
        }
    }
    
    private var filterPicker: some View {
        ZStack {
            Picker("trades.filter".localized, selection: Binding(
                get: { viewModel.selectedFilter },
                set: { appState.tradesViewModel.selectedFilter = $0 }
            )) {
                Text("trades.filter.all".localized).tag(TradeFilter.all)
                if viewModel.pendingTradesCount > 0 {
                    Text(String(format: "trades.filter.pending_count".localized, viewModel.pendingTradesCount)).tag(TradeFilter.pending)
                } else {
                    Text("trades.filter.pending".localized).tag(TradeFilter.pending)
                }
                Text("trades.filter.accepted".localized).tag(TradeFilter.accepted)
                Text("trades.filter.declined".localized).tag(TradeFilter.declined)
            }
            .pickerStyle(.segmented)
            .padding()
            .onAppear {
                UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Color.accentColor)
                UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
                UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
            }
        }
    }
    
    private var tradesList: some View {
        LazyVStack(spacing: 16) {
            ForEach(viewModel.filteredTrades) { trade in
                TradeHistoryItemView(trade: trade) { accept in
                    Task {
                        await viewModel.respondToTrade(tradeId: trade.id, accept: accept)
                    }
                }
                .onTapGesture {
                    selectedTrade = trade
                }
            }
            
            if !viewModel.filteredTrades.isEmpty {
                progressView
            }
        }
        .padding(.horizontal)
        .padding(.vertical)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            Text("trades.empty".localized)
                .font(.headline)
                .foregroundStyle(.gray)
            Text("trades.empty.description".localized)
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var progressView: some View {
        HStack {
            Spacer()
            if viewModel.isLoading {
                ProgressView()
                    .tint(.accentColor)
            }
            Spacer()
        }
        .onAppear {
            Task {
                await viewModel.loadMoreTrades()
            }
        }
    }
}
