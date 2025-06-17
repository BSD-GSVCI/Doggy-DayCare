import SwiftUI
import SwiftData
import Foundation

@MainActor
class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    private let ownerPasswordKey = "owner_password"  // Define a constant for the key
    
    @Published private(set) var currentUser: User?
    @Published private(set) var modelContext: ModelContext?
    @Published var temporaryPassword: String?
    
    private init() {
        print("AuthenticationService initialized")
        // Always start with no user
        currentUser = nil
    }
    
    func isModelContextSet() -> Bool {
        let isSet = modelContext != nil
        print("Model context is \(isSet ? "set" : "not set")")
        return isSet
    }
    
    func setModelContext(_ context: ModelContext) {
        print("Setting model context in AuthenticationService")
        modelContext = context
    }
    
    func signIn(email: String? = nil, name: String? = nil, password: String? = nil) async throws {
        guard let modelContext = modelContext else {
            print("Model context not set")
            throw AuthError.modelContextNotSet
        }
        
        print("Attempting sign in with email: \(email ?? "nil"), name: \(name ?? "nil")")
        
        let descriptor: FetchDescriptor<User>
        
        if let email = email {
            // Convert email to lowercase for case-insensitive comparison
            let lowercaseEmail = email.lowercased()
            
            // Fetch all owners and filter in memory since we can't use lowercased() in predicate
            let allOwnersDescriptor = FetchDescriptor<User>(
                predicate: #Predicate<User> { user in
                    user.isOwner == true && user.isActive == true
                }
            )
            let allOwners = try modelContext.fetch(allOwnersDescriptor)
            guard let user = allOwners.first(where: { $0.email?.lowercased() == lowercaseEmail }) else {
                print("No user found with email: \(email)")
                throw AuthError.userNotFound
            }
            
            // Use explicit string interpolation for user properties
            let userEmail = user.email.map { ", email: \($0)" } ?? ""
            print("Found user: \(user.name)\(userEmail), isOwner: \(user.isOwner), isActive: \(user.isActive)")
            
                // Owner login requires password
                guard let password = password else {
                    print("Password required for owner login")
                    throw AuthError.passwordRequired
                }
                
                // For original owner, use the owner password key
                if user.isOriginalOwner {
                    guard let storedPassword = UserDefaults.standard.string(forKey: ownerPasswordKey),
                          password == storedPassword else {
                        print("Invalid owner password")
                        throw AuthError.invalidPassword
                    }
                } else {
                // For promoted owners, use their email-based password key
                guard let userEmail = user.email else {
                    print("Promoted owner has no email")
                    throw AuthError.invalidCredentials
                }
                // Use lowercase email for password key
                let passwordKey = "owner_password_\(userEmail.lowercased())"
                    guard let storedPassword = UserDefaults.standard.string(forKey: passwordKey),
                          password == storedPassword else {
                        print("Invalid password for promoted owner: \(user.name)")
                        throw AuthError.invalidPassword
                    }
                }
            
            // Update last login time
            user.lastLogin = Date()
            try modelContext.save()
            
            // Set current user
            currentUser = user
            print("Successfully signed in user: \(user.name)")
            return
        } else if let name = name {
            // Staff login - only non-owner active users
            descriptor = FetchDescriptor<User>(
                predicate: #Predicate<User> { user in
                    user.name == name && !user.isOwner && user.isActive
                }
            )
            
            do {
                let users = try modelContext.fetch(descriptor)
                print("Found \(users.count) matching users")
                
                guard let user = users.first else {
                    print("No user found")
                    throw AuthError.userNotFound
                }
                
                // Staff login - use staff password key
                let passwordKey = "staff_password_\(user.name)"
                guard let storedPassword = UserDefaults.standard.string(forKey: passwordKey),
                      password == storedPassword else {
                    print("Invalid staff password")
                    throw AuthError.invalidPassword
                }
                
                // Check if staff member is scheduled to work today
                if !user.canWorkToday {
                    print("Staff member \(user.name) is not scheduled to work today")
                    throw AuthError.notScheduledToday
                }
                
                // Update last login time
                user.lastLogin = Date()
                try modelContext.save()
                
                // Set current user
                currentUser = user
            print("Successfully signed in user: \(user.name)")
            } catch {
                print("Sign in error: \(error)")
            throw error
            }
        } else {
            throw AuthError.invalidCredentials
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
        guard let modelContext = modelContext else {
            throw AuthError.modelContextNotSet
        }
        
        // Verify owner exists
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.isOwner
            }
        )
        
        let owners = try modelContext.fetch(descriptor)
        guard !owners.isEmpty else {
            throw AuthError.passwordResetFailed("No owner account found")
        }
        
        // Generate temporary password (6 letters + 2 numbers)
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let numbers = "0123456789"
        let tempPassword = String((0..<6).map { _ in letters.randomElement()! } +
                                (0..<2).map { _ in numbers.randomElement()! })
        
        // Store temporary password using the constant key
        UserDefaults.standard.set(tempPassword, forKey: ownerPasswordKey)
        temporaryPassword = tempPassword
        
        // Simulate email delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
    
    func updateOwnerPassword(_ newPassword: String) {
        // Verify owner exists before updating password
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.isOwner
            }
        )
        
        do {
            let owners = try modelContext?.fetch(descriptor) ?? []
            guard !owners.isEmpty else {
                print("No owner account found when updating password")
                return
            }
            
            // Store password using the constant key
            UserDefaults.standard.set(newPassword, forKey: ownerPasswordKey)
            temporaryPassword = nil
        } catch {
            print("Error updating owner password: \(error)")
        }
    }
}

enum AuthError: LocalizedError {
    case modelContextNotSet
    case invalidCredentials
    case userNotFound
    case accountInactive
    case notScheduledToday
    case passwordRequired
    case invalidPassword
    case passwordResetFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelContextNotSet:
            return "Application error: Model context not set"
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