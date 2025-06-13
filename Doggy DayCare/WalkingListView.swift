import SwiftUI
import SwiftData

struct WalkingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var dogs: [Dog]
    @State private var searchText = ""
    
    private var walkingDogs: [Dog] {
        dogs.filter { $0.needsWalking }
    }
    
    private var filteredDogs: [Dog] {
        if searchText.isEmpty {
            return walkingDogs
        } else {
            return walkingDogs.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var presentDogs: [Dog] {
        filteredDogs.filter { $0.isCurrentlyPresent }
    }
    
    var body: some View {
        List {
            if filteredDogs.isEmpty {
                ContentUnavailableView {
                    Label("No Dogs Found", systemImage: "magnifyingglass")
                } description: {
                    if searchText.isEmpty {
                        Text("Add dogs that need walking in their details")
                    } else {
                        Text("No dogs match \"\(searchText)\"")
                    }
                }
            } else {
                ForEach(presentDogs) { dog in
                    DogWalkingSection(dog: dog, showingPottyAlert: showingPottyAlert, modelContext: modelContext)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search dogs by name")
        .navigationTitle("Walking List")
        .navigationBarTitleDisplayMode(.inline)
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
    
    @State private var showingPottyAlert = false
    @State private var selectedDog: Dog?
    
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

private struct DogWalkingSection: View {
    let dog: Dog
    let showingPottyAlert: (Dog) -> Void
    let modelContext: ModelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                showingPottyAlert(dog)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(dog.name)
                            .font(.headline)
                            .textCase(.none)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(.yellow)
                        Text("\(dog.peeCount)")
                        Text("💩")
                        Text("\(dog.poopCount)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    if let notes = dog.walkingNotes {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            let columns = [
                GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 8)
            ]
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(dog.pottyRecords.sorted(by: { $0.timestamp > $1.timestamp })) { record in
                    PottyRecordGridItem(dog: dog, record: record, modelContext: modelContext)
                }
            }
            .padding(.leading, 4)
        }
    }
}

private struct PottyRecordGridItem: View {
    let dog: Dog
    let record: PottyRecord
    let modelContext: ModelContext
    
    @State var showingEditAlert = false
    @State var showingDeleteAlert = false
    @State var selectedType: PottyRecord.PottyType?
    
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
    
    func deleteRecord() {
        if let index = dog.pottyRecords.firstIndex(where: { $0.timestamp == record.timestamp }) {
            dog.pottyRecords.remove(at: index)
            try? modelContext.save()
        }
    }
    
    func updateRecord(type: PottyRecord.PottyType) {
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