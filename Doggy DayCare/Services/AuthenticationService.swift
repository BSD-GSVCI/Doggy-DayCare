import SwiftUI
import Foundation
import CryptoKit

@MainActor
class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    private let ownerPasswordKey = "owner_password"  // Keep for backward compatibility
    
    @Published private(set) var currentUser: User?
    @Published var temporaryPassword: String?
    
    private let cloudKitService = CloudKitService.shared
    
    private init() {
        #if DEBUG
        print("AuthenticationService initialized")
        #endif
        // Always start with no user
        currentUser = nil
    }
    
    // MARK: - Password Hashing
    
    func hashPassword(_ password: String) -> String {
        let salt = "DoggyDayCare_Salt_2024" // In production, use unique salt per user
        let saltedPassword = password + salt
        let inputData = Data(saltedPassword.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func verifyPassword(_ password: String, against hashedPassword: String) -> Bool {
        let hashedInput = hashPassword(password)
        return hashedInput == hashedPassword
    }
    
    // MARK: - Authentication
    
    func signIn(email: String? = nil, name: String? = nil, password: String? = nil) async throws {
        #if DEBUG
        print("Attempting sign in with email: \(email ?? "nil"), name: \(name ?? "nil")")
        #endif
        
        // First authenticate with CloudKit
        try await cloudKitService.authenticate()
        
        if let email = email {
            // Convert email to lowercase for case-insensitive comparison
            let lowercaseEmail = email.lowercased()
            
            // Fetch all users from CloudKit
            let allUsers = try await cloudKitService.fetchAllUsers()
            let owners = allUsers.filter { $0.isOwner && $0.isActive }
            
            guard let cloudKitUser = owners.first(where: { $0.email?.lowercased() == lowercaseEmail }) else {
                #if DEBUG
                print("No user found with email: \(email)")
                #endif
                throw AuthError.userNotFound
            }
            
            // Use explicit string interpolation for user properties
            let userEmail = cloudKitUser.email.map { ", email: \($0)" } ?? ""
            #if DEBUG
            print("Found user: \(cloudKitUser.name)\(userEmail), isOwner: \(cloudKitUser.isOwner), isActive: \(cloudKitUser.isActive)")
            #endif
            
            // Owner login requires password
            guard let password = password else {
                #if DEBUG
                print("Password required for owner login")
                #endif
                throw AuthError.passwordRequired
            }
            
            // Verify password from CloudKit
            if let storedHashedPassword = cloudKitUser.hashedPassword {
                // Use CloudKit stored password
                guard verifyPassword(password, against: storedHashedPassword) else {
                    #if DEBUG
                    print("Invalid password for owner: \(cloudKitUser.name)")
                    #endif
                    throw AuthError.invalidPassword
                }
            } else {
                // Fallback to UserDefaults for backward compatibility
                if cloudKitUser.isOriginalOwner {
                    guard let storedPassword = UserDefaults.standard.string(forKey: ownerPasswordKey),
                          password == storedPassword else {
                        #if DEBUG
                        print("Invalid owner password")
                        #endif
                        throw AuthError.invalidPassword
                    }
                } else {
                    guard let userEmail = cloudKitUser.email else {
                        #if DEBUG
                        print("Promoted owner has no email")
                        #endif
                        throw AuthError.invalidCredentials
                    }
                    let passwordKey = "owner_password_\(userEmail.lowercased())"
                    guard let storedPassword = UserDefaults.standard.string(forKey: passwordKey),
                          password == storedPassword else {
                        #if DEBUG
                        print("Invalid password for promoted owner: \(cloudKitUser.name)")
                        #endif
                        throw AuthError.invalidPassword
                    }
                }
                
                // Migrate password to CloudKit
                await migratePasswordToCloudKit(for: cloudKitUser, password: password)
            }
            
            // Update last login time (only if we have write permissions)
            do {
                var updatedUser = cloudKitUser
                updatedUser.lastLogin = Date()
                _ = try await cloudKitService.updateUser(updatedUser)
                #if DEBUG
                print("✅ Updated last login time for user: \(updatedUser.name)")
                #endif
            } catch {
                // If we can't update last login (e.g., no write permissions), 
                // just log it but don't fail the login
                #if DEBUG
                print("⚠️ Could not update last login time (this is normal for non-owner users): \(error)")
                #endif
            }
            
            // Set current user
            currentUser = cloudKitUser.toUser()
            #if DEBUG
            print("Successfully signed in user: \(cloudKitUser.name)")
            #endif
            
            // Update CloudKit user ID for cross-device compatibility
            do {
                #if DEBUG
                print("🔄 Attempting to update CloudKit user ID for owner login...")
                #endif
                try await cloudKitService.updateCurrentUserCloudKitID()
                #if DEBUG
                print("✅ Successfully updated CloudKit user ID for owner")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ Failed to update CloudKit user ID for owner: \(error)")
                #endif
            }
            
            return
            
        } else if let name = name {
            // Staff login - only non-owner active users
            let allUsers = try await cloudKitService.fetchAllUsers()
            let staffUsers = allUsers.filter { $0.name == name && !$0.isOwner && $0.isActive }
            
            #if DEBUG
            print("Found \(staffUsers.count) matching users")
            #endif
            
            guard let cloudKitUser = staffUsers.first else {
                #if DEBUG
                print("No user found")
                #endif
                throw AuthError.userNotFound
            }
            
            // Verify password from CloudKit
            if let storedHashedPassword = cloudKitUser.hashedPassword {
                // Use CloudKit stored password
                guard let password = password,
                      verifyPassword(password, against: storedHashedPassword) else {
                    #if DEBUG
                    print("Invalid staff password")
                    #endif
                    throw AuthError.invalidPassword
                }
            } else {
                // Fallback to UserDefaults for backward compatibility
                let passwordKey = "staff_password_\(cloudKitUser.name)"
                guard let storedPassword = UserDefaults.standard.string(forKey: passwordKey),
                      password == storedPassword else {
                    #if DEBUG
                    print("Invalid staff password")
                    #endif
                    throw AuthError.invalidPassword
                }
                
                // Migrate password to CloudKit
                if let password = password {
                    await migratePasswordToCloudKit(for: cloudKitUser, password: password)
                }
            }
            
            // Check if staff member is scheduled to work today
            #if DEBUG
            print("🔍 AUTH DEBUG: Checking if \(cloudKitUser.name) can work today...")
            #endif
            let canWork = cloudKitUser.canWorkToday
            #if DEBUG
            print("🔍 AUTH DEBUG: canWorkToday result: \(canWork)")
            #endif
            
            if !canWork {
                // Determine the specific reason for access denial
                let calendar = Calendar.current
                let today = calendar.component(.weekday, from: Date())
                let todayInt64 = Int64(today)
                
                if let days = cloudKitUser.scheduledDays, !days.isEmpty {
                    if days.contains(todayInt64) {
                        // User is scheduled for today but outside working hours
                        #if DEBUG
                        print("❌ AUTH ERROR: Staff member \(cloudKitUser.name) is outside working hours")
                        #endif
                        throw AuthError.outsideWorkingHours
                    } else {
                        // User is not scheduled for today
                        #if DEBUG
                        print("❌ AUTH ERROR: Staff member \(cloudKitUser.name) is not scheduled to work today")
                        #endif
                        throw AuthError.notScheduledToday
                    }
                } else {
                    // No schedule set
                    #if DEBUG
                    print("❌ AUTH ERROR: Staff member \(cloudKitUser.name) has no schedule set")
                    #endif
                    throw AuthError.noScheduleSet
                }
            } else {
                #if DEBUG
                print("✅ AUTH DEBUG: \(cloudKitUser.name) is allowed to work")
                #endif
            }
            
            // Update last login time (only if we have write permissions)
            do {
                var updatedUser = cloudKitUser
                updatedUser.lastLogin = Date()
                _ = try await cloudKitService.updateUser(updatedUser)
                #if DEBUG
                print("✅ Updated last login time for user: \(updatedUser.name)")
                #endif
            } catch {
                // If we can't update last login (e.g., no write permissions), 
                // just log it but don't fail the login
                #if DEBUG
                print("⚠️ Could not update last login time (this is normal for non-owner users): \(error)")
                #endif
            }
            
            // Set current user
            currentUser = cloudKitUser.toUser()
            #if DEBUG
            print("Successfully signed in user: \(cloudKitUser.name)")
            #endif
            
            // Update CloudKit user ID for cross-device compatibility
            do {
                #if DEBUG
                print("🔄 Attempting to update CloudKit user ID for staff login...")
                #endif
                try await cloudKitService.updateCurrentUserCloudKitID()
                #if DEBUG
                print("✅ Successfully updated CloudKit user ID for staff")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ Failed to update CloudKit user ID for staff: \(error)")
                #endif
            }
            
            return
            
        } else {
            throw AuthError.invalidCredentials
        }
    }
    
    // MARK: - Password Migration
    
    /// Manually migrate passwords for existing users (runs only once per app installation)
    func migrateExistingPasswords() async {
        // Check if migration has already been completed
        let migrationCompletedKey = "password_migration_completed"
        if UserDefaults.standard.bool(forKey: migrationCompletedKey) {
            #if DEBUG
            print("✅ Password migration already completed, skipping...")
            #endif
            return
        }
        
        #if DEBUG
        print("🔄 Starting password migration for existing users...")
        #endif
        
        do {
            let allUsers = try await cloudKitService.fetchAllUsers()
            var migrationCount = 0
            
            for user in allUsers {
                // Skip users that already have hashed passwords
                if user.hashedPassword != nil {
                    #if DEBUG
                    print("User \(user.name) already has hashed password, skipping...")
                    #endif
                    continue
                }
                
                // Try to find password in UserDefaults
                var password: String?
                
                if user.isOwner {
                    if user.isOriginalOwner {
                        password = UserDefaults.standard.string(forKey: ownerPasswordKey)
                    } else if let email = user.email {
                        let passwordKey = "owner_password_\(email.lowercased())"
                        password = UserDefaults.standard.string(forKey: passwordKey)
                    }
                } else {
                    // Staff member
                    let passwordKey = "staff_password_\(user.name)"
                    password = UserDefaults.standard.string(forKey: passwordKey)
                }
                
                if let password = password {
                    #if DEBUG
                    print("Migrating password for user: \(user.name)")
                    #endif
                    await migratePasswordToCloudKit(for: user, password: password)
                    migrationCount += 1
                } else {
                    #if DEBUG
                    print("No password found in UserDefaults for user: \(user.name)")
                    #endif
                }
            }
            
            // Mark migration as completed
            UserDefaults.standard.set(true, forKey: migrationCompletedKey)
            
            if migrationCount > 0 {
                #if DEBUG
                print("✅ Password migration completed for \(migrationCount) users")
                #endif
            } else {
                #if DEBUG
                print("✅ Password migration completed (no users needed migration)")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ Error during password migration: \(error)")
            #endif
        }
    }
    
    /// Manually trigger password migration (for testing purposes)
    func forcePasswordMigration() async {
        #if DEBUG
        print("🔄 Force triggering password migration...")
        #endif
        
        // Reset migration flag to force migration
        let migrationCompletedKey = "password_migration_completed"
        UserDefaults.standard.set(false, forKey: migrationCompletedKey)
        
        // Run migration
        await migrateExistingPasswords()
    }
    
    private func migratePasswordToCloudKit(for user: CloudKitUser, password: String) async {
        do {
            var updatedUser = user
            updatedUser.hashedPassword = hashPassword(password)
            _ = try await cloudKitService.updateUser(updatedUser)
            #if DEBUG
            print("✅ Migrated password to CloudKit for user: \(user.name)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to migrate password to CloudKit for user \(user.name): \(error)")
            #endif
        }
    }
    
    func signOut() {
        #if DEBUG
        print("Signing out user: \(currentUser?.name ?? "unknown")")
        #endif
        Task {
            await MainActor.run {
                withAnimation {
                    self.currentUser = nil
                }
            }
        }
        #if DEBUG
        print("User signed out")
        #endif
    }
    
    func resetLoginState() {
        #if DEBUG
        print("Resetting login state for fresh login")
        #endif
        // This will be called when the app needs to check owner existence again
    }
    
    func resetOwnerPassword() async throws {
        // Verify owner exists
        let allUsers = try await cloudKitService.fetchAllUsers()
        let owners = allUsers.filter { $0.isOwner }
        
        guard !owners.isEmpty else {
            throw AuthError.passwordResetFailed("No owner account found")
        }
        
        // Generate temporary password (6 letters + 2 numbers)
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let numbers = "0123456789"
        let tempPassword = String((0..<6).map { _ in letters.randomElement()! } +
                                (0..<2).map { _ in numbers.randomElement()! })
        
        // Store temporary password in CloudKit for the first owner
        if let firstOwner = owners.first {
            var updatedOwner = firstOwner
            updatedOwner.hashedPassword = hashPassword(tempPassword)
            _ = try await cloudKitService.updateUser(updatedOwner)
        }
        
        // Also store in UserDefaults for backward compatibility
        UserDefaults.standard.set(tempPassword, forKey: ownerPasswordKey)
        temporaryPassword = tempPassword
        
        // Simulate email delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
    
    func updateOwnerPassword(_ newPassword: String) async {
        do {
            // Verify owner exists before updating password
            let allUsers = try await cloudKitService.fetchAllUsers()
            let owners = allUsers.filter { $0.isOwner }
            
            guard let firstOwner = owners.first else {
                #if DEBUG
                print("No owner account found when updating password")
                #endif
                return
            }
            
            // Update password in CloudKit
            var updatedOwner = firstOwner
            updatedOwner.hashedPassword = hashPassword(newPassword)
            _ = try await cloudKitService.updateUser(updatedOwner)
            
            // Also update in UserDefaults for backward compatibility
            UserDefaults.standard.set(newPassword, forKey: ownerPasswordKey)
            temporaryPassword = nil
            
            #if DEBUG
            print("✅ Owner password updated in CloudKit")
            #endif
        } catch {
            #if DEBUG
            print("Error updating owner password: \(error)")
            #endif
        }
    }
    
    func updatePromotedOwnerPassword(email: String, password: String) async {
        do {
            // Find the promoted owner by email
            let allUsers = try await cloudKitService.fetchAllUsers()
            guard let promotedOwner = allUsers.first(where: { $0.email?.lowercased() == email.lowercased() && $0.isOwner && !$0.isOriginalOwner }) else {
                #if DEBUG
                print("Promoted owner with email \(email) not found")
                #endif
                return
            }
            
            // Update password in CloudKit
            var updatedOwner = promotedOwner
            updatedOwner.hashedPassword = hashPassword(password)
            _ = try await cloudKitService.updateUser(updatedOwner)
            
            #if DEBUG
            print("✅ Promoted owner password updated in CloudKit for \(email)")
            #endif
        } catch {
            #if DEBUG
            print("Error updating promoted owner password: \(error)")
            #endif
        }
    }
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case userNotFound
    case accountInactive
    case notScheduledToday
    case outsideWorkingHours
    case noScheduleSet
    case passwordRequired
    case invalidPassword
    case passwordResetFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid login credentials"
        case .userNotFound:
            return "User not found"
        case .accountInactive:
            return "This account is inactive"
        case .notScheduledToday:
            return "You are not scheduled to work today"
        case .outsideWorkingHours:
            return "You are outside your scheduled working hours"
        case .noScheduleSet:
            return "No working schedule has been set for your account"
        case .passwordRequired:
            return "Password is required"
        case .invalidPassword:
            return "Invalid password"
        case .passwordResetFailed(let message):
            return "Failed to reset password. \(message)"
        }
    }
} 