import Foundation
import CloudKit

/// Handles application-level conflict resolution for multi-user scenarios
@MainActor
final class ConflictResolver {
    static let shared = ConflictResolver()
    
    // MARK: - Conflict Types
    
    enum ConflictType {
        case dogNoLongerPresent(dogName: String, attemptedAction: String)
        case visitAlreadyModified(dogName: String, localChanges: String, remoteChanges: String)
        case duplicateActivityRecord(dogName: String, activityType: String)
        case deletedWhileUpdating(dogName: String)
        case conflictingFieldUpdates(dogName: String, conflicts: [FieldConflict])
        case boardingDateConflict(dogName: String, localDate: Date, remoteDate: Date)
    }
    
    struct FieldConflict {
        let fieldName: String
        let localValue: Any
        let remoteValue: Any
        let resolution: ResolutionStrategy
    }
    
    enum ResolutionStrategy {
        case keepLocal
        case keepRemote
        case merge
        case askUser
    }
    
    // MARK: - Conflict Resolution Rules
    
    private let fieldPrecedence: [String: Int] = [
        // Owner-modifiable fields have highest precedence
        "ownerName": 100,
        "ownerPhoneNumber": 100,
        "allergiesAndFeedingInstructions": 90,
        
        // Medical fields have high precedence
        "medications": 80,
        "scheduledMedications": 80,
        "vaccinations": 80,
        
        // Staff-modifiable fields have medium precedence
        "needsWalking": 50,
        "walkingNotes": 50,
        "isDaycareFed": 50,
        "notes": 40,
        "specialInstructions": 40,
        
        // Activity records have low precedence (always merge)
        "feedingRecords": 10,
        "medicationRecords": 10,
        "pottyRecords": 10
    ]
    
    // MARK: - Main Conflict Resolution
    
    /// Resolves conflicts between local and remote dog data using field-level updates
    func resolveConflict(
        local: DogWithVisit,
        remote: DogWithVisit,
        localUser: User?,
        remoteUser: User?
    ) async -> ConflictResolution {
        
        var resolution = ConflictResolution()
        
        // 1. Check if dog is still present
        if !remote.isCurrentlyPresent && local.isCurrentlyPresent {
            resolution.conflicts.append(.dogNoLongerPresent(
                dogName: local.name,
                attemptedAction: "update"
            ))
            resolution.userMessage = "\(local.name) has been checked out by another staff member"
            return resolution
        }
        
        // 2. Check for deletion
        if remote.isDeleted && !local.isDeleted {
            resolution.conflicts.append(.deletedWhileUpdating(dogName: local.name))
            resolution.userMessage = "\(local.name) has been deleted"
            return resolution
        }
        
        // 3. Resolve field-level conflicts
        var fieldConflicts: [FieldConflict] = []
        
        // Compare and resolve PersistentDog fields
        if local.ownerName != remote.ownerName {
            let conflict = resolveFieldConflict(
                fieldName: "ownerName",
                localValue: local.ownerName,
                remoteValue: remote.ownerName,
                localUser: localUser,
                remoteUser: remoteUser
            )
            fieldConflicts.append(conflict)
            
            if conflict.resolution == .keepRemote {
                resolution.fieldUpdates.append(FieldUpdate(
                    dogId: local.id,
                    fieldPath: "persistentDog.ownerName",
                    newValue: remote.ownerName ?? "",
                    reason: "Remote user had higher precedence"
                ))
            }
        }
        
        if local.ownerPhoneNumber != remote.ownerPhoneNumber {
            let conflict = resolveFieldConflict(
                fieldName: "ownerPhoneNumber",
                localValue: local.ownerPhoneNumber,
                remoteValue: remote.ownerPhoneNumber,
                localUser: localUser,
                remoteUser: remoteUser
            )
            fieldConflicts.append(conflict)
            
            if conflict.resolution == .keepRemote {
                resolution.fieldUpdates.append(FieldUpdate(
                    dogId: local.id,
                    fieldPath: "persistentDog.ownerPhoneNumber",
                    newValue: remote.ownerPhoneNumber ?? "",
                    reason: "Remote user had higher precedence"
                ))
            }
        }
        
        // 4. Merge activity records (always combine, never lose data)
        if let localVisit = local.currentVisit,
           let remoteVisit = remote.currentVisit {
            
            mergeVisitRecords(
                dogId: local.id,
                local: localVisit,
                remote: remoteVisit,
                resolution: &resolution
            )
        }
        
        // 5. Handle boarding date conflicts
        if let localBoarding = local.boardingEndDate,
           let remoteBoarding = remote.boardingEndDate,
           localBoarding != remoteBoarding {
            
            // Later date wins (extending boarding is safer than shortening)
            let winningDate = max(localBoarding, remoteBoarding)
            
            resolution.fieldUpdates.append(FieldUpdate(
                dogId: local.id,
                fieldPath: "currentVisit.boardingEndDate",
                newValue: winningDate,
                reason: "Extended boarding date takes precedence"
            ))
            
            resolution.conflicts.append(.boardingDateConflict(
                dogName: local.name,
                localDate: localBoarding,
                remoteDate: remoteBoarding
            ))
            
            resolution.userMessage = "Boarding extended to \(winningDate.formatted())"
        }
        
        if !fieldConflicts.isEmpty {
            resolution.conflicts.append(.conflictingFieldUpdates(
                dogName: local.name,
                conflicts: fieldConflicts
            ))
        }
        
        resolution.wasSuccessful = true
        
        return resolution
    }
    
    // MARK: - Field-Level Conflict Resolution
    
    private func resolveFieldConflict(
        fieldName: String,
        localValue: Any?,
        remoteValue: Any?,
        localUser: User?,
        remoteUser: User?
    ) -> FieldConflict {
        
        // Determine resolution strategy based on field precedence and user roles
        let strategy: ResolutionStrategy
        
        // Owner changes always win over staff changes
        if remoteUser?.isOwner == true && localUser?.isOwner == false {
            strategy = .keepRemote
        } else if localUser?.isOwner == true && remoteUser?.isOwner == false {
            strategy = .keepLocal
        } else {
            // Same role level - use field precedence
            let precedence = fieldPrecedence[fieldName] ?? 50
            
            if precedence >= 80 {
                // High precedence fields - ask user for critical data
                strategy = .askUser
            } else if precedence >= 50 {
                // Medium precedence - last write wins
                strategy = .keepRemote
            } else {
                // Low precedence - merge if possible
                strategy = .merge
            }
        }
        
        return FieldConflict(
            fieldName: fieldName,
            localValue: localValue ?? "",
            remoteValue: remoteValue ?? "",
            resolution: strategy
        )
    }
    
    // MARK: - Visit Record Merging
    
    private func mergeVisitRecords(
        dogId: UUID,
        local: Visit,
        remote: Visit,
        resolution: inout ConflictResolution
    ) {
        
        // Merge feeding records - identify records to add
        let feedingRecordsToAdd = identifyRecordsToAdd(
            local: local.feedingRecords,
            remote: remote.feedingRecords
        )
        
        if !feedingRecordsToAdd.isEmpty {
            resolution.recordMerges.append(RecordMerge(
                dogId: dogId,
                recordType: .feeding,
                recordsToAdd: feedingRecordsToAdd,
                recordsToRemove: [],
                reason: "Merged unique feeding records from both sources"
            ))
        }
        
        // Merge medication records
        let medicationRecordsToAdd = identifyRecordsToAdd(
            local: local.medicationRecords,
            remote: remote.medicationRecords
        )
        
        if !medicationRecordsToAdd.isEmpty {
            resolution.recordMerges.append(RecordMerge(
                dogId: dogId,
                recordType: .medication,
                recordsToAdd: medicationRecordsToAdd,
                recordsToRemove: [],
                reason: "Merged unique medication records from both sources"
            ))
        }
        
        // Merge potty records
        let pottyRecordsToAdd = identifyRecordsToAdd(
            local: local.pottyRecords,
            remote: remote.pottyRecords
        )
        
        if !pottyRecordsToAdd.isEmpty {
            resolution.recordMerges.append(RecordMerge(
                dogId: dogId,
                recordType: .potty,
                recordsToAdd: pottyRecordsToAdd,
                recordsToRemove: [],
                reason: "Merged unique potty records from both sources"
            ))
        }
        
        // Merge scheduled medications
        let scheduledMedsToAdd = identifyScheduledMedicationsToAdd(
            local: local.scheduledMedications,
            remote: remote.scheduledMedications
        )
        
        if !scheduledMedsToAdd.isEmpty {
            resolution.recordMerges.append(RecordMerge(
                dogId: dogId,
                recordType: .scheduledMedication,
                recordsToAdd: scheduledMedsToAdd,
                recordsToRemove: [],
                reason: "Merged unique scheduled medications from both sources"
            ))
        }
    }
    
    // MARK: - Record Identification Methods
    
    private func identifyRecordsToAdd<T: ActivityRecord>(
        local: [T],
        remote: [T]
    ) -> [T] {
        
        var recordsToAdd: [T] = []
        
        // Find local records that don't exist in remote
        for localRecord in local {
            let isDuplicate = remote.contains { remoteRecord in
                // Check if records are duplicates (same timestamp within 5 seconds)
                abs(localRecord.timestamp.timeIntervalSince(remoteRecord.timestamp)) < 5
            }
            
            if !isDuplicate {
                recordsToAdd.append(localRecord)
                
                #if DEBUG
                print("🔄 Identified unique local record to add: \(type(of: localRecord))")
                #endif
            }
        }
        
        return recordsToAdd
    }
    
    private func identifyScheduledMedicationsToAdd(
        local: [ScheduledMedication],
        remote: [ScheduledMedication]
    ) -> [ScheduledMedication] {
        
        var recordsToAdd: [ScheduledMedication] = []
        
        // Find local scheduled medications not in remote
        for localSched in local {
            let isDuplicate = remote.contains { remoteSched in
                remoteSched.medicationId == localSched.medicationId &&
                abs(remoteSched.scheduledDate.timeIntervalSince(localSched.scheduledDate)) < 60
            }
            
            if !isDuplicate {
                recordsToAdd.append(localSched)
                
                #if DEBUG
                print("🔄 Identified unique scheduled medication to add")
                #endif
            }
        }
        
        return recordsToAdd
    }
    
    // MARK: - Conflict Detection for Operations
    
    /// Checks if an operation will conflict before attempting it
    func detectPotentialConflict(
        operation: PendingOperation,
        currentState: DogWithVisit
    ) -> ConflictWarning? {
        
        switch operation {
        case .addFeedingRecord(_, _):
            if !currentState.isCurrentlyPresent {
                return ConflictWarning(
                    severity: .high,
                    message: "\(currentState.name) has been checked out",
                    suggestion: "This dog is no longer present. The feeding record cannot be added."
                )
            }
            
        case .addMedicationRecord(_, _):
            if !currentState.isCurrentlyPresent {
                return ConflictWarning(
                    severity: .high,
                    message: "\(currentState.name) has been checked out",
                    suggestion: "This dog is no longer present. The medication record cannot be added."
                )
            }
            
        case .addPottyRecord(_, _):
            if !currentState.isCurrentlyPresent {
                return ConflictWarning(
                    severity: .high,
                    message: "\(currentState.name) has been checked out",
                    suggestion: "This dog is no longer present. The potty record cannot be added."
                )
            }
            
        case .checkoutDog(_):
            if !currentState.isCurrentlyPresent {
                return ConflictWarning(
                    severity: .high,
                    message: "\(currentState.name) has already been checked out",
                    suggestion: "Another staff member has already checked out this dog."
                )
            }
            
        case .extendBoarding(_, let newDate):
            if let currentEnd = currentState.boardingEndDate,
               newDate < currentEnd {
                return ConflictWarning(
                    severity: .medium,
                    message: "Boarding date conflict",
                    suggestion: "Another staff member has already extended boarding to \(currentEnd.formatted())"
                )
            }
            
        case .updateDogInfo(_):
            // Check if dog was deleted
            if currentState.isDeleted {
                return ConflictWarning(
                    severity: .critical,
                    message: "\(currentState.name) has been deleted",
                    suggestion: "This dog record has been deleted and cannot be updated."
                )
            }
        }
        
        return nil
    }
}

// MARK: - Supporting Types

struct ConflictResolution {
    var conflicts: [ConflictResolver.ConflictType] = []
    var fieldUpdates: [FieldUpdate] = []
    var recordMerges: [RecordMerge] = []
    var wasSuccessful: Bool = false
    var userMessage: String?
    var requiresUserIntervention: Bool = false
}

struct FieldUpdate {
    let dogId: UUID
    let fieldPath: String  // "persistentDog.ownerName" or "currentVisit.departureDate"
    let newValue: Any
    let reason: String     // Why this update was chosen
}

struct RecordMerge {
    let dogId: UUID
    let recordType: RecordType
    let recordsToAdd: [Any]
    let recordsToRemove: [UUID]
    let reason: String
    
    enum RecordType {
        case feeding
        case medication
        case potty
        case scheduledMedication
    }
}

struct ConflictWarning {
    enum Severity {
        case low
        case medium
        case high
        case critical
    }
    
    let severity: Severity
    let message: String
    let suggestion: String
}

enum PendingOperation {
    case addFeedingRecord(dogId: UUID, record: FeedingRecord)
    case addMedicationRecord(dogId: UUID, record: MedicationRecord)
    case addPottyRecord(dogId: UUID, record: PottyRecord)
    case checkoutDog(dogId: UUID)
    case extendBoarding(dogId: UUID, newDate: Date)
    case updateDogInfo(dog: DogWithVisit)
}

// Protocol for activity records
protocol ActivityRecord {
    var id: UUID { get }
    var timestamp: Date { get }
    var recordedBy: String? { get }
}

// Conform existing record types to ActivityRecord
extension FeedingRecord: ActivityRecord {}
extension MedicationRecord: ActivityRecord {}
extension PottyRecord: ActivityRecord {}