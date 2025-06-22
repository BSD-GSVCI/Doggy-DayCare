import SwiftUI

struct DogSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @State private var searchText = ""
    @State private var selectedFilter: SearchFilter = .all
    
    enum SearchFilter {
        case all
        case present
        case departed
        case future
    }
    
    private var filteredDogs: [Dog] {
        let dogs = dataManager.dogs
        
        let filtered = dogs.filter { dog in
            if !searchText.isEmpty {
                return dog.name.localizedCaseInsensitiveContains(searchText) ||
                       (dog.ownerName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
            return true
        }
        
        switch selectedFilter {
        case .all:
            return filtered
        case .present:
            return filtered.filter { $0.isCurrentlyPresent }
        case .departed:
            return filtered.filter { $0.departureDate != nil }
        case .future:
            return filtered.filter { 
                Calendar.current.startOfDay(for: $0.arrivalDate) > Calendar.current.startOfDay(for: Date())
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter buttons
                HStack(spacing: 12) {
                    FilterButton(title: "All", isSelected: selectedFilter == .all) {
                        selectedFilter = .all
                    }
                    
                    FilterButton(title: "Present", isSelected: selectedFilter == .present) {
                        selectedFilter = .present
                    }
                    
                    FilterButton(title: "Departed", isSelected: selectedFilter == .departed) {
                        selectedFilter = .departed
                    }
                    
                    FilterButton(title: "Future", isSelected: selectedFilter == .future) {
                        selectedFilter = .future
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Results list
                List {
                    if filteredDogs.isEmpty {
                        ContentUnavailableView {
                            Label("No Dogs Found", systemImage: "magnifyingglass")
                        } description: {
                            Text("Try adjusting your search or filter.")
                        }
                    } else {
                        ForEach(filteredDogs) { dog in
                            DogSearchRow(dog: dog)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search dogs by name or owner")
            .navigationTitle("Search Dogs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DogSearchRow: View {
    let dog: Dog
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dog.name)
                    .font(.headline)
                Spacer()
                Text(dateFormatter.string(from: dog.arrivalDate))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if let ownerName = dog.ownerName {
                Text("Owner: \(ownerName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text(dog.isBoarding ? "Boarding" : "Daycare")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(dog.isBoarding ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                    .foregroundStyle(dog.isBoarding ? .orange : .blue)
                    .clipShape(Capsule())
                
                Spacer()
                
                if dog.isCurrentlyPresent {
                    Text("Present")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if dog.departureDate != nil {
                    Text("Departed")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("Future")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

#Preview {
    DogSearchView()
        .environmentObject(DataManager.shared)
} 