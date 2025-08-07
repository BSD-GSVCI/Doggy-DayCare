import Foundation
import CloudKit

@Observable
class BackupService {
    static let shared = BackupService()
    
    private init() {}
    
    func exportDogs(_ dogs: [DogWithVisit], filename: String? = nil, to backupFolderURL: URL? = nil) async throws -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yy"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        
        // Add BOM (Byte Order Mark) for better Excel compatibility
        let bom = "\u{FEFF}"
        var csvString = bom + "Number,Dog Name,Owner Name,Arrival Date & Time,Departure Date & Time,Service Type,Boarding End Date,Stay Duration,Needs Walking,Walking Notes,Medications,Special Instructions,Allergies & Feeding Instructions,Is Daycare Fed,Notes,Feeding Records,Medication Records,Potty Records\n"
        
        for (index, dog) in dogs.enumerated() {
            // Format dates properly
            let arrivalDateString: String
            if dog.isArrivalTimeSet {
                arrivalDateString = "\(dateFormatter.string(from: dog.arrivalDate)) at \(timeFormatter.string(from: dog.arrivalDate))"
            } else {
                arrivalDateString = "\(dateFormatter.string(from: dog.arrivalDate)) - No arrival time set"
            }
            
            let departureDateString = dog.departureDate != nil ? 
                "\(dateFormatter.string(from: dog.departureDate!)) at \(timeFormatter.string(from: dog.departureDate!))" : ""
            
            let boardingEndDateString = dog.boardingEndDate != nil ? 
                dateFormatter.string(from: dog.boardingEndDate!) : ""
            
            let serviceType = dog.isBoarding ? "Boarding" : "Daycare"
            
            // Calculate stay duration using the improved formatted properties
            let stayDuration: String
            if dog.departureDate != nil {
                // For departed dogs, use the formatted stay duration
                stayDuration = dog.formattedStayDuration
            } else {
                // For current dogs, use the current stay duration
                stayDuration = dog.formattedCurrentStayDuration
            }
            
            // Format records in a readable way
            let feedingRecords = dog.feedingRecords.map { record in
                "\(record.type.rawValue) at \(timeFormatter.string(from: record.timestamp))"
            }.joined(separator: "; ")
            
            let medicationRecords = dog.medicationRecords.map { record in
                let base = timeFormatter.string(from: record.timestamp)
                if let notes = record.notes, !notes.isEmpty {
                    return "\(base) - \(notes)"
                } else {
                    return base
                }
            }.joined(separator: "; ")
            
            let pottyRecords = dog.pottyRecords.map { record in
                "\(record.type.rawValue) at \(timeFormatter.string(from: record.timestamp))"
            }.joined(separator: "; ")
            
            // Create row values in DogDetailView order
            let rowValues: [String] = [
                String(index + 1), // Add row number (starting from 1)
                dog.name,
                dog.ownerName ?? "",
                arrivalDateString,
                departureDateString,
                serviceType,
                boardingEndDateString,
                stayDuration,
                dog.needsWalking ? "Yes" : "No",
                dog.walkingNotes ?? "",
                dog.medications.map(\.name).joined(separator: ", "),
                dog.specialInstructions ?? "",
                dog.allergiesAndFeedingInstructions ?? "",
                dog.isDaycareFed ? "Yes" : "No",
                dog.notes ?? "",
                feedingRecords.isEmpty ? "None" : feedingRecords,
                medicationRecords.isEmpty ? "None" : medicationRecords,
                pottyRecords.isEmpty ? "None" : pottyRecords
            ]
            
            // Escape and quote values properly for CSV
            let row = rowValues
                .map { value in
                    let escapedValue = value.replacingOccurrences(of: "\"", with: "\"\"")
                    return "\"\(escapedValue)\""
                }
                .joined(separator: ",")
            
            csvString.append(row + "\n")
        }
        
        // Create a clean filename without invalid characters
        let cleanDateFormatter = DateFormatter()
        cleanDateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let cleanDateString = cleanDateFormatter.string(from: Date())
        let fileName = filename ?? "DoggyDayCare_Export_\(cleanDateString).csv"
        
        let fileURL: URL
        if let backupFolderURL = backupFolderURL {
            // Use the selected backup folder
            fileURL = backupFolderURL.appendingPathComponent(fileName)
        } else {
            // Use the default documents directory
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            fileURL = documentsDirectory.appendingPathComponent(fileName)
        }
        
        // Write with UTF-8 encoding and ensure proper line endings
        let data = csvString.data(using: .utf8)!
        try data.write(to: fileURL, options: .atomic)
        
        // Set proper file attributes for better compatibility
        let attributesToSet: [FileAttributeKey: Any] = [
            .posixPermissions: 0o644,  // Read/write for owner, read for others
            .type: FileAttributeType.typeRegular
        ]
        try FileManager.default.setAttributes(attributesToSet, ofItemAtPath: fileURL.path)
        
        // Verify the file was created successfully
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw NSError(domain: "BackupService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export file"])
        }
        
        // Verify the file is readable
        guard FileManager.default.isReadableFile(atPath: fileURL.path) else {
            throw NSError(domain: "BackupService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Export file is not readable"])
        }
        
        // Get file attributes to verify it's not empty
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = fileAttributes[FileAttributeKey.size] as? Int64 ?? 0
        
        print("✅ File created successfully at: \(fileURL.path)")
        print("✅ File size: \(fileSize) bytes")
        print("✅ File type: CSV with UTF-8 BOM for Excel compatibility")
        print("✅ File permissions: \(fileAttributes[FileAttributeKey.posixPermissions] ?? "unknown")")
        
        if fileSize == 0 {
            throw NSError(domain: "BackupService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Export file is empty"])
        }
        
        // For manual exports, copy to temporary directory for better sharing
        if backupFolderURL == nil {
            let tempDirectory = FileManager.default.temporaryDirectory
            let tempFileName = "DoggyDayCare_Export_\(cleanDateString).csv"
            let tempFileURL = tempDirectory.appendingPathComponent(tempFileName)
            
            try FileManager.default.copyItem(at: fileURL, to: tempFileURL)
            
            print("✅ File copied to temp directory: \(tempFileURL.path)")
            return tempFileURL
        } else {
            // For automatic backups, return the original file URL
            return fileURL
        }
    }
    
    private func exportDogToCSV(_ dog: DogWithVisit) -> String {
        let walkingNotes = dog.walkingNotes ?? ""
        let medications = dog.medications.map(\.name).joined(separator: ", ")
        let specialInstructions = dog.specialInstructions ?? ""
        
        return [
            dog.id.uuidString,
            dog.name,
            dog.arrivalDate.formatted(date: .numeric, time: .shortened),
            dog.departureDate?.formatted(date: .numeric, time: .shortened) ?? "",
            String(dog.isBoarding),
            dog.boardingEndDate?.formatted(date: .numeric, time: .omitted) ?? "",
            medications,
            specialInstructions,
            String(dog.needsWalking),
            walkingNotes,
            String(dog.isDaycareFed),
            dog.updatedAt.formatted(date: .numeric, time: .shortened)
        ].map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
            .joined(separator: ",")
    }
} 