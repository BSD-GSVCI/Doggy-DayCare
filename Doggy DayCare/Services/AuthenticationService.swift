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
        print("AuthenticationService initialized")
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
        print("Attempting sign in with email: \(email ?? "nil"), name: \(name ?? "nil")")
        
        // First authenticate with CloudKit
        try await cloudKitService.authenticate()
        
        if let email = email {
            // Convert email to lowercase for case-insensitive comparison
            let lowercaseEmail = email.lowercased()
            
            // Fetch all users from CloudKit
            let allUsers = try await cloudKitService.fetchAllUsers()
            let owners = allUsers.filter { $0.isOwner && $0.isActive }
            
            guard let cloudKitUser = owners.first(where: { $0.email?.lowercased() == lowercaseEmail }) else {
                print("No user found with email: \(email)")
                throw AuthError.userNotFound
            }
            
            // Use explicit string interpolation for user properties
            let userEmail = cloudKitUser.email.map { ", email: \($0)" } ?? ""
            print("Found user: \(cloudKitUser.name)\(userEmail), isOwner: \(cloudKitUser.isOwner), isActive: \(cloudKitUser.isActive)")
            
            // Owner login requires password
            guard let password = password else {
                print("Password required for owner login")
                throw AuthError.passwordRequired
            }
            
            // Verify password from CloudKit
            if let storedHashedPassword = cloudKitUser.hashedPassword {
                // Use CloudKit stored password
                guard verifyPassword(password, against: storedHashedPassword) else {
                    print("Invalid password for owner: \(cloudKitUser.name)")
                    throw AuthError.invalidPassword
                }
            } else {
                // Fallback to UserDefaults for backward compatibility
                if cloudKitUser.isOriginalOwner {
                    guard let storedPassword = UserDefaults.standard.string(forKey: ownerPasswordKey),
                          password == storedPassword else {
                        print("Invalid owner password")
                        throw AuthError.invalidPassword
                    }
                } else {
                    guard let userEmail = cloudKitUser.email else {
                        print("Promoted owner has no email")
                        throw AuthError.invalidCredentials
                    }
                    let passwordKey = "owner_password_\(userEmail.lowercased())"
                    guard let storedPassword = UserDefaults.standard.string(forKey: passwordKey),
                          password == storedPassword else {
                        print("Invalid password for promoted owner: \(cloudKitUser.name)")
                        throw AuthError.invalidPassword
                    }
                }
                
                // Migrate password to CloudKit
                await migratePasswordToCloudKit(for: cloudKitUser, password: password)
            }
            
            // Update last login time
            var updatedUser = cloudKitUser
            updatedUser.lastLogin = Date()
            _ = try await cloudKitService.updateUser(updatedUser)
            
            // Set current user
            currentUser = updatedUser.toUser()
            print("Successfully signed in user: \(updatedUser.name)")
            return
            
        } else if let name = name {
            // Staff login - only non-owner active users
            let allUsers = try await cloudKitService.fetchAllUsers()
            let staffUsers = allUsers.filter { $0.name == name && !$0.isOwner && $0.isActive }
            
            print("Found \(staffUsers.count) matching users")
            
            guard let cloudKitUser = staffUsers.first else {
                print("No user found")
                throw AuthError.userNotFound
            }
            
            // Verify password from CloudKit
            if let storedHashedPassword = cloudKitUser.hashedPassword {
                // Use CloudKit stored password
                guard let password = password,
                      verifyPassword(password, against: storedHashedPassword) else {
                    print("Invalid staff password")
                    throw AuthError.invalidPassword
                }
            } else {
                // Fallback to UserDefaults for backward compatibility
                let passwordKey = "staff_password_\(cloudKitUser.name)"
                guard let storedPassword = UserDefaults.standard.string(forKey: passwordKey),
                      password == storedPassword else {
                    print("Invalid staff password")
                    throw AuthError.invalidPassword
                }
                
                // Migrate password to CloudKit
                if let password = password {
                    await migratePasswordToCloudKit(for: cloudKitUser, password: password)
                }
            }
            
            // Check if staff member is scheduled to work today
            if !cloudKitUser.canWorkToday {
                print("Staff member \(cloudKitUser.name) is not scheduled to work today")
                throw AuthError.notScheduledToday
            }
            
            // Update last login time
            var updatedUser = cloudKitUser
            updatedUser.lastLogin = Date()
            _ = try await cloudKitService.updateUser(updatedUser)
            
            // Set current user
            currentUser = updatedUser.toUser()
            print("Successfully signed in user: \(updatedUser.name)")
            
        } else {
            throw AuthError.invalidCredentials
        }
    }
    
    private func migratePasswordToCloudKit(for user: CloudKitUser, password: String) async {
        do {
            var updatedUser = user
            updatedUser.hashedPassword = hashPassword(password)
            _ = try await cloudKitService.updateUser(updatedUser)
            print("✅ Migrated password to CloudKit for user: \(user.name)")
        } catch {
            print("❌ Failed to migrate password to CloudKit: \(error)")
        }
    }
    
    func signOut() {
        print("Signing out user: \(currentUser?.name ?? "unknown")")
        Task {
            await MainActor.run {
                withAnimation {
                    self.currentUser = nil
                }
            }
        }
        print("User signed out")
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
                print("No owner account found when updating password")
                return
            }
            
            // Update password in CloudKit
            var updatedOwner = firstOwner
            updatedOwner.hashedPassword = hashPassword(newPassword)
            _ = try await cloudKitService.updateUser(updatedOwner)
            
            // Also update in UserDefaults for backward compatibility
            UserDefaults.standard.set(newPassword, forKey: ownerPasswordKey)
            temporaryPassword = nil
            
            print("✅ Owner password updated in CloudKit")
        } catch {
            print("Error updating owner password: \(error)")
        }
    }
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case userNotFound
    case accountInactive
    case notScheduledToday
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
        case .passwordRequired:
            return "Password is required"
        case .invalidPassword:
            return "Invalid password"
        case .passwordResetFailed(let message):
            return "Failed to reset password. \(message)"
        }
    }
} 