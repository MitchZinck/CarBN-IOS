import SwiftUI
import Foundation

private struct CarImageView: View {
    let car: Car
    
    var body: some View {
        Group {
            if !car.lowResImageURL.isEmpty {
                CachedAsyncImage(url: URL(string: car.lowResImageURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty, _:
                        placeholderView
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    Text(car.model)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(4)
                        .padding(4),
                    alignment: .bottom
                )
            } else {
                placeholderView
            }
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Image(systemName: "car.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.white.opacity(0.5))
            )
            .aspectRatio(1, contentMode: .fill)
    }
}

struct CarThumbnailView: View {
    let car: Car
    @Environment(CarService.self) private var carService
    @State private var isPressed = false
    @State private var showingDetail = false
    @State private var isVisible = false

    var currentCar: Car {
        carService.userCars.first(where: { $0.userCarId == car.userCarId }) ?? car
    }

    var body: some View {
        VStack(spacing: 4) {
            if isVisible {
                CarImageView(car: currentCar)
            } else {
                Color.gray.opacity(0.2)
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .id(currentCar.userCarId)
        .overlay(RarityBadgeView(rarity: currentCar.rarity ?? 1), alignment: .topLeading)
        .overlay(
            Group {
                if currentCar.hasPremiumImage {
                    Image(systemName: "star.circle.fill")
                        .foregroundStyle(.yellow)
                        .background(Circle().fill(.black))
                        .font(.system(size: 16))
                        .padding(4)
                }
            },
            alignment: .topTrailing
        )
        .scaleEffect(isPressed ? 0.95 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture {
            // Provide tactile feedback
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
                
                // Reset after short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        isPressed = false
                    }
                    
                    // Show detail view after animation
                    showingDetail = true
                }
            }
        }
        .sheet(isPresented: $showingDetail) {
            CarDetailView(car: currentCar)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isVisible = true
            }
        }
        .onDisappear {
            isVisible = false
        }
    }
}
