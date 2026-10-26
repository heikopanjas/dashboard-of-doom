import SwiftUI

struct GridView: View {
    let items = ["Item 1", "Item 2", "Item 3", "Item 4", "Item 5", "Item 6"]

    // Define two columns with flexible width
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .frame(height: 60)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
    }
}
