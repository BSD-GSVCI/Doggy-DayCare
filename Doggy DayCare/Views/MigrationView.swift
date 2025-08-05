import SwiftUI

struct MigrationView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var isMigrationInProgress = false
    @State private var showingMigrationAlert = false
    @State private var migrationError: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    
                    Text("Persistent Dog Migration")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("This will migrate your existing dog data to the new persistent dog system for better performance and scalability.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Migration Status
                if dataManager.isMigrationComplete() {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)
                        
                        Text("Migration Complete!")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                        
                        Text("Your data has been successfully migrated to the new system.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if isMigrationInProgress {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text(dataManager.getMigrationStatus())
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        ProgressView(value: dataManager.getMigrationProgress())
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(height: 8)
                        
                        Text("\(Int(dataManager.getMigrationProgress() * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    // Migration Info
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What will be migrated:")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                MigrationInfoRow(icon: "dog", text: "All existing dog records")
                                MigrationInfoRow(icon: "calendar", text: "Visit history and activity records")
                                MigrationInfoRow(icon: "pills", text: "Medication and vaccination data")
                                MigrationInfoRow(icon: "fork.knife", text: "Feeding and potty records")
                                MigrationInfoRow(icon: "person", text: "Owner information and contact details")
                            }
                        }
                        .padding()
                        .background(.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Benefits after migration:")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                MigrationInfoRow(icon: "speedometer", text: "Faster app performance")
                                MigrationInfoRow(icon: "chart.line.uptrend.xyaxis", text: "Better scalability")
                                MigrationInfoRow(icon: "person.2", text: "Customer-centric data model")
                                MigrationInfoRow(icon: "shield.checkered", text: "Improved data integrity")
                            }
                        }
                        .padding()
                        .background(.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                
                Spacer()
                
                // Action Button
                if !dataManager.isMigrationComplete() {
                    Button(action: {
                        showingMigrationAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Start Migration")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isMigrationInProgress)
                    .opacity(isMigrationInProgress ? 0.6 : 1.0)
                } else {
                    Button(action: {
                        // Navigate back or show completion message
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Migration Complete")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding()
            .navigationTitle("Data Migration")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Start Migration?", isPresented: $showingMigrationAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Start Migration") {
                    startMigration()
                }
            } message: {
                Text("This will migrate all your existing dog data to the new persistent dog system. This process cannot be undone. Make sure you have a backup before proceeding.")
            }
            .alert("Migration Error", isPresented: .constant(migrationError != nil)) {
                Button("OK") {
                    migrationError = nil
                }
            } message: {
                if let error = migrationError {
                    Text(error)
                }
            }
        }
    }
    
    private func startMigration() {
        isMigrationInProgress = true
        
        Task {
            do {
                try await dataManager.performMigration()
                await MainActor.run {
                    isMigrationInProgress = false
                }
            } catch {
                await MainActor.run {
                    isMigrationInProgress = false
                    migrationError = error.localizedDescription
                }
            }
        }
    }
}

struct MigrationInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
                .frame(width: 16)
            
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer()
        }
    }
}

#Preview {
    MigrationView()
        .environmentObject(DataManager.shared)
} 