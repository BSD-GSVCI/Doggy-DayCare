import Foundation

actor BackupService {
    static let shared = BackupService()
    private let backupInterval: TimeInterval = 3600 // 1 hour
    private var lastBackupTime: Date?
    
    private init() {}
    
    func exportDogs(_ dogs: [Dog]) async throws -> URL {
        // Create file URL
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "doggy_daycare_backup_\(Date().ISO8601Format()).csv"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        // Create empty file
        try "".write(to: fileURL, atomically: true, encoding: .utf8)
        
        // Create file handle
        guard let fileHandle = try? FileHandle(forWritingTo: fileURL) else {
            throw NSError(domain: "BackupService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create file"])
        }
        defer { try? fileHandle.close() }
        
        // Write header
        let header = "ID,Name,Arrival Date,Departure Date,Needs Walking,Walking Notes,Is Boarding,Special Instructions,Created At,Updated At\n"
        try fileHandle.write(contentsOf: header.data(using: .utf8)!)
        
        // Write each dog's data
        for dog in dogs {
            let row = createRow(for: dog)
            try fileHandle.write(contentsOf: row.data(using: .utf8)!)
        }
        
        lastBackupTime = Date()
        return fileURL
    }
    
    private func createRow(for dog: Dog) -> String {
        var fields: [String] = []
        
        // Add each field with proper escaping
        fields.append(dog.id.uuidString)
        fields.append(escapeCSV(dog.name))
        fields.append(dog.arrivalDate.ISO8601Format())
        fields.append(dog.departureDate?.ISO8601Format() ?? "")
        fields.append(String(dog.needsWalking))
        fields.append(escapeCSV(dog.walkingNotes ?? ""))
        fields.append(String(dog.isBoarding))
        fields.append(escapeCSV(dog.specialInstructions ?? ""))
        fields.append(dog.createdAt.ISO8601Format())
        fields.append(dog.updatedAt.ISO8601Format())
        
        // Join fields and add newline
        return fields.joined(separator: ",") + "\n"
    }
    
    private func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return string
    }
} 