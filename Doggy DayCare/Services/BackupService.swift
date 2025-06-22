import Foundation
import CloudKit

@Observable
class BackupService {
    static let shared = BackupService()
    
    private init() {}
    
    func exportDogs(_ dogs: [Dog], filename: String? = nil) async throws -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var csvString = "ID,Name,Arrival Date,Departure Date,Is Boarding,Boarding End Date,Is Daycare Fed,Needs Walking,Walking Notes,Special Instructions,Medications,Notes,Feeding Records,Medication Records,Potty Records\n"
        
        for dog in dogs {
            // Format records
            let feedingRecords = dog.feedingRecords.map { record in
                "\(record.type.rawValue)@\(dateFormatter.string(from: record.timestamp))"
            }.joined(separator: "|")
            
            let medicationRecords = dog.medicationRecords.map { record in
                "\(dateFormatter.string(from: record.timestamp))\(record.notes.map { " - \($0)" } ?? "")"
            }.joined(separator: "|")
            
            let pottyRecords = dog.pottyRecords.map { record in
                "\(record.type.rawValue)@\(dateFormatter.string(from: record.timestamp))"
            }.joined(separator: "|")
            
            // Create row values
            let id = dog.id.uuidString
            let name = dog.name
            let arrivalDate = dateFormatter.string(from: dog.arrivalDate)
            let departureDate = dog.departureDate.map { dateFormatter.string(from: $0) } ?? ""
            let isBoarding = String(dog.isBoarding)
            let boardingEndDate = dog.boardingEndDate.map { dateFormatter.string(from: $0) } ?? ""
            let isDaycareFed = String(dog.isDaycareFed)
            let needsWalking = String(dog.needsWalking)
            let walkingNotes = dog.walkingNotes ?? ""
            let specialInstructions = dog.specialInstructions ?? ""
            let medications = dog.medications ?? ""
            let notes = dog.notes ?? ""
            
            // Combine values into row
            let rowValues = [
                id, name, arrivalDate, departureDate, isBoarding, boardingEndDate,
                isDaycareFed, needsWalking, walkingNotes, specialInstructions,
                medications, notes, feedingRecords, medicationRecords, pottyRecords
            ]
            
            // Escape and quote values
            let row = rowValues
                .map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
                .joined(separator: ",")
            
            csvString.append(row + "\n")
        }
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = filename ?? "dogs_export_\(dateFormatter.string(from: Date())).csv"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    private func exportDogToCSV(_ dog: Dog) -> String {
        let walkingNotes = dog.walkingNotes ?? ""
        let medications = dog.medications ?? ""
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