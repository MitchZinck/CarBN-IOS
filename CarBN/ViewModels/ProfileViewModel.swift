// MARK: - ProfileViewModel.swift
import SwiftUI

@Observable
@MainActor
final class ProfileViewModel {
    private let carService: CarService
    private let userManager: UserManager
    
    var isLoading = false
    var errorMessage: String?
    var currentSort: CarSort = .rarity
    
    var user: User? { userManager.currentUser }
    var cars: [Car] { carService.userCars }
    
    // Pagination-related computed properties
    var hasMoreCars: Bool { carService.hasMoreCars }
    var isLoadingMoreCars: Bool { carService.isFetchingCars }
    private var loadMoreTask: Task<Void, Never>?
    private var lastLoadTime: Date = .distantPast
    
    static func create() async -> ProfileViewModel {
        await MainActor.run {
            ProfileViewModel(
                carService: CarService.shared,
                userManager: UserManager.shared
            )
        }
    }
    
    private init(
        carService: CarService,
        userManager: UserManager
    ) {
        self.carService = carService
        self.userManager = userManager
    }
    
    func loadData() async {
        await loadUser()
        await loadCars()
    }
    
    func loadUser() async {
        do {
            try await userManager.fetchAndUpdateUserDetails()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadCars() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Always fetch cars but only update if there are changes
            let changesDetected = try await carService.fetchAndCompareUsersCars(limit: 20, sort: currentSort)
            
            if changesDetected {
                Logger.info("Car changes detected, updated local cache")
            } else {
                Logger.info("No changes to user cars, using existing data")
                // Just reset pagination tracking without clearing cars
                carService.resetPaginationStateOnly()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
        
    // Add a new method to load more cars when scrolling
    func loadMoreCars() async {
        // Don't attempt fetch if we're already loading or there are no more cars
        guard !isLoadingMoreCars && hasMoreCars else { return }
        
        // Debounce: Don't allow more than one request every 5 seconds
        let now = Date()
        if now.timeIntervalSince(lastLoadTime) < 0.5 {
            return
        }
        
        // Cancel any existing task
        loadMoreTask?.cancel()
        
        // Create a new task
        loadMoreTask = Task {
            do {
                // Set the last load time
                lastLoadTime = Date()
                try await carService.fetchAndAppendUsersCars(limit: 10, sort: currentSort)
            } catch {
                errorMessage = error.localizedDescription
            }
            loadMoreTask = nil
        }
    }
    
    // Add method to update sort option and reload cars
    func updateSortOption(newSort: CarSort) async {
        guard newSort != currentSort else { return }
        
        currentSort = newSort
        
        // Reset pagination state and clear current car list
        carService.resetPaginationState()
        
        // Load cars with the new sort option
        await loadCars()
    }
}
