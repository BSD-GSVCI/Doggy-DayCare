import SwiftUI

struct NoInternetView: View {
    @ObservedObject var networkService = NetworkConnectivityService.shared
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon
            Image(systemName: "wifi.slash")
                .font(.system(size: 80))
                .foregroundStyle(.red)
                .symbolEffect(.bounce, options: .repeating)
            
            // Title
            Text("No Internet Connection")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            VStack(spacing: 16) {
                Text("Doggy DayCare requires an internet connection to sync your data with CloudKit.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("This ensures that all your data is safely backed up and synchronized across your devices.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("Please connect to the internet to continue using the app.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Connection status
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(networkService.isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    Text(networkService.isConnected ? "Connected" : "Disconnected")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                if networkService.connectionType != .unknown {
                    HStack(spacing: 8) {
                        Image(systemName: "network")
                            .foregroundStyle(.blue)
                        Text("Connection type: \(networkService.connectionType.displayName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 10)
            
            Spacer()
            
            // Retry button (optional, for UX)
            Button(action: {
                // The network service will automatically detect when connection is restored
                // This button provides a way for users to manually check
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Check Connection")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding()
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(networkService.isConnected)
            .opacity(networkService.isConnected ? 0.6 : 1.0)
            
            // Connection restored message
            if networkService.isConnected {
                Text("Connection restored! Loading app...")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.top, 10)
            }
            
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

#Preview {
    NoInternetView()
} 