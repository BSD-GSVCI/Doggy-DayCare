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
    var cloudKitUserID: String?  // CloudKit user ID for cross-device mapping
    
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
            #if DEBUG
            print("DEBUG: User \(name) is not active")
            #endif
            return false
        }
        
        // Check if schedule-based access is enabled
        if let days = scheduledDays, !days.isEmpty {
            let calendar = Calendar.current
            let today = calendar.component(.weekday, from: Date())  // 1 = Sunday, 2 = Monday, etc.
            
            #if DEBUG
            print("DEBUG: User \(name) - Today is weekday \(today), scheduled days: \(days)")
            #endif
            
            // Check if today is in the scheduled days
            guard days.contains(today) else { 
                #if DEBUG
                print("DEBUG: User \(name) - Today (\(today)) is not in scheduled days (\(days))")
                #endif
                return false 
            }
            
            #if DEBUG
            print("DEBUG: User \(name) - Today is scheduled!")
            #endif
            
            // Check working hours if they are set
            if let startTime = scheduleStartTime, let endTime = scheduleEndTime {
                let now = Date()
                let calendar = Calendar.current
                
                #if DEBUG
                print("DEBUG: User \(name) - Raw start time: \(startTime)")
                print("DEBUG: User \(name) - Raw end time: \(endTime)")
                print("DEBUG: User \(name) - Current time: \(now)")
                #endif
                
                // Extract time components from the stored times
                let startHour = calendar.component(.hour, from: startTime)
                let startMinute = calendar.component(.minute, from: startTime)
                let endHour = calendar.component(.hour, from: endTime)
                let endMinute = calendar.component(.minute, from: endTime)
                
                // Get current time components
                let currentHour = calendar.component(.hour, from: now)
                let currentMinute = calendar.component(.minute, from: now)
                
                // Convert to minutes for easier comparison
                let startMinutes = startHour * 60 + startMinute
                let endMinutes = endHour * 60 + endMinute
                let currentMinutes = currentHour * 60 + currentMinute
                
                #if DEBUG
                print("DEBUG: User \(name) - Working hours: \(startHour):\(startMinute) to \(endHour):\(endMinute)")
                print("DEBUG: User \(name) - Current time: \(currentHour):\(currentMinute)")
                print("DEBUG: User \(name) - Start minutes: \(startMinutes), End minutes: \(endMinutes), Current minutes: \(currentMinutes)")
                #endif
                
                // Check if current time is within working hours
                let isWithinHours = currentMinutes >= startMinutes && currentMinutes <= endMinutes
                #if DEBUG
                print("DEBUG: User \(name) - Within working hours: \(isWithinHours)")
                print("DEBUG: User \(name) - Comparison: \(currentMinutes) >= \(startMinutes) && \(currentMinutes) <= \(endMinutes)")
                #endif
                return isWithinHours
            } else {
                // If no time constraints are set, allow access for the entire day
                #if DEBUG
                print("DEBUG: User \(name) - No time constraints, allowing all-day access")
                #endif
                return true
            }
        }
        
        // If no schedule is set, staff cannot work
        #if DEBUG
        print("DEBUG: User \(name) - No schedule set")
        #endif
        return false
    }
    
    init(id: String, name: String, email: String? = nil, isOwner: Bool = false, isActive: Bool = true, isWorkingToday: Bool = false, isOriginalOwner: Bool = false, scheduledDays: [Int]? = nil, scheduleStartTime: Date? = nil, scheduleEndTime: Date? = nil, createdAt: Date = Date(), updatedAt: Date = Date(), lastLogin: Date? = nil, cloudKitUserID: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.isOwner = isOwner
        self.isActive = isActive
        self.isWorkingToday = isWorkingToday
        self.isOriginalOwner = isOriginalOwner
        self.scheduledDays = scheduledDays
        self.scheduleStartTime = scheduleStartTime
        self.scheduleEndTime = scheduleEndTime
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastLogin = lastLogin
        self.cloudKitUserID = cloudKitUserID
        // Set permissions based on role
        if isOwner {
            self.canAddDogs = true
            self.canAddFutureBookings = true
            self.canManageStaff = true
            self.canManageMedications = true
            self.canManageFeeding = true
            self.canManageWalking = true
        } else {
            self.canAddDogs = true
            self.canAddFutureBookings = true
            self.canManageStaff = false
            self.canManageMedications = true
            self.canManageFeeding = true
            self.canManageWalking = true
        }
    }
    
    mutating func promoteToOwner(email: String, password: String) {
        guard !isOwner else { return }  // Already an owner
        
        // Update owner status and permissions
        isOwner = true
        isWorkingToday = true  // Owners should always have access
        self.email = email  // Set the new owner email
        
        // Update permissions for owner
        canAddDogs = true
        canAddFutureBookings = true
        canManageStaff = true
        canManageMedications = true
        canManageFeeding = true
        canManageWalking = true
        
        // Store the new owner password
        let passwordKey = "owner_password_\(email.lowercased())"
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