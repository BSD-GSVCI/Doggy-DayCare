import SwiftUI
import SwiftData

struct FeedingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allDogs: [Dog]
    
    private var feedingDogs: [Dog] {
        allDogs.filter { $0.isCurrentlyPresent }
    }
    
    var body: some View {
        List {
            if feedingDogs.isEmpty {
                ContentUnavailableView(
                    "No Dogs Present",
                    systemImage: "fork.knife.circle",
                    description: Text("Add dogs to the main list")
                )
            } else {
                ForEach(feedingDogs) { dog in
                    DogFeedingRow(dog: dog)
                }
            }
        }
        .navigationTitle("Feeding List")
    }
}

private struct DogFeedingRow: View {
    @Bindable var dog: Dog
    @State private var showingFeedingAlert = false
    
    var body: some View {
        Button {
            showingFeedingAlert = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dog.name)
                        .font(.headline)
                    Text(dog.isDaycareFed ? "Daycare Feeds" : "Own Food")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(dog.isDaycareFed ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                        .clipShape(Capsule())
                    Spacer()
                    Text(dog.formattedStayDuration)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                if let notes = dog.specialInstructions {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "sunrise.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text("\(dog.breakfastCount)")
                            .font(.caption)
                    }
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                        Text("\(dog.lunchCount)")
                            .font(.caption)
                    }
                    HStack {
                        Image(systemName: "sunset.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                        Text("\(dog.dinnerCount)")
                            .font(.caption)
                    }
                    HStack {
                        Image(systemName: "pawprint.fill")
                            .font(.caption)
                            .foregroundStyle(.brown)
                        Text("\(dog.snackCount)")
                            .font(.caption)
                    }
                }
                
                if !dog.feedingRecords.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(dog.feedingRecords.sorted(by: { $0.timestamp > $1.timestamp }).prefix(3), id: \.timestamp) { record in
                            HStack {
                                Image(systemName: iconForFeedingType(record.type))
                                    .font(.caption)
                                    .foregroundStyle(colorForFeedingType(record.type))
                                Text(record.type.rawValue.capitalized)
                                    .font(.caption)
                                Spacer()
                                Text(record.timestamp.formatted(date: .omitted, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .alert("Record Feeding", isPresented: $showingFeedingAlert) {
            Button("Breakfast") {
                dog.addFeedingRecord(type: .breakfast)
            }
            Button("Lunch") {
                dog.addFeedingRecord(type: .lunch)
            }
            Button("Dinner") {
                dog.addFeedingRecord(type: .dinner)
            }
            Button("Snack") {
                dog.addFeedingRecord(type: .snack)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("What did \(dog.name) eat?")
        }
    }
    
    private func iconForFeedingType(_ type: FeedingRecord.FeedingType) -> String {
        switch type {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "sunset.fill"
        case .snack: return "pawprint.fill"
        }
    }
    
    private func colorForFeedingType(_ type: FeedingRecord.FeedingType) -> Color {
        switch type {
        case .breakfast: return .orange
        case .lunch: return .yellow
        case .dinner: return .red
        case .snack: return .brown
        }
    }
}

#Preview {
    NavigationStack {
        FeedingListView()
    }
    .modelContainer(for: Dog.self, inMemory: true)
} 