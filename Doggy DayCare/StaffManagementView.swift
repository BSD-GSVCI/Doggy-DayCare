import SwiftUI

struct StaffManagementView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var authService = AuthenticationService.shared
    @State private var showingAddStaff = false
    @State private var showingDeleteAlert = false
    @State private var showingPromoteAlert = false
    @State private var showingScheduleSettings = false
    @State private var showingPromoteForm = false
    @State private var staffToDelete: User?
    @State private var staffToPromote: User?
    @State private var selectedStaffForSchedule: User?
    @State private var promoteEmail = ""
    @State private var promotePassword = ""
    @State private var promoteConfirmPassword = ""
    @State private var showingPromoteError = false
    @State private var promoteErrorMessage = ""
    
    private var originalOwner: User? {
        dataManager.users.first { $0.isOriginalOwner }
    }
    
    private var isCurrentUserOriginalOwner: Bool {
        authService.currentUser?.isOriginalOwner ?? false
    }
    
    private var isCurrentUserOwner: Bool {
        authService.currentUser?.isOwner ?? false
    }
    
    private var staffMembers: [User] {
        dataManager.users.filter { !$0.isOwner }
    }
    
    private var promotedOwners: [User] {
        dataManager.users.filter { $0.isOwner && !$0.isOriginalOwner }
    }
    
    var body: some View {
        List {
            if dataManager.users.isEmpty {
                ContentUnavailableView {
                    Label("No Staff Members", systemImage: "person.2.slash")
                } description: {
                    Text("Add staff members to manage their schedules and permissions.")
                }
            } else {
                Section("Staff Members") {
                    ForEach(staffMembers) { user in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(user.name)
                                    .font(.headline)
                                Spacer()
                                if user.isActive {
                                    Text("Active")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Inactive")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                            
                            // Schedule Access Button
                            if user.isActive {
                                Button {
                                    handleScheduleAction(for: user)
                                } label: {
                                    Label("Schedule Access", systemImage: "clock")
                                        .font(.subheadline)
                                }
                            }
                            
                            // Schedule Information
                            ScheduleInfoView(user: user)
                        }
                        .swipeActions(edge: .trailing) {
                            if isCurrentUserOwner {
                                Button(role: .destructive) {
                                    staffToDelete = user
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if isCurrentUserOriginalOwner && user.isActive {
                                Button {
                                    handlePromoteAction(for: user)
                                } label: {
                                    Label("Promote", systemImage: "person.badge.plus")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
                
                if !promotedOwners.isEmpty {
                    Section("Promoted Owners") {
                        ForEach(promotedOwners) { user in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(user.name)
                                        .font(.headline)
                                    Spacer()
                                    if user.isActive {
                                        Text("Active")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("Inactive")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }
                                }
                                
                                Text("Full access to all features")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .swipeActions(edge: .trailing) {
                                if isCurrentUserOriginalOwner {
                                    Button(role: .destructive) {
                                        staffToDelete = user
                                        showingDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                if let owner = originalOwner {
                    Section("Original Owner") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(owner.name)
                                    .font(.headline)
                                Spacer()
                                if owner.isActive {
                                    Text("Active")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Inactive")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                            
                            Text("This account has full access to all features and cannot be deleted.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Staff Management")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddStaff = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingAddStaff) {
            NavigationStack {
                AddStaffView()
            }
        }
        .sheet(item: Binding(
            get: { staffToPromote },
            set: { newValue in
                staffToPromote = newValue
                showingPromoteForm = newValue != nil
            }
        )) { staff in
            NavigationStack {
                PromoteToOwnerView(staff: staff) { success in
                    if success {
                        staffToPromote = nil
                    }
                }
            }
            .presentationDetents([.medium])
            .interactiveDismissDisabled()
        }
        .sheet(item: Binding(
            get: { selectedStaffForSchedule },
            set: { newValue in
                selectedStaffForSchedule = newValue
                showingScheduleSettings = newValue != nil
            }
        )) { staff in
            NavigationStack {
                StaffScheduleView(staff: staff)
            }
            .presentationDetents([.medium])
            .interactiveDismissDisabled()
        }
        .alert("Delete User", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                staffToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let staff = staffToDelete {
                    if staff.isOwner {
                        UserDefaults.standard.removeObject(forKey: "owner_password_\(staff.email ?? "")")
                    }
                    deleteStaff(staff)
                }
                staffToDelete = nil
            }
        } message: {
            if let staff = staffToDelete {
                if staff.isOwner {
                    Text("Are you sure you want to delete owner \(staff.name)? This will remove their owner access and cannot be undone.")
                } else {
                    Text("Are you sure you want to delete \(staff.name)? This action cannot be undone.")
                }
            }
        }
        .alert("Promotion Error", isPresented: $showingPromoteError) {
            Button("OK") { }
        } message: {
            Text(promoteErrorMessage)
        }
    }
    
    private func handlePromoteAction(for staff: User) {
        staffToPromote = staff
    }
    
    private func handleScheduleAction(for staff: User) {
        selectedStaffForSchedule = staff
    }
    
    private func deleteStaff(_ staff: User) {
        Task {
            await dataManager.deleteUser(staff)
        }
    }
    
    private func promoteStaff(_ staff: User) {
        Task {
            var updatedStaff = staff
            updatedStaff.promoteToOwner(email: promoteEmail, password: promotePassword)
            await dataManager.updateUser(updatedStaff)
        }
    }
    
    private func updateStaffSchedule(_ staff: User) {
        Task {
            let updatedStaff = staff
            // Update schedule properties here
            await dataManager.updateUser(updatedStaff)
        }
    }
}

struct PromoteToOwnerView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    let staff: User
    let onComplete: (Bool) -> Void
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && password == confirmPassword && password.count >= 8
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                } header: {
                    Text("Owner Credentials")
                } footer: {
                    Text("The promoted owner will use these credentials to sign in.")
                }
            }
            .navigationTitle("Promote to Owner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onComplete(false)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Promote") {
                        promoteUser()
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func promoteUser() {
        // Check if email already exists (excluding current user)
        let existingUser = dataManager.users.first { user in
            if let userEmail = user.email {
                return userEmail == email && user.id != staff.id
            }
            return false
        }
        
        if existingUser != nil {
            errorMessage = "A user with this email already exists"
            showingError = true
            return
        }
        
        // Promote the staff member to owner
        Task {
            var updatedStaff = staff
            updatedStaff.promoteToOwner(email: email, password: password)
            await dataManager.updateUser(updatedStaff)
            await MainActor.run {
                onComplete(true)
            }
        }
    }
}

struct StaffScheduleView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    let staff: User
    
    @State private var selectedDays: Set<Int> = []
    
    private let weekdays = [
        (1, "Sunday"),
        (2, "Monday"),
        (3, "Tuesday"),
        (4, "Wednesday"),
        (5, "Thursday"),
        (6, "Friday"),
        (7, "Saturday")
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Working Days") {
                    ForEach(weekdays, id: \.0) { day in
                        Button {
                            if selectedDays.contains(day.0) {
                                selectedDays.remove(day.0)
                            } else {
                                selectedDays.insert(day.0)
                            }
                        } label: {
                            HStack {
                                Text(day.1)
                                Spacer()
                                if selectedDays.contains(day.0) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Schedule Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSchedule()
                    }
                }
            }
            .onAppear {
                // Load existing schedule
                if let days = staff.scheduledDays {
                    selectedDays = Set(days)
                }
            }
        }
    }
    
    private func saveSchedule() {
        Task {
            var updatedStaff = staff
            updatedStaff.scheduledDays = Array(selectedDays).sorted()
            updatedStaff.scheduleStartTime = nil
            updatedStaff.scheduleEndTime = nil
            updatedStaff.updatedAt = Date()
            await dataManager.updateUser(updatedStaff)
            // Refresh users from CloudKit to ensure latest data is loaded
            await dataManager.fetchUsers()
            await MainActor.run {
                dismiss()
            }
        }
    }
}

private struct AddStaffView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var isFormValid: Bool {
        !name.isEmpty && !password.isEmpty && password == confirmPassword && password.count >= 8
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                    
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                } header: {
                    Text("Staff Information")
                } footer: {
                    Text("The staff member will use their name and password to sign in.")
                }
            }
            .navigationTitle("Add Staff Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addStaffMember()
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func addStaffMember() {
        // Check if name already exists
        let existingUsers = dataManager.users.filter { user in
            user.name == name
        }
        
        guard existingUsers.isEmpty else {
            errorMessage = "A staff member with this name already exists"
            showingError = true
            return
        }
        
        // Create new staff member
        let newUser = User(
            id: UUID().uuidString,
            name: name,
            email: nil,  // Staff members don't need email
            isOwner: false,
            isActive: true,
            isWorkingToday: false
        )
        
        // Store staff password
        let passwordKey = "staff_password_\(name)"
        UserDefaults.standard.set(password, forKey: passwordKey)
        
        Task {
            await dataManager.addUser(newUser)
            await MainActor.run {
                dismiss()
            }
        }
    }
}

// MARK: - Schedule Info View
private struct ScheduleInfoView: View {
    let user: User
    
    private var dayNames: String {
        guard let days = user.scheduledDays, !days.isEmpty else { return "" }
        return days.map { day in
            Calendar.current.weekdaySymbols[day - 1]
        }.joined(separator: ", ")
    }
    
    var body: some View {
        if user.isActive {
            VStack(alignment: .leading, spacing: 4) {
                if user.scheduledDays != nil && !user.scheduledDays!.isEmpty {
                    Text("📅 Weekly Schedule Active:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Text("• Working days: \(dayNames)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    // Show current status
                    if user.canWorkToday {
                        Text("Scheduled for work today")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    } else {
                        Text("Not scheduled for today")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                } else {
                    Text("📅 No Schedule Set:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Text("• Staff member cannot login without a schedule")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text("• Set up a weekly schedule to grant access")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview {
    let dataManager = DataManager.shared
    
    return NavigationStack {
        StaffManagementView()
            .environmentObject(dataManager)
    }
} 