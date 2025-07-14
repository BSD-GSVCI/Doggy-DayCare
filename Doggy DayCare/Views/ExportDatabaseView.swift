import SwiftUI

struct ExportDatabaseView: View {
    let exportData: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    
                    Text("Database Export")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Copy the data below to transfer your database to production")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Export data
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Export Data")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Copy All") {
                            UIPasteboard.general.string = exportData
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                    
                    ScrollView {
                        Text(exportData)
                            .font(.caption.monospaced())
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .frame(maxHeight: 400)
                }
                
                Spacer()
                
                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Instructions:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("1.")
                                .fontWeight(.bold)
                            Text("Copy the export data above")
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("2.")
                                .fontWeight(.bold)
                            Text("Switch to production CloudKit container")
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("3.")
                                .fontWeight(.bold)
                            Text("Go to Database page and use Import feature")
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("4.")
                                .fontWeight(.bold)
                            Text("Paste the export data to import all dogs")
                        }
                    }
                    .font(.subheadline)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .navigationTitle("Export Database")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: exportData) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

#Preview {
    ExportDatabaseView(exportData: "{\"test\": \"data\"}")
} 