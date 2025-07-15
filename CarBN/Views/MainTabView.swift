// MARK: - MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases) { tab in
                tab.view
                    .tabItem {
                        Label(tab.title, systemImage: tab.systemImage)
                    }
                    .badge(getBadgeCount(for: tab))
                    .tag(tab.rawValue)
            }
        }
        .task {
            // Initial load when view appears
            if appState.isAuthenticated {
                await appState.refreshAllData()
            }
        }
        .onChange(of: appState.isAuthenticated) { wasAuthenticated, isAuthenticated in
            if isAuthenticated {
                Task { await appState.refreshAllData() }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && appState.isAuthenticated {
                Task { await appState.refreshIfNeeded() }
            }
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            // Check if refresh is needed when tab changes
            if appState.isAuthenticated {
                Task {
                    await appState.refreshIfNeeded()
                }
            }
        }
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(AppConstants.backgroundColor)
            
            UITabBar.appearance().scrollEdgeAppearance = appearance
            UITabBar.appearance().standardAppearance = appearance
        }
    }
    
    private func getBadgeCount(for tab: Tab) -> Int {
        switch tab {
        case .friends:
            return appState.friendsViewModel.pendingRequests.filter { request in
                // Only count requests where the current user is the recipient (friendId)
                request.friendId == UserManager.shared.currentUser?.id
            }.count
        case .trades:
            return appState.tradesViewModel.pendingTradesCount
        case .home:
            // Show badge for new likes if we're not currently on the home tab
            if Tab(rawValue: selectedTab) != .home {
                return appState.homeViewModel?.newLikesCount ?? 0
            }
            return 0
        default:
            return 0
        }
    }
}

enum Tab: Int, CaseIterable, Identifiable {
    case home, friends, scan, profile, trades
    
    var id: Int { rawValue }
    
    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .friends: return "person.2.fill"
        case .scan: return "camera.fill"
        case .profile: return "car.fill"
        case .trades: return "arrow.left.arrow.right"
        }
    }
    
    var title: String {
        switch self {
        case .home: return "tab.home".localized
        case .friends: return "tab.friends".localized
        case .profile: return "tab.profile".localized
        case .scan: return "tab.scan".localized
        case .trades: return "tab.trades".localized
        }
    }
    
    @ViewBuilder
    var view: some View {
        switch self {
        case .home: HomeView()
        case .friends: FriendsView()
        case .scan: ScanView()
        case .profile: ProfileView()
        case .trades: TradesView()
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppState.shared)
}
