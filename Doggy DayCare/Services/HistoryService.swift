import Foundation

@MainActor
class HistoryService: ObservableObject {
    static let shared = HistoryService()
    
    @Published var historyRecords: [DogHistoryRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let userDefaults = UserDefaults.standard
    private let historyKey = "dog_history_records"
    
    private init() {
        loadHistoryRecords()
    }
    
    // MARK: - History Management
    
    func recordDailySnapshot(dogs: [DogWithVisit]) {
        let today = Calendar.current.startOfDay(for: Date())
        
        // Remove any existing records for today
        historyRecords.removeAll { Calendar.current.isDate($0.date, inSameDayAs: today) }
        
        // Create new records for all dogs
        let newRecords = dogs.map { dog in
            DogHistoryRecord(from: dog, date: today)
        }
        
        historyRecords.append(contentsOf: newRecords)
        saveHistoryRecords()
        
        print("📅 Recorded daily snapshot for \(newRecords.count) dogs on \(today)")
    }
    
    func getHistoryForDate(_ date: Date) -> [DogHistoryRecord] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return historyRecords.filter { record in
            record.date >= startOfDay && record.date < endOfDay
        }.sorted { $0.dogName.localizedCaseInsensitiveCompare($1.dogName) == .orderedAscending }
    }
    
    func getAvailableDates() -> [Date] {
        let dates = Set(historyRecords.map { Calendar.current.startOfDay(for: $0.date) })
        return Array(dates).sorted(by: >)
    }
    
    func getHistoryForDog(_ dogId: UUID) -> [DogHistoryRecord] {
        return historyRecords
            .filter { $0.dogId == dogId }
            .sorted { $0.date > $1.date }
    }
    
    func getPresentDogsForDate(_ date: Date) -> [DogHistoryRecord] {
        return getHistoryForDate(date).filter { $0.isCurrentlyPresent }
    }
    
    func getBoardingDogsForDate(_ date: Date) -> [DogHistoryRecord] {
        return getHistoryForDate(date).filter { $0.isBoarding }
    }
    
    func getDaycareDogsForDate(_ date: Date) -> [DogHistoryRecord] {
        return getHistoryForDate(date).filter { !$0.isBoarding }
    }
    
    func getDepartedDogsForDate(_ date: Date) -> [DogHistoryRecord] {
        return getHistoryForDate(date).filter { $0.departureDate != nil }
    }
    
    // MARK: - Data Persistence
    
    private func saveHistoryRecords() {
        do {
            let data = try JSONEncoder().encode(historyRecords)
            userDefaults.set(data, forKey: historyKey)
            print("✅ Saved \(historyRecords.count) history records")
        } catch {
            print("❌ Failed to save history records: \(error)")
            errorMessage = "Failed to save history: \(error.localizedDescription)"
        }
    }
    
    private func loadHistoryRecords() {
        guard let data = userDefaults.data(forKey: historyKey) else {
            print("📝 No history records found")
            return
        }
        
        do {
            historyRecords = try JSONDecoder().decode([DogHistoryRecord].self, from: data)
            print("✅ Loaded \(historyRecords.count) history records")
        } catch {
            print("❌ Failed to load history records: \(error)")
            errorMessage = "Failed to load history: \(error.localizedDescription)"
            historyRecords = []
        }
    }
    
    // MARK: - Cleanup
    
    func cleanupOldRecords(olderThan days: Int = 90) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let originalCount = historyRecords.count
        
        historyRecords.removeAll { $0.date < cutoffDate }
        
        if historyRecords.count < originalCount {
            saveHistoryRecords()
            print("🧹 Cleaned up \(originalCount - historyRecords.count) old history records")
        }
    }
    
    // MARK: - Export
    
    func exportHistoryRecords() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var csv = "Date,Dog Name,Owner Name,Service Type,Status,Arrival Time,Departure Time,Boarding End Date,Medications,Special Instructions,Notes\n"
        
        for record in historyRecords.sorted(by: { $0.date > $1.date }) {
            // Create row data
            let dateString = formatter.string(from: record.date)
            let dogName = record.dogName
            let ownerName = record.ownerName ?? ""
            let serviceType = record.serviceType
            let statusDescription = record.statusDescription
            let arrivalTime = record.formattedArrivalTime
            let departureTime = record.formattedDepartureTime ?? ""
            let boardingEndDate = record.boardingEndDate != nil ? formatter.string(from: record.boardingEndDate!) : ""
            let medications = record.medications.map(\.name).joined(separator: ", ")
            let specialInstructions = record.specialInstructions ?? ""
            let notes = record.notes ?? ""
            
            // Escape quotes and create CSV row
            let escapedDate = dateString.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedDogName = dogName.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedOwnerName = ownerName.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedServiceType = serviceType.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedStatus = statusDescription.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedArrivalTime = arrivalTime.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedDepartureTime = departureTime.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedBoardingEndDate = boardingEndDate.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedMedications = medications.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedSpecialInstructions = specialInstructions.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedNotes = notes.replacingOccurrences(of: "\"", with: "\"\"")
            
            let row = "\"\(escapedDate)\",\"\(escapedDogName)\",\"\(escapedOwnerName)\",\"\(escapedServiceType)\",\"\(escapedStatus)\",\"\(escapedArrivalTime)\",\"\(escapedDepartureTime)\",\"\(escapedBoardingEndDate)\",\"\(escapedMedications)\",\"\(escapedSpecialInstructions)\",\"\(escapedNotes)\""
            
            csv += row + "\n"
        }
        
        return csv
    }
} 