import SwiftUI

struct TabBarItem: View {
    let systemName: String
    let title: String
    
    var body: some View {
        VStack {
            Image(systemName: systemName)
            Text(title)
        }
    }
}
