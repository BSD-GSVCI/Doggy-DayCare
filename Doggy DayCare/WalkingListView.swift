import SwiftUI
import SwiftData

struct WalkingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allDogs: [Dog]
    
    private var walkingDogs: [Dog] {
        allDogs.filter { $0.needsWalking && $0.isCurrentlyPresent }
    }
    
    var body: some View {
        List {
            if walkingDogs.isEmpty {
                ContentUnavailableView(
                    "No Dogs Need Walking",
                    systemImage: "pawprint.circle",
                    description: Text("Add dogs that need walking in the main list")
                )
            } else {
                ForEach(walkingDogs) { dog in
                    DogWalkingRow(dog: dog)
                }
            }
        }
        .navigationTitle("Walking List")
    }
}

private struct DogWalkingRow: View {
    @Bindable var dog: Dog
    @State private var showingPottyAlert = false
    
    var body: some View {
        Button {
            showingPottyAlert = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dog.name)
                        .font(.headline)
                    Spacer()
                    Text(dog.formattedStayDuration)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                if let notes = dog.walkingNotes {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "drop.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                        Text("\(dog.peeCount)")
                            .font(.caption)
                    }
                    HStack {
                        Text("💩")
                            .font(.caption)
                            .foregroundColor(.brown)
                        Text("\(dog.poopCount)")
                            .font(.caption)
                    }
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .alert("Record Potty", isPresented: $showingPottyAlert) {
            Button("Peed") {
                dog.addPottyRecord(type: .pee)
            }
            Button("Pooped") {
                dog.addPottyRecord(type: .poop)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("What did \(dog.name) do?")
        }
    }
}

#Preview {
    NavigationStack {
        WalkingListView()
    }
    .modelContainer(for: Dog.self, inMemory: true)
} 