import SwiftUI
import SwiftData

struct WalkingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var dogs: [Dog]
    @State private var searchText = ""
    @State private var showingPottyAlert = false
    @State private var selectedDog: Dog?
    
    private var walkingDogs: [Dog] {
        let presentDogs = filteredDogs.filter { dog in
            let isPresent = dog.isCurrentlyPresent
            let isArrivingToday = Calendar.current.isDateInToday(dog.arrivalDate)
            let hasArrived = Calendar.current.dateComponents([.hour, .minute], from: dog.arrivalDate).hour != 0 ||
                            Calendar.current.dateComponents([.hour, .minute], from: dog.arrivalDate).minute != 0
            let isFutureBooking = Calendar.current.startOfDay(for: dog.arrivalDate) > Calendar.current.startOfDay(for: Date())
            
            return (isPresent || (isArrivingToday && !hasArrived)) && !isFutureBooking && dog.needsWalking
        }
        return presentDogs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var daycareDogs: [Dog] {
        walkingDogs.filter { !$0.isBoarding }
    }
    
    private var boardingDogs: [Dog] {
        walkingDogs.filter { $0.isBoarding }
    }
    
    private var filteredDogs: [Dog] {
        if searchText.isEmpty {
            return dogs
        } else {
            return dogs.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if walkingDogs.isEmpty {
                    ContentUnavailableView(
                        "No Dogs Need Walking",
                        systemImage: "figure.walk",
                        description: Text("Enable walking for dogs in the main list")
                    )
                } else {
                    Section {
                        if daycareDogs.isEmpty {
                            Text("No daycare dogs need walking")
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            ForEach(daycareDogs) { dog in
                                DogWalkingRow(dog: dog, showingPottyAlert: showingPottyAlert(for:))
                            }
                        }
                    } header: {
                        Text("Daycare")
                    }
                    .listSectionSpacing(20)
                    
                    Section {
                        if boardingDogs.isEmpty {
                            Text("No boarding dogs need walking")
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            ForEach(boardingDogs) { dog in
                                DogWalkingRow(dog: dog, showingPottyAlert: showingPottyAlert(for:))
                            }
                        }
                    } header: {
                        Text("Boarding")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search dogs by name")
            .navigationTitle("Walking List")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Record Potty", isPresented: $showingPottyAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Pee") {
                if let dog = selectedDog {
                    addPottyRecord(for: dog, type: .pee)
                }
            }
            Button("Poop") {
                if let dog = selectedDog {
                    addPottyRecord(for: dog, type: .poop)
                }
            }
        } message: {
            if let dog = selectedDog {
                Text("What did \(dog.name) do?")
            }
        }
    }
    
    private func showingPottyAlert(for dog: Dog) {
        selectedDog = dog
        showingPottyAlert = true
    }
    
    private func addPottyRecord(for dog: Dog, type: PottyRecord.PottyType) {
        let record = PottyRecord(timestamp: Date(), type: type)
        dog.pottyRecords.append(record)
        try? modelContext.save()
    }
}

private struct DogWalkingRow: View {
    @Environment(\.modelContext) private var modelContext
    let dog: Dog
    let showingPottyAlert: (Dog) -> Void
    @State private var showingEditAlert = false
    @State private var showingDeleteAlert = false
    @State private var selectedRecord: PottyRecord?
    @State private var selectedType: PottyRecord.PottyType?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                showingPottyAlert(dog)
            } label: {
                HStack {
                    Text(dog.name)
                        .font(.headline)
                    if dog.needsWalking {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(.blue)
                    }
                    Spacer()
                    Text(dog.formattedStayDuration)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.yellow)
                    Text("\(dog.peeCount)")
                }
                HStack {
                    Text("💩")
                    Text("\(dog.poopCount)")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            if let notes = dog.walkingNotes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if !dog.pottyRecords.isEmpty {
                let columns = [
                    GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 8)
                ]
                
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(dog.pottyRecords.sorted(by: { $0.timestamp > $1.timestamp }), id: \.timestamp) { record in
                        PottyRecordGridItem(dog: dog, record: record, modelContext: modelContext)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PottyRecordGridItem: View {
    let dog: Dog
    let record: PottyRecord
    let modelContext: ModelContext
    
    @State private var showingEditAlert = false
    @State private var showingDeleteAlert = false
    @State private var selectedType: PottyRecord.PottyType?
    
    var body: some View {
        HStack(spacing: 4) {
            if record.type == .pee {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.yellow)
            } else {
                Text("💩")
            }
            
            Text(record.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Menu {
                Button {
                    selectedType = record.type == .pee ? .poop : .pee
                    showingEditAlert = true
                } label: {
                    Label("Change Type", systemImage: "arrow.triangle.2.circlepath")
                }
                
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(6)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .alert("Delete Record", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteRecord()
            }
        } message: {
            Text("Are you sure you want to delete this record?")
        }
        .alert("Change Record Type", isPresented: $showingEditAlert) {
            Button("Cancel", role: .cancel) { }
            if let type = selectedType {
                Button("Change to \(type == .pee ? "Pee" : "Poop")") {
                    updateRecord(type: type)
                }
            }
        } message: {
            if let type = selectedType {
                Text("Change this record to \(type == .pee ? "pee" : "poop")?")
            }
        }
    }
    
    private func deleteRecord() {
        if let index = dog.pottyRecords.firstIndex(where: { $0.timestamp == record.timestamp }) {
            dog.pottyRecords.remove(at: index)
            try? modelContext.save()
        }
    }
    
    private func updateRecord(type: PottyRecord.PottyType) {
        if let index = dog.pottyRecords.firstIndex(where: { $0.timestamp == record.timestamp }) {
            dog.pottyRecords[index].type = type
            try? modelContext.save()
        }
    }
}

#Preview {
    NavigationStack {
        WalkingListView()
    }
    .modelContainer(for: Dog.self, inMemory: true)
} 