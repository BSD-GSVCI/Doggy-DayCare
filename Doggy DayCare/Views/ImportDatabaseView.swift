import SwiftUI

struct ImportDatabaseView: View {
    let onImport: ([DogWithVisit]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var importData = ""
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var previewDogs: [DogWithVisit] = []
    @State private var showingPreview = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    
                    Text("Import Database")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Paste the exported database data below")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Total dogs count
                if !previewDogs.isEmpty {
                    Text("Total Dogs in Database: \(previewDogs.count)")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                }
                
                // Import data input
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Import Data")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Paste") {
                            if let clipboard = UIPasteboard.general.string {
                                importData = clipboard
                                validateImportData()
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                    
                    TextEditor(text: $importData)
                        .font(.caption.monospaced())
                        .frame(minHeight: 200)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onChange(of: importData) {
                            validateImportData()
                        }
                }
                
                // Preview section
                if !previewDogs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Preview (\(previewDogs.count) dogs)")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("View Details") {
                                showingPreview = true
                            }
                            .font(.caption)
                            .foregroundStyle(.blue)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(previewDogs.prefix(5)) { dog in
                                    VStack(spacing: 4) {
                                        if let profilePictureData = dog.profilePictureData,
                                           let uiImage = UIImage(data: profilePictureData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 40, height: 40)
                                                .clipShape(Circle())
                                        } else {
                                            Image(systemName: "dog")
                                                .font(.title3)
                                                .foregroundStyle(.gray)
                                                .frame(width: 40, height: 40)
                                                .background(.gray.opacity(0.2))
                                                .clipShape(Circle())
                                        }
                                        
                                        Text(dog.name)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                }
                                
                                if previewDogs.count > 5 {
                                    Text("+\(previewDogs.count - 5) more")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 8)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Spacer()
                
                // Import button
                Button {
                    isImporting = true
                    onImport(previewDogs)
                } label: {
                    HStack {
                        if isImporting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text(isImporting ? "Importing..." : "Import Database")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(previewDogs.isEmpty ? Color.gray : Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(previewDogs.isEmpty || isImporting)
            }
            .padding()
            .navigationTitle("Import Database")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPreview) {
                NavigationStack {
                    ImportPreviewView(dogs: previewDogs)
                }
            }
        }
    }
    
    private func validateImportData() {
        guard !importData.isEmpty else {
            previewDogs = []
            errorMessage = nil
            return
        }
        
        do {
            guard let data = importData.data(using: .utf8) else {
                errorMessage = "Invalid data format"
                previewDogs = []
                return
            }
            
            let dogs = try JSONDecoder().decode([DogWithVisit].self, from: data)
            previewDogs = dogs
            errorMessage = nil
        } catch {
            errorMessage = "Invalid import data: \(error.localizedDescription)"
            previewDogs = []
        }
    }
}

struct ImportPreviewView: View {
    let dogs: [DogWithVisit]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(dogs) { dog in
                    HStack(spacing: 12) {
                        // Profile picture
                        if let profilePictureData = dog.profilePictureData,
                           let uiImage = UIImage(data: profilePictureData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "dog")
                                .font(.title2)
                                .foregroundStyle(.gray)
                                .frame(width: 50, height: 50)
                                .background(.gray.opacity(0.2))
                                .clipShape(Circle())
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dog.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            if let ownerName = dog.ownerName {
                                Text("Owner: \(ownerName)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text(dog.isBoarding ? "Boarding" : "Daycare")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(dog.isBoarding ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                                .foregroundStyle(dog.isBoarding ? .blue : .green)
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Import Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ImportDatabaseView { dogs in
        print("Importing \(dogs.count) dogs")
    }
} 