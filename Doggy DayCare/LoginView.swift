import SwiftUI
import SwiftData

struct LoginView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = AuthenticationService.shared
    @State private var email = ""
    @State private var name = ""
    @State private var ownerPassword = ""
    @State private var staffPassword = ""
    @State private var confirmPassword = ""
    @State private var newPassword = ""
    @State private var confirmNewPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isOwnerLogin = true
    @State private var isFirstLogin = false
    @State private var showingPasswordChange = false
    @State private var showingForgotPassword = false
    @State private var showingTemporaryPassword = false
    @State private var showingPasswordUpdateConfirmation = false
    @State private var isResettingPassword = false
    @State private var isSigningUp = false
    @State private var ownerExists = false
    
    private var isFormValid: Bool {
        if isOwnerLogin {
            return !email.isEmpty && !ownerPassword.isEmpty
        } else {
            return !name.isEmpty && !staffPassword.isEmpty
        }
    }
    
    private var isPasswordValid: Bool {
        ownerPassword.count >= 8 && ownerPassword.contains(where: { $0.isNumber })
    }
    
    private var isSignupValid: Bool {
        !name.isEmpty &&
        !email.isEmpty &&
        email.contains("@") &&
        isPasswordValid &&
        ownerPassword == confirmPassword
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("🐕‍🦺")
                        .font(.system(size: 80))
                        .padding(.bottom, 20)
                    
                    Text("Green House Doggy DayCare")
                        .font(.title)
                        .bold()
                    
                    Picker("Login Type", selection: $isOwnerLogin) {
                        Text("Owner").tag(true)
                        Text("Staff").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if isOwnerLogin {
                        VStack(spacing: 15) {
                            if !ownerExists {
                                // Show signup form if no owner exists
                                Text("Welcome to Doggy DayCare!")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .padding(.top)
                                
                                Text("Create your owner account to get started")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                TextField("Your Name", text: $name)
                                    .textFieldStyle(.roundedBorder)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
                                    .padding(.horizontal)
                                
                                TextField("Email", text: $email)
                                    .textFieldStyle(.roundedBorder)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled()
                                    .padding(.horizontal)
                                
                                SecureField("Password", text: $ownerPassword)
                                    .textFieldStyle(.roundedBorder)
                                    .padding(.horizontal)
                                
                                SecureField("Confirm Password", text: $confirmPassword)
                                    .textFieldStyle(.roundedBorder)
                                    .padding(.horizontal)
                                
                                if !ownerPassword.isEmpty && !isPasswordValid {
                                    Text("Password must be at least 8 characters and include a number")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                        .padding(.horizontal)
                                }
                                
                                if !confirmPassword.isEmpty && ownerPassword != confirmPassword {
                                    Text("Passwords do not match")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                        .padding(.horizontal)
                                }
                                
                                if let errorMessage = errorMessage {
                                    Text(errorMessage)
                                        .foregroundStyle(.red)
                                        .font(.caption)
                                        .padding(.horizontal)
                                }
                                
                                Button {
                                    Task {
                                        await signUp()
                                    }
                                } label: {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                    } else {
                                        Text("Create Account")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.horizontal)
                                .disabled(isLoading || !isSignupValid)
                                
                                Text("If already owner login")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                            } else {
                                // Show login form if owner exists
                                Text("Owner Login")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .padding(.top)
                                
                                TextField("Email", text: $email)
                                    .textFieldStyle(.roundedBorder)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled()
                                    .padding(.horizontal)
                                
                                SecureField("Password", text: $ownerPassword)
                                    .textFieldStyle(.roundedBorder)
                                    .padding(.horizontal)
                                
                                if let errorMessage = errorMessage {
                                    Text(errorMessage)
                                        .foregroundStyle(.red)
                                        .font(.caption)
                                        .padding(.horizontal)
                                }
                                
                                Button {
                                    Task {
                                        await signIn()
                                    }
                                } label: {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                    } else {
                                        Text("Sign In")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.horizontal)
                                .disabled(isLoading || !isFormValid)
                                
                                VStack(spacing: 8) {
                                    Button {
                                        showingForgotPassword = true
                                    } label: {
                                        Text("Forgot Password?")
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(.blue.opacity(0.1))
                                            .foregroundStyle(.blue)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .padding(.horizontal)
                                    
                                    if showingPasswordChange {
                                        VStack(spacing: 12) {
                                            Text("Change Password")
                                                .font(.headline)
                                                .padding(.top)
                                            
                                            SecureField("New Password", text: $newPassword)
                                                .textFieldStyle(.roundedBorder)
                                                .padding(.horizontal)
                                            
                                            SecureField("Confirm New Password", text: $confirmNewPassword)
                                                .textFieldStyle(.roundedBorder)
                                                .padding(.horizontal)
                                            
                                            HStack(spacing: 20) {
                                                Button("Cancel") {
                                                    showingPasswordChange = false
                                                    newPassword = ""
                                                    confirmNewPassword = ""
                                                    errorMessage = nil
                                                }
                                                .foregroundStyle(.red)
                                                
                                                Button("Update Password") {
                                                    updateOwnerPassword()
                                                }
                                                .disabled(!isPasswordChangeValid)
                                            }
                                            .padding(.horizontal)
                                        }
                                        .background(Color(.systemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .shadow(radius: 2)
                                        .padding(.horizontal)
                                    } else {
                                        Button {
                                            withAnimation {
                                                showingPasswordChange = true
                                            }
                                        } label: {
                                            Label("Change Password", systemImage: "key.fill")
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                                .background(.blue.opacity(0.1))
                                                .foregroundStyle(.blue)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    } else {
                        // Staff login view
                        VStack(spacing: 15) {
                            TextField("Name", text: $name)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .padding(.horizontal)
                            
                            SecureField("Password", text: $staffPassword)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal)
                            
                            if let errorMessage = errorMessage {
                                Text(errorMessage)
                                    .foregroundStyle(.red)
                                    .font(.caption)
                                    .padding(.horizontal)
                            }
                            
                            Button {
                                Task {
                                    await signIn()
                                }
                            } label: {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text("Sign In")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal)
                            .disabled(isLoading || !isFormValid)
                        }
                    }
                }
                .padding()
            }
            .alert("Reset Password", isPresented: $showingForgotPassword) {
                Button("Cancel", role: .cancel) { }
                Button("Reset") {
                    Task {
                        await resetPassword()
                    }
                }
            } message: {
                Text("A temporary password will be generated and shown to you. You can use this to sign in and then change your password.")
            }
            .alert("Temporary Password", isPresented: $showingTemporaryPassword) {
                Button("OK") {
                    // Clear the temporary password from the alert
                    authService.temporaryPassword = nil
                }
            } message: {
                if let tempPassword = authService.temporaryPassword {
                    Text("Your temporary password is:\n\n\(tempPassword)\n\nPlease use this to sign in and then change your password.")
                }
            }
            .alert("Password Updated", isPresented: $showingPasswordUpdateConfirmation) {
                Button("OK") { }
            } message: {
                Text("Your password has been successfully updated. Please use your new password the next time you sign in.")
            }
            .overlay {
                if isResettingPassword {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Resetting Password...")
                                .padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onChange(of: isOwnerLogin) { _, _ in
            // Clear fields when switching between owner and staff
            errorMessage = nil
            if isOwnerLogin {
                staffPassword = ""
            } else {
                ownerPassword = ""
                confirmPassword = ""
                email = ""
            }
        }
        .onAppear {
            // Clear any existing error message and fields
            errorMessage = nil
            email = ""
            name = ""
            ownerPassword = ""
            staffPassword = ""
            confirmPassword = ""
            
            // Check if owner exists
            let fetchDescriptor = FetchDescriptor<User>(
                predicate: #Predicate<User> { user in
                    user.isOwner == true && user.isActive == true
                }
            )
            
            do {
                let owners = try modelContext.fetch(fetchDescriptor)
                print("Found \(owners.count) active owners")
                for owner in owners {
                    print("Owner: \(owner.name), email: \(owner.email ?? "none"), isOriginalOwner: \(owner.isOriginalOwner)")
                }
                ownerExists = !owners.isEmpty
                print("ownerExists set to: \(ownerExists)")
            } catch {
                print("Error checking for owner: \(error)")
                ownerExists = false
            }
        }
    }
    
    private var isPasswordChangeValid: Bool {
        !newPassword.isEmpty &&
        newPassword.count >= 8 &&
        newPassword.contains(where: { $0.isNumber }) &&
        newPassword == confirmNewPassword
    }
    
    private func signIn() async {
        guard isFormValid else {
            errorMessage = "Please fill in all fields"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            if isOwnerLogin {
                // Convert email to lowercase for case-insensitive comparison
                try await authService.signIn(email: email.lowercased(), password: ownerPassword)
            } else {
                try await authService.signIn(name: name, password: staffPassword)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func signUp() async {
        guard isSignupValid else {
            errorMessage = "Please fill in all fields correctly. Password must be at least 8 characters and include a number."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Check if this is the first owner account
            let fetchDescriptor = FetchDescriptor<User>(
                predicate: #Predicate<User> { user in
                    user.isOwner == true
                }
            )
            let existingOwners = try modelContext.fetch(fetchDescriptor)
            let isFirstOwner = existingOwners.isEmpty
            
            // Convert email to lowercase for case-insensitive storage
            let lowercaseEmail = email.lowercased()
            
            // Check if email already exists (case-insensitive)
            // We'll fetch all users and filter in memory since we can't use lowercased() in predicate
            let allUsersDescriptor = FetchDescriptor<User>()
            let allUsers = try modelContext.fetch(allUsersDescriptor)
            if allUsers.contains(where: { $0.email?.lowercased() == lowercaseEmail }) {
                errorMessage = "An account with this email already exists"
                isLoading = false
                return
            }
            
            // Create owner account with lowercase email
            let owner = User(
                id: UUID().uuidString,
                name: name,
                email: lowercaseEmail,
                isOwner: true,
                isActive: true,
                isOriginalOwner: isFirstOwner
            )
            
            // Store password before inserting the user
            if isFirstOwner {
                // For original owner, use the owner password key
                UserDefaults.standard.set(ownerPassword, forKey: "owner_password")
            } else {
                // For promoted owners, use email-based password key
                UserDefaults.standard.set(ownerPassword, forKey: "owner_password_\(lowercaseEmail)")
            }
            
            modelContext.insert(owner)
            try modelContext.save()
            
            // Sign in the new owner
            try await authService.signIn(email: lowercaseEmail, password: ownerPassword)
            
            await MainActor.run {
                ownerExists = true
                isSigningUp = false
                // Clear sensitive fields
                ownerPassword = ""
                confirmPassword = ""
            }
        } catch {
            errorMessage = "Failed to create account: \(error.localizedDescription)"
            print("Sign up error: \(error)")
        }
        
        isLoading = false
    }
    
    private func updateOwnerPassword() {
        guard isPasswordChangeValid else {
            errorMessage = "Please enter a valid password (minimum 8 characters with at least one number)"
            return
        }
        
        authService.updateOwnerPassword(newPassword)
        showingPasswordChange = false
        newPassword = ""
        confirmNewPassword = ""
        errorMessage = nil
        showingPasswordUpdateConfirmation = true
    }
    
    private func resetPassword() async {
        // Convert email to lowercase for case-insensitive comparison
        let lowercaseEmail = email.lowercased()
        guard lowercaseEmail == "owner@doggydaycare.com" else {
            errorMessage = "Invalid owner email"
            return
        }
        
        isResettingPassword = true
        errorMessage = nil
        
        do {
            try await authService.resetOwnerPassword()
            showingTemporaryPassword = true
        } catch {
            errorMessage = "Failed to reset password: \(error.localizedDescription)"
        }
        
        isResettingPassword = false
    }
}

#Preview {
    LoginView()
        .modelContainer(for: User.self)
} 