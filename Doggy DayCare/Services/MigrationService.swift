import CloudKit
import Foundation

@MainActor
class MigrationService: ObservableObject {
    static let shared = MigrationService()
    
    private let cloudKitService = CloudKitService.shared
    private let persistentDogService = PersistentDogService.shared
    private let visitService = VisitService.shared
    
    @Published var migrationProgress: Double = 0.0
    @Published var migrationStatus: String = "Ready"
    @Published var isMigrationComplete = false
    
    private init() {
        print("🔧 MigrationService initialized")
    }
    
    // MARK: - Migration Methods
    
    func performCompleteMigration() async throws {
        print("🚀 Starting complete migration...")
        migrationStatus = "Starting migration..."
        migrationProgress = 0.0
        
        do {
            // Step 1: Fetch all existing dogs
            migrationStatus = "Fetching existing dogs..."
            migrationProgress = 0.1
            let existingDogs = try await cloudKitService.fetchAllDogsIncludingDeleted()
            print("📊 Found \(existingDogs.count) existing dogs to migrate")
            
            // Step 2: Group dogs by name and owner
            migrationStatus = "Grouping dogs by name and owner..."
            migrationProgress = 0.2
            let groupedDogs = groupDogsByNameAndOwner(existingDogs)
            print("📊 Grouped into \(groupedDogs.count) unique dogs")
            
            // Step 3: Create persistent dogs
            migrationStatus = "Creating persistent dogs..."
            migrationProgress = 0.3
            let persistentDogs = try await createPersistentDogsFromGroups(groupedDogs)
            print("✅ Created \(persistentDogs.count) persistent dogs")
            
            // Step 4: Convert dogs to visits
            migrationStatus = "Converting dogs to visits..."
            migrationProgress = 0.6
            let visits = try await convertDogsToVisits(existingDogs, persistentDogs: persistentDogs)
            print("✅ Created \(visits.count) visits")
            
            // Step 5: Validate migration
            migrationStatus = "Validating migration..."
            migrationProgress = 0.9
            let validation = try await validateMigration(existingDogs: existingDogs, persistentDogs: persistentDogs, visits: visits)
            
            if validation.isValid {
                migrationStatus = "Migration completed successfully!"
                migrationProgress = 1.0
                isMigrationComplete = true
                print("✅ Migration completed successfully!")
                print("📊 Summary:")
                print("   - Original dogs: \(existingDogs.count)")
                print("   - Persistent dogs created: \(persistentDogs.count)")
                print("   - Visits created: \(visits.count)")
                print("   - Data integrity: ✅ Valid")
            } else {
                throw MigrationError.validationFailed(validation.errors)
            }
            
        } catch {
            migrationStatus = "Migration failed: \(error.localizedDescription)"
            print("❌ Migration failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func groupDogsByNameAndOwner(_ dogs: [CloudKitDog]) -> [String: [CloudKitDog]] {
        var grouped: [String: [CloudKitDog]] = [:]
        
        for dog in dogs {
            let key = createGroupKey(for: dog)
            if grouped[key] == nil {
                grouped[key] = []
            }
            grouped[key]?.append(dog)
        }
        
        return grouped
    }
    
    private func createGroupKey(for dog: CloudKitDog) -> String {
        let name = dog.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let ownerName = (dog.ownerName ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let ownerPhone = (dog.ownerPhoneNumber ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create a unique key based on name and owner information
        if !ownerName.isEmpty {
            return "\(name)_\(ownerName)"
        } else if !ownerPhone.isEmpty {
            return "\(name)_\(ownerPhone)"
        } else {
            return name
        }
    }
    
    private func createPersistentDogsFromGroups(_ groupedDogs: [String: [CloudKitDog]]) async throws -> [PersistentDog] {
        var persistentDogs: [PersistentDog] = []
        
        for (_, dogs) in groupedDogs {
            // Use the first dog in the group as the base for persistent dog info
            let baseDog = dogs.first!
            
            // Merge information from all dogs in the group
            let mergedInfo = mergeDogInformation(dogs)
            
            let persistentDog = PersistentDog(
                id: UUID(), // New UUID for persistent dog
                name: baseDog.name,
                ownerName: mergedInfo.ownerName,
                ownerPhoneNumber: mergedInfo.ownerPhoneNumber,
                age: mergedInfo.age,
                gender: mergedInfo.gender,
                vaccinations: mergedInfo.vaccinations,
                isNeuteredOrSpayed: mergedInfo.isNeuteredOrSpayed,
                allergiesAndFeedingInstructions: mergedInfo.allergiesAndFeedingInstructions,
                profilePictureData: mergedInfo.profilePictureData,
                medications: mergedInfo.medications,
                scheduledMedications: mergedInfo.scheduledMedications,
                visitCount: dogs.count,
                lastVisitDate: dogs.map { $0.arrivalDate }.max(),
                isDeleted: dogs.allSatisfy { $0.isDeleted },
                createdAt: dogs.map { $0.createdAt }.min() ?? Date(),
                updatedAt: Date(),
                createdBy: nil,
                lastModifiedBy: nil
            )
            
            try await persistentDogService.createPersistentDog(persistentDog)
            persistentDogs.append(persistentDog)
            
            print("✅ Created persistent dog: \(persistentDog.name) with \(dogs.count) visits")
        }
        
        return persistentDogs
    }
    
    private func mergeDogInformation(_ dogs: [CloudKitDog]) -> MergedDogInfo {
        var mergedInfo = MergedDogInfo()
        
        for dog in dogs {
            // Merge owner information (prefer non-nil values)
            if mergedInfo.ownerName == nil && dog.ownerName != nil {
                mergedInfo.ownerName = dog.ownerName
            }
            if mergedInfo.ownerPhoneNumber == nil && dog.ownerPhoneNumber != nil {
                mergedInfo.ownerPhoneNumber = dog.ownerPhoneNumber
            }
            
            // Merge age (prefer non-nil values)
            if mergedInfo.age == nil && !dog.age.isEmpty {
                mergedInfo.age = Int(dog.age)
            }
            
            // Merge gender (prefer non-nil values)
            if mergedInfo.gender == nil && !dog.gender.isEmpty {
                mergedInfo.gender = DogGender(rawValue: dog.gender) ?? .unknown
            }
            
            // Merge vaccinations (combine all unique vaccinations)
            for vaccination in dog.vaccinations {
                if !mergedInfo.vaccinations.contains(where: { $0.name == vaccination.name }) {
                    mergedInfo.vaccinations.append(vaccination)
                }
            }
            
            // Merge medications (combine all unique medications)
            for medication in dog.medications {
                if !mergedInfo.medications.contains(where: { $0.id == medication.id }) {
                    mergedInfo.medications.append(medication)
                }
            }
            
            // Merge scheduled medications (combine all unique scheduled medications)
            for scheduledMedication in dog.scheduledMedications {
                if !mergedInfo.scheduledMedications.contains(where: { $0.id == scheduledMedication.id }) {
                    mergedInfo.scheduledMedications.append(scheduledMedication)
                }
            }
            
            // Merge other information (prefer non-nil values)
            if mergedInfo.isNeuteredOrSpayed == nil {
                mergedInfo.isNeuteredOrSpayed = dog.isNeuteredOrSpayed
            }
            if mergedInfo.allergiesAndFeedingInstructions == nil && dog.allergiesAndFeedingInstructions != nil {
                mergedInfo.allergiesAndFeedingInstructions = dog.allergiesAndFeedingInstructions
            }
            if mergedInfo.profilePictureData == nil && dog.profilePictureData != nil {
                mergedInfo.profilePictureData = dog.profilePictureData
            }
        }
        
        return mergedInfo
    }
    
    private func convertDogsToVisits(_ dogs: [CloudKitDog], persistentDogs: [PersistentDog]) async throws -> [Visit] {
        var visits: [Visit] = []
        
        for dog in dogs {
            // Find the corresponding persistent dog
            let groupKey = createGroupKey(for: dog)
            let persistentDog = persistentDogs.first { persistentDog in
                let persistentKey = createGroupKey(for: persistentDog)
                return persistentKey == groupKey
            }
            
            guard let persistentDog = persistentDog else {
                print("⚠️ Could not find persistent dog for: \(dog.name)")
                continue
            }
            
            let visit = Visit(
                id: UUID(uuidString: dog.id) ?? UUID(), // Use original dog ID as visit ID
                dogId: persistentDog.id,
                arrivalDate: dog.arrivalDate,
                departureDate: dog.departureDate,
                isBoarding: dog.isBoarding,
                boardingEndDate: dog.boardingEndDate,
                isDaycareFed: dog.isDaycareFed,
                notes: dog.notes,
                specialInstructions: nil, // CloudKitDog doesn't have specialInstructions
                needsWalking: dog.needsWalking,
                walkingNotes: dog.walkingNotes,
                isDeleted: dog.isDeleted,
                deletedAt: dog.isDeleted ? dog.updatedAt : nil,
                deletedBy: nil, // CloudKitDog doesn't have modifiedBy
                createdAt: dog.createdAt,
                updatedAt: dog.updatedAt,
                createdBy: nil, // CloudKitDog doesn't have createdBy
                lastModifiedBy: nil, // CloudKitDog doesn't have modifiedBy
                feedingRecords: dog.feedingRecords,
                medicationRecords: dog.medicationRecords,
                pottyRecords: dog.pottyRecords
            )
            
            try await visitService.createVisit(visit)
            visits.append(visit)
            
            print("✅ Created visit for \(dog.name) on \(dog.arrivalDate)")
        }
        
        return visits
    }
    
    private func validateMigration(existingDogs: [CloudKitDog], persistentDogs: [PersistentDog], visits: [Visit]) async throws -> MigrationValidation {
        var errors: [String] = []
        
        // Check that all dogs were migrated
        if visits.count != existingDogs.count {
            errors.append("Visit count (\(visits.count)) doesn't match original dog count (\(existingDogs.count))")
        }
        
        // Check that all persistent dogs have visits
        for persistentDog in persistentDogs {
            let dogVisits = visits.filter { $0.dogId == persistentDog.id }
            if dogVisits.count != persistentDog.visitCount {
                errors.append("Persistent dog \(persistentDog.name) has \(dogVisits.count) visits but visitCount is \(persistentDog.visitCount)")
            }
        }
        
        // Check data integrity
        for dog in existingDogs {
            let visit = visits.first { $0.id == UUID(uuidString: dog.id) }
            if visit == nil {
                errors.append("Could not find visit for dog: \(dog.name)")
            }
        }
        
        return MigrationValidation(
            isValid: errors.isEmpty,
            errors: errors,
            originalDogCount: existingDogs.count,
            persistentDogCount: persistentDogs.count,
            visitCount: visits.count
        )
    }
    
    // MARK: - Utility Methods
    
    private func createGroupKey(for persistentDog: PersistentDog) -> String {
        let name = persistentDog.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let ownerName = (persistentDog.ownerName ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let ownerPhone = (persistentDog.ownerPhoneNumber ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !ownerName.isEmpty {
            return "\(name)_\(ownerName)"
        } else if !ownerPhone.isEmpty {
            return "\(name)_\(ownerPhone)"
        } else {
            return name
        }
    }
}

// MARK: - Supporting Types

struct MergedDogInfo {
    var ownerName: String?
    var ownerPhoneNumber: String?
    var age: Int?
    var gender: DogGender?
    var vaccinations: [VaccinationItem] = []
    var isNeuteredOrSpayed: Bool?
    var allergiesAndFeedingInstructions: String?
    var profilePictureData: Data?
    var medications: [Medication] = []
    var scheduledMedications: [ScheduledMedication] = []
}

struct MigrationValidation {
    let isValid: Bool
    let errors: [String]
    let originalDogCount: Int
    let persistentDogCount: Int
    let visitCount: Int
}

enum MigrationError: Error {
    case validationFailed([String])
    case cloudKitError(Error)
    case unknownError
}

// MARK: - CloudKitDog Extension

extension CloudKitDog {
    var vaccinations: [VaccinationItem] {
        var vaccinations: [VaccinationItem] = []
        
        if let bordetellaEndDate = bordetellaEndDate {
            vaccinations.append(VaccinationItem(name: "Bordetella", endDate: bordetellaEndDate))
        }
        if let dhppEndDate = dhppEndDate {
            vaccinations.append(VaccinationItem(name: "DHPP", endDate: dhppEndDate))
        }
        if let rabiesEndDate = rabiesEndDate {
            vaccinations.append(VaccinationItem(name: "Rabies", endDate: rabiesEndDate))
        }
        if let civEndDate = civEndDate {
            vaccinations.append(VaccinationItem(name: "CIV", endDate: civEndDate))
        }
        if let leptospirosisEndDate = leptospirosisEndDate {
            vaccinations.append(VaccinationItem(name: "Leptospirosis", endDate: leptospirosisEndDate))
        }
        
        return vaccinations
    }
    
    var medications: [Medication] {
        var medications: [Medication] = []
        
        for (index, name) in medicationNames.enumerated() {
            let type = medicationTypes.indices.contains(index) ? Medication.MedicationType(rawValue: medicationTypes[index]) ?? .daily : .daily
            let notes = medicationNotes.indices.contains(index) ? medicationNotes[index] : nil
            
            let medication = Medication(
                name: name,
                type: type,
                notes: notes,
                createdBy: nil // CloudKitDog doesn't track createdBy for medications
            )
            medications.append(medication)
        }
        
        return medications
    }
    
    var scheduledMedications: [ScheduledMedication] {
        var scheduledMedications: [ScheduledMedication] = []
        
        for (index, date) in scheduledMedicationDates.enumerated() {
            let status = scheduledMedicationStatuses.indices.contains(index) ? 
                ScheduledMedication.ScheduledMedicationStatus(rawValue: scheduledMedicationStatuses[index]) ?? .pending : .pending
            let notes = scheduledMedicationNotes.indices.contains(index) ? scheduledMedicationNotes[index] : nil
            
            let scheduledMedication = ScheduledMedication(
                medicationId: UUID(), // This will be updated during migration
                scheduledDate: date,
                notificationTime: date,
                status: status,
                notes: notes
            )
            scheduledMedications.append(scheduledMedication)
        }
        
        return scheduledMedications
    }
} 