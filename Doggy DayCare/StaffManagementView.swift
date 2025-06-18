import SwiftUI
import SwiftData

struct StaffManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = AuthenticationService.shared
    @Query private var staff: [User]
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
        staff.first { $0.isOriginalOwner }
    }
    
    private var isCurrentUserOriginalOwner: Bool {
        authService.currentUser?.isOriginalOwner ?? false
    }
    
    private var isCurrentUserOwner: Bool {
        authService.currentUser?.isOwner ?? false
    }
    
    private var staffMembers: [User] {
        staff.filter { !$0.isOwner }
    }
    
    private var promotedOwners: [User] {
        staff.filter { $0.isOwner && !$0.isOriginalOwner }
    }
    
    var body: some View {
        List {
            if staff.isEmpty {
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
                    modelContext.delete(staff)
                    try? modelContext.save()
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
}

struct PromoteToOwnerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let staff: User
    let onComplete: (Bool) -> Void
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var showingError = false
    
    private var isFormValid: Bool {
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 8 &&
        password.contains(where: { $0.isNumber }) &&
        password == confirmPassword
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                SecureField("Confirm Password", text: $confirmPassword)
            } header: {
                Text("Owner Credentials")
            } footer: {
                Text("Password must be at least 8 characters and include a number.")
            }
            
            Section {
                Button("Promote to Owner") {
                    promoteToOwner()
                }
                .disabled(!isFormValid)
            }
        }
        .navigationTitle("Promote to Owner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .onAppear {
            // Initialize email with staff's current email if available
            email = staff.email ?? ""
        }
    }
    
    private func promoteToOwner() {
        // Validate email format
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        guard emailPredicate.evaluate(with: email) else {
            errorMessage = "Please enter a valid email address"
            showingError = true
            return
        }
        
        // Check if email already exists (excluding current user)
        let descriptor = FetchDescriptor<User>()
        do {
            let allUsers = try modelContext.fetch(descriptor)
            let existingUser = allUsers.first { user in
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
            staff.isOwner = true
            staff.email = email
            staff.updatedAt = Date()
            
            // Store the owner's password with lowercase email
            let passwordKey = "owner_password_\(email.lowercased())"
            UserDefaults.standard.set(password, forKey: passwordKey)
            print("Stored password for promoted owner with key: \(passwordKey)")
            
            try modelContext.save()
            onComplete(true)
        } catch {
            errorMessage = "Failed to promote user: \(error.localizedDescription)"
            showingError = true
        }
    }
}

struct StaffScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let staff: User
    
    @State private var isScheduleEnabled: Bool
    @State private var selectedDays: Set<Int>
    
    init(staff: User) {
        self.staff = staff
        // Initialize state from staff member's current schedule
        _isScheduleEnabled = State(initialValue: staff.scheduledDays != nil)
        _selectedDays = State(initialValue: Set(staff.scheduledDays ?? []))
    }
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable Schedule", isOn: $isScheduleEnabled)
                    .onChange(of: isScheduleEnabled) { _, newValue in
                        updateStaffSchedule()
                    }
            } footer: {
                Text("When enabled, staff access will be controlled by their schedule.")
            }
            
            if isScheduleEnabled {
                Section("Working Days") {
                    ForEach(Calendar.current.weekdaySymbols.indices, id: \.self) { index in
                        Toggle(Calendar.current.weekdaySymbols[index], isOn: Binding(
                            get: { selectedDays.contains(index + 1) },
                            set: { isSelected in
                                if isSelected {
                                    selectedDays.insert(index + 1)
                                } else {
                                    selectedDays.remove(index + 1)
                                }
                                updateStaffSchedule()
                            }
                        ))
                    }
                }
            }
        }
        .navigationTitle("Schedule Access")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
    
    private func updateStaffSchedule() {
        if isScheduleEnabled {
            staff.scheduledDays = Array(selectedDays)
            // Remove time constraints - staff can work all day on scheduled days
            staff.scheduleStartTime = nil
            staff.scheduleEndTime = nil
        } else {
            staff.scheduledDays = nil
            staff.scheduleStartTime = nil
            staff.scheduleEndTime = nil
        }
        staff.updatedAt = Date()
        try? modelContext.save()
    }
}

private struct AddStaffView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var showingError = false
    
    private var isFormValid: Bool {
        !name.isEmpty && !password.isEmpty && password == confirmPassword
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                SecureField("Confirm Password", text: $confirmPassword)
            }
            
            Section {
                Button("Add Staff Member") {
                    addStaffMember()
                }
                .disabled(!isFormValid)
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
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    private func addStaffMember() {
        // Check if name already exists
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.name == name
            }
        )
        
        do {
            let existingUsers = try modelContext.fetch(descriptor)
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
            
            modelContext.insert(newUser)
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to add staff member: \(error.localizedDescription)"
            showingError = true
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
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: User.self, configurations: config)
    
    return NavigationStack {
        StaffManagementView()
    }
    .modelContainer(container)
} 