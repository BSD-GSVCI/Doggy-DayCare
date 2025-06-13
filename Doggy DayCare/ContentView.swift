//
//  ContentView.swift
//  Doggy DayCare
//
//  Created by Behnam Soleimani Darinsoo on 6/10/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor(\Dog.departureDate, order: .forward),
        SortDescriptor(\Dog.name, order: .forward)
    ]) private var allDogs: [Dog]
    @State private var showingAddDog = false
    @State private var showingWalkingList = false
    @State private var showingMedicationsList = false
    @State private var showingExportSheet = false
    @State private var exportError: Error?
    @State private var exportURL: URL?
    @State private var searchText = ""
    
    private var filteredDogs: [Dog] {
        if searchText.isEmpty {
            return allDogs
        } else {
            return allDogs.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var daycareDogs: [Dog] {
        filteredDogs.filter { !$0.isBoarding }
    }
    
    private var boardingDogs: [Dog] {
        filteredDogs.filter { $0.isBoarding }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if daycareDogs.isEmpty {
                        Text("No daycare dogs present")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(daycareDogs) { dog in
                            DogRow(dog: dog)
                        }
                    }
                } header: {
                    Text("Daycare")
                }
                .listSectionSpacing(20)
                
                Section {
                    if boardingDogs.isEmpty {
                        Text("No boarding dogs present")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(boardingDogs) { dog in
                            DogRow(dog: dog)
                        }
                    }
                } header: {
                    Text("Boarding")
                }
            }
            .searchable(text: $searchText, prompt: "Search dogs by name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingAddDog = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        NavigationLink {
                            WalkingListView()
                        } label: {
                            Image(systemName: "figure.walk")
                        }
                        
                        NavigationLink {
                            FeedingListView()
                        } label: {
                            Image(systemName: "fork.knife")
                        }
                        
                        NavigationLink {
                            MedicationsListView()
                        } label: {
                            Image(systemName: "pills")
                        }
                        
                        Menu {
                            Button {
                                Task {
                                    await exportData()
                                }
                            } label: {
                                Label("Export Data", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddDog) {
                DogFormView()
            }
            .sheet(isPresented: $showingExportSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Export Error", isPresented: .constant(exportError != nil)) {
                Button("OK") {
                    exportError = nil
                }
            } message: {
                if let error = exportError {
                    Text(error.localizedDescription)
                }
            }
        }
    }

    private func exportData() async {
        do {
            let url = try await BackupService.shared.exportDogs(allDogs)
            exportURL = url
            showingExportSheet = true
        } catch {
            exportError = error
        }
    }
}

private struct DogRow: View {
    let dog: Dog
    
    var body: some View {
        NavigationLink {
            DogDetailView(dog: dog)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dog.name)
                        .font(.headline)
                    if dog.needsWalking {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(.blue)
                    }
                    if dog.medications != nil && !dog.medications!.isEmpty {
                        Image(systemName: "pills")
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    if dog.departureDate != nil {
                        Text(dog.formattedStayDuration)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text(dog.arrivalDate.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.green.opacity(0.8))
                
                if let departureDate = dog.departureDate {
                    Text(departureDate.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.red.opacity(0.8))
                }
                
                HStack {
                    Text(dog.isBoarding ? "Boarding" : "Daycare")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(dog.isBoarding ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                        .clipShape(Capsule())
                    
                    if dog.isBoarding, let boardingEndDate = dog.boardingEndDate {
                        Text("Until \(boardingEndDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    
                    if dog.isDaycareFed {
                        Text("Daycare Feeds")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
        .modelContainer(for: Dog.self, inMemory: true)
}
