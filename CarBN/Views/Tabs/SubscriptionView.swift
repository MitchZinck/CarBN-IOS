import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SubscriptionViewModel()
    @State private var selectedTab = 0 // 0 = subscriptions, 1 = scan packs
    
    var body: some View {
        ZStack {
            AppConstants.backgroundColor.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Current subscription status card
                    SubscriptionInfoCard(subscription: viewModel.subscriptionInfo)
                    
                    // Tabs for subscription types
                    Picker("subscription.purchase_type".localized, selection: $selectedTab) {
                        Text("subscription.tab.monthly".localized).tag(0)
                        Text("subscription.tab.scan_packs".localized).tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 300)
                    } else {
                        // Plans display based on selected tab
                        if selectedTab == 0 {
                            monthlySubscriptionOptions
                        } else {
                            scanPackOptions
                        }
                    }
                    
                    // Subscription benefits
                    subscriptionBenefitsView
                }
                .padding()
            }
        }
        .navigationTitle("subscription.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .alert("common.error".localized, isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("common.ok".localized) {}
        } message: {
            Text(viewModel.errorMessage ?? "error.unknown".localized)
        }
        .alert("subscription.alert.success.title".localized, isPresented: .init(
            get: { viewModel.purchaseSuccess },
            set: { viewModel.setPurchaseSuccess($0) }
        )) {
            Button("common.ok".localized) {}
        } message: {
            Text("subscription.alert.success.message".localized)
        }
        .task {
            await viewModel.loadSubscriptionInfo()
            await viewModel.loadProducts()
            
            // Also make sure AppState is updated with subscription info
            if let subscription = viewModel.subscriptionInfo {
                appState.subscription = subscription
            }
        }
        .refreshable {
            await viewModel.refresh()
            // Update AppState with refreshed subscription info
            if let subscription = viewModel.subscriptionInfo {
                appState.subscription = subscription
            }
        }
    }
    
    private var monthlySubscriptionOptions: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.subscriptionProducts.filter { $0.tier != .none }) { product in
                // Highlight the current subscription tier
                let isCurrentSubscription = viewModel.subscriptionInfo?.isActive ?? false && product.tier == viewModel.subscriptionInfo?.tier
                subscriptionCard(
                    product: product,
                    highlight: isCurrentSubscription,
                    isCurrentPlan: isCurrentSubscription
                )
            }
        }
    }
    
    private var scanPackOptions: some View {
        VStack(spacing: 16) {
            if viewModel.scanPackProducts.isEmpty {
                Text("subscription.loading".localized)
                    .foregroundStyle(.gray)
                    .padding(.vertical, 20)
            } else {
                ForEach(viewModel.scanPackProducts) { product in
                    // Highlight the "best value" option (50 credits)
                    let isHighlighted = product.scanCredits == 50
                    scanPackCard(
                        product: product,
                        highlight: isHighlighted
                    )
                }
            }
        }
    }
    
    private func subscriptionCard(
        product: SubscriptionProduct,
        highlight: Bool = false,
        isCurrentPlan: Bool = false
    ) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(product.name)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                
                if isCurrentPlan {
                    Spacer()
                    Text("subscription.current_plan".localized)
                        .font(.caption)
                        .padding(4)
                        .background(Color.green.opacity(0.3))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }
            }
            
            if let storeProduct = product.storeProduct {
                Text(storeProduct.displayPrice + "subscription.month_suffix".localized)
                    .font(.title2.bold())
                    .foregroundStyle(highlight ? .yellow : .white)
            } else {
                Text("subscription.loading".localized)
                    .font(.title2.bold())
                    .foregroundStyle(highlight ? .yellow : .white)
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("subscription.scan_credits_per_month".localizedFormat(product.scanCredits))
                        .foregroundStyle(.white)
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("subscription.features.trading".localized)
                        .foregroundStyle(.white)
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("subscription.features.premium_images".localized)
                        .foregroundStyle(.white)
                    Spacer()
                }
            }
            .padding(.vertical, 8)
            
            if product.storeProduct != nil {
                Button(isCurrentPlan ? "subscription.current_plan".localized : "subscription.button.subscribe".localized) {
                    Task {
                        await viewModel.purchaseSubscription(product: product)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isLoading || isCurrentPlan)
            } else {
                Button("subscription.loading".localized) {}
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(true)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(highlight ? Color.accentColor.opacity(0.2) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(highlight ? Color.yellow : Color.clear, lineWidth: highlight ? 2 : 0)
                )
        )
    }
    
    private func scanPackCard(
        product: SubscriptionProduct,
        highlight: Bool = false
    ) -> some View {
        VStack(spacing: 12) {
            Text(product.name)
                .font(.title3.bold())
                .foregroundStyle(.white)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(product.scanCredits)")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(highlight ? .yellow : .white)
                
                Text("subscription.scan_pack.scans".localized)
                    .font(.title3)
                    .foregroundStyle(.gray)
            }
            
            if let storeProduct = product.storeProduct {
                Text(storeProduct.displayPrice)
                    .font(.title2.bold())
                    .foregroundStyle(highlight ? .yellow : .white)
                
                Button("subscription.button.purchase".localized) {
                    Task {
                        await viewModel.purchaseScanPack(product: product)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isLoading)
            } else {
                Text("subscription.loading".localized)
                    .font(.title2.bold())
                    .foregroundStyle(highlight ? .yellow : .white)
                
                Button("subscription.loading".localized) {}
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(true)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(highlight ? Color.accentColor.opacity(0.2) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(highlight ? Color.yellow : Color.clear, lineWidth: highlight ? 2 : 0)
                )
        )
    }
    
    private var subscriptionBenefitsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("subscription.benefits.title".localized)
                .font(.headline)
                .foregroundStyle(.white)
            
            benefitRow(
                icon: "arrow.left.arrow.right",
                title: "subscription.benefits.trading.title".localized,
                description: "subscription.benefits.trading.description".localized
            )
            benefitRow(
                icon: "photo.fill",
                title: "subscription.benefits.images.title".localized,
                description: "subscription.benefits.images.description".localized
            )
            benefitRow(
                icon: "camera.viewfinder",
                title: "subscription.benefits.scanning.title".localized,
                description: "subscription.benefits.scanning.description".localized
            )
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            
            Spacer()
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.7 : 1))
            .foregroundStyle(.white)
            .font(.headline)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}
