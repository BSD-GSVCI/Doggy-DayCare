import SwiftUI

struct DeleteLogView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var disappearedDogs: [Dog] = []
    @State private var isLoading = false
    @State private var searchText = ""
    
    private var filteredDisappearedDogs: [Dog] {
        if searchText.isEmpty {
            return disappearedDogs
        } else {
            return disappearedDogs.filter { dog in
                dog.name.localizedCaseInsensitiveContains(searchText) ||
                (dog.ownerName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title and refresh at the very top
            HStack {
                Text("Delete Logs")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    Task { await refreshDisappearedDogs() }
                } label: {
                    if isLoading {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 4)
            
            if isLoading {
                ProgressView("Loading disappeared dogs...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if disappearedDogs.isEmpty {
                ContentUnavailableView {
                    Label("No Disappeared Dogs", systemImage: "archivebox")
                } description: {
                    Text("No dogs have disappeared from the database.")
                }
            } else {
                VStack(spacing: 0) {
                    Text("Total Disappeared Dogs: \(disappearedDogs.count)")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                    List {
                        ForEach(filteredDisappearedDogs) { dog in
                            HStack(alignment: .top, spacing: 12) {
                                DogProfilePicture(dog: dog, size: 48)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(dog.name)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            if let ownerName = dog.ownerName {
                                                Text("Owner: \(ownerName)")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing) {
                                            Text("Disappeared")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.red.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Arrival: \(dog.arrivalDate.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if let departureDate = dog.departureDate {
                                            Text("Departure: \(departureDate.formatted(date: .abbreviated, time: .shortened))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Text("Last Modified: \(dog.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search disappeared dogs")
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDisappearedDogs(useCache: true)
        }
        .imageOverlay() // For profile picture zoom
    }
    
    private func loadDisappearedDogs(useCache: Bool) async {
        await MainActor.run { isLoading = true }
        if useCache {
            // Use cache if available
            if dataManager.allDogs.isEmpty {
                await dataManager.fetchAllDogsIncludingDeleted()
            }
        } else {
            // Always fetch incremental changes
            await dataManager.fetchAllDogsIncremental()
        }
        // Compute disappeared dogs: in allDogs but not in dogs
        let presentDogIDs = Set(dataManager.dogs.map { $0.id })
        let disappeared = dataManager.allDogs.filter { !presentDogIDs.contains($0.id) }
        await MainActor.run {
            self.disappearedDogs = disappeared.sorted { $0.updatedAt > $1.updatedAt }
            self.isLoading = false
        }
    }
    
    private func refreshDisappearedDogs() async {
        await loadDisappearedDogs(useCache: false)
    }
}

#Preview {
    NavigationStack {
        DeleteLogView()
            .environmentObject(DataManager.shared)
    }
} 