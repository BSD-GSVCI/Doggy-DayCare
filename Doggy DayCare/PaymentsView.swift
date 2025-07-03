import SwiftUI

struct PaymentsView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var authService = AuthenticationService.shared
    
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    ContentUnavailableView {
                        Label("Payments Coming Soon", systemImage: "dollarsign.circle")
                    } description: {
                        Text("Payment management features will be available here.")
                    }
                }
            }
            .navigationTitle("Payments")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search payments")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // TODO: Add payment functionality
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
    }
}

#Preview {
    PaymentsView()
        .environmentObject(DataManager.shared)
} 