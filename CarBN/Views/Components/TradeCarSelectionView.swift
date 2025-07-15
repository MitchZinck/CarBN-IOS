import SwiftUI

struct TradeCarSelectionView: View {
    @Environment(AppState.self) private var appState
    let cars: [Car]
    let selectedCars: Set<Car>
    let onCarSelected: (Car) -> Void
    @State private var showSubscriptionAlert = false
    
    // Card dimensions that work well across different screen sizes
    private let cardWidth: CGFloat = UIScreen.main.bounds.width * 0.4
    private let cardHeight: CGFloat = 180
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            LazyHStack(spacing: 12) {
                ForEach(cars, id: \.userCarId) { car in
                    VStack {
                        CarThumbnailView(car: car)
                            .frame(width: cardWidth, height: cardHeight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedCars.contains { $0.userCarId == car.userCarId } ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                            .overlay(
                                Button {
                                    handleCarSelection(car)
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(selectedCars.contains { $0.userCarId == car.userCarId } ? Color.accentColor : Color.gray.opacity(0.4))
                                            .frame(width: 44, height: 44) // Increased touch target
                                        Image(systemName: selectedCars.contains { $0.userCarId == car.userCarId } ? "checkmark" : "plus")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .padding(8),
                                alignment: .topTrailing
                            )
                    }
                    .contentShape(Rectangle()) // Make entire card tappable
                    .onTapGesture {
                        handleCarSelection(car)
                    }
                    .saturation(selectedCars.contains { $0.userCarId == car.userCarId } ? 1.0 : 0.7)
                    .scaleEffect(selectedCars.contains { $0.userCarId == car.userCarId } ? 1.0 : 0.95)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedCars.contains { $0.userCarId == car.userCarId })
                }
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.visible)
        .alert("Subscription Required", isPresented: $showSubscriptionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You need an active subscription to trade cars")
        }
    }
    
    private func handleCarSelection(_ car: Car) {
        guard let subscription = appState.subscription, subscription.isActive else {
            showSubscriptionAlert = true
            return
        }
        
        withAnimation {
            onCarSelected(car)
        }
    }
}

// Custom button style for better touch feedback
struct CarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
