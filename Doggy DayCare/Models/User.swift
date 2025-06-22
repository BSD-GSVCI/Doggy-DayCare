import Foundation

struct User: Codable, Identifiable {
    var id: String
    var name: String
    var email: String?  // Optional for staff
    var isActive: Bool
    var isOwner: Bool
    var isWorkingToday: Bool
    var updatedAt: Date
    var lastLogin: Date?
    var createdAt: Date
    var isOriginalOwner: Bool  // Track if this is the original owner
    
    // Schedule-based access control
    var scheduledDays: [Int]?  // Array of weekday indices (1-7, where 1 is Sunday, 2 is Monday, etc.)
    var scheduleStartTime: Date?
    var scheduleEndTime: Date?
    
    // Permissions
    var canAddDogs: Bool
    var canAddFutureBookings: Bool
    var canManageStaff: Bool
    var canManageMedications: Bool
    var canManageFeeding: Bool
    var canManageWalking: Bool
    
    // Computed property for staff work status
    var canWorkToday: Bool {
        if isOwner {
            return true
        }
        
        // Staff must be active to work
        guard isActive else {
            print("DEBUG: User \(name) is not active")
            return false
        }
        
        // Check if schedule-based access is enabled
        if let days = scheduledDays, !days.isEmpty {
            let calendar = Calendar.current
            let today = calendar.component(.weekday, from: Date())  // 1 = Sunday, 2 = Monday, etc.
            
            print("DEBUG: User \(name) - Today is weekday \(today), scheduled days: \(days)")
            
            // Check if today is in the scheduled days
            guard days.contains(today) else { 
                print("DEBUG: User \(name) - Today (\(today)) is not in scheduled days (\(days))")
                return false 
            }
            
            print("DEBUG: User \(name) - Today is scheduled!")
            
            // If day is scheduled, allow access for the entire day (no time constraints)
            print("DEBUG: User \(name) - Day scheduled, allowing all-day access")
            return true
        }
        
        // If no schedule is set, staff cannot work
        print("DEBUG: User \(name) - No schedule set")
        return false
    }
    
    init(id: String, name: String, email: String? = nil, isOwner: Bool = false, isActive: Bool = true, isWorkingToday: Bool = false, isOriginalOwner: Bool = false) {
        self.id = id
        self.name = name
        self.email = email
        self.isOwner = isOwner
        self.isActive = isActive
        self.isWorkingToday = isWorkingToday
        self.isOriginalOwner = isOriginalOwner
        self.createdAt = Date()
        self.updatedAt = Date()
        
        // Initialize schedule properties
        self.scheduledDays = nil
        self.scheduleStartTime = nil
        self.scheduleEndTime = nil
        
        // Set permissions based on role
        if isOwner {
            self.canAddDogs = true
            self.canAddFutureBookings = true
            self.canManageStaff = true
            self.canManageMedications = true
            self.canManageFeeding = true
            self.canManageWalking = true
        } else {
            // Give staff members full access
            self.canAddDogs = true
            self.canAddFutureBookings = true
            self.canManageStaff = false  // Only owners can manage staff
            self.canManageMedications = true
            self.canManageFeeding = true
            self.canManageWalking = true
        }
    }
    
    mutating func promoteToOwner(email: String, password: String) {
        guard !isOwner else { return }  // Already an owner
        
        // Update owner status and permissions
        isOwner = true
        self.email = email  // Set the new owner email
        
        // Update permissions for owner
        canAddDogs = true
        canAddFutureBookings = true
        canManageStaff = true
        canManageMedications = true
        canManageFeeding = true
        canManageWalking = true
        
        // Store the new owner password
        let passwordKey = "owner_password_\(email)"
        UserDefaults.standard.set(password, forKey: passwordKey)
        
        updatedAt = Date()
    }
    
    mutating func deactivate() {
        // Prevent deactivating original owner
        guard !isOriginalOwner else { return }
        isActive = false
        updatedAt = Date()
    }
    
    mutating func activate() {
        isActive = true
        updatedAt = Date()
    }
    
    mutating func updateWorkingStatus(_ isWorking: Bool) {
        isWorkingToday = isWorking
        updatedAt = Date()
    }
    
    mutating func updateLastLogin() {
        lastLogin = Date()
    }
}

// MARK: - Change Tracking
struct DogChange: Codable, Identifiable {
    var id = UUID()
    var timestamp: Date
    var changeType: ChangeType
    var fieldName: String
    var oldValue: String?
    var newValue: String?
    
    init(
        timestamp: Date = Date(),
        changeType: ChangeType,
        fieldName: String,
        oldValue: String? = nil,
        newValue: String? = nil
    ) {
        self.timestamp = timestamp
        self.changeType = changeType
        self.fieldName = fieldName
        self.oldValue = oldValue
        self.newValue = newValue
    }
}

enum ChangeType: String, Codable {
    case created
    case updated
    case deleted
    case arrived
    case departed
    case medicationAdded
    case medicationRemoved
    case walkingStatusChanged
    case feedingStatusChanged
} 