# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview
Doggy DayCare is a professional iOS app for managing a dog daycare facility. It uses SwiftUI, CloudKit for backend, and follows modern iOS development patterns.

## Development Commands

**IMPORTANT: Do NOT build the project via command line to check for compilation errors. The user will compile in Xcode and provide error details if needed.**

### Build and Run
```bash
# Open in Xcode
open "Doggy DayCare.xcodeproj"

# Build from command line (ONLY if user explicitly requests)
xcodebuild -project "Doggy DayCare.xcodeproj" -scheme "Doggy DayCare" build

# Run tests (ONLY if user explicitly requests)
xcodebuild test -project "Doggy DayCare.xcodeproj" -scheme "Doggy DayCare" -destination 'platform=iOS Simulator,name=iPhone 15'

# Clean build (ONLY if user explicitly requests)
xcodebuild clean -project "Doggy DayCare.xcodeproj" -scheme "Doggy DayCare"
```

## Architecture

### Core Components
- **DataManager** (`DataManager.swift`): Main data orchestration layer, singleton pattern, handles all data operations
- **PersistentDogService** (`PersistentDogService.swift`): Manages persistent dog data (profiles, statistics)
- **VisitService** (`VisitService.swift`): Manages visit records and activity tracking
- **CloudKitService** (`CloudKitService.swift`): Legacy backend integration (being phased out)
- **AuthenticationService** (`AuthenticationService.swift`): User authentication and session management

### NEW Data Architecture (PersistentDog + Visit System)
**Migration completed as of commit 3e94279**

#### Two-Entity Model:
1. **PersistentDog**: Stable dog profile data that persists across visits
   - Basic info (name, owner, phone, age, gender, vaccinations)
   - Behavioral settings (needsWalking, walkingNotes, isDaycareFed, notes, specialInstructions)
   - Visit statistics (visitCount, lastVisitDate) - automatically maintained
   - Profile picture and medical info
   
2. **Visit**: Individual daycare/boarding sessions
   - Linked to PersistentDog via dogId
   - Activity records (feeding, medication, potty, walking) stored as arrays
   - Session info (arrival/departure dates, boarding status)
   - Medications and scheduled medications for this visit

#### UI Wrapper:
- **DogWithVisit**: Combines PersistentDog + current Visit for UI display
- Provides unified interface while maintaining data separation

### Data Flow
1. Views observe DataManager via `@StateObject`/`@EnvironmentObject`
2. DataManager orchestrates PersistentDogService and VisitService calls
3. Services sync with CloudKit public database using individual record types
4. Visit completion automatically updates PersistentDog statistics (visitCount, lastVisitDate)

### Key Patterns
- **MVVM**: Views + Observable ViewModels
- **Singleton Services**: `DataManager.shared`, `PersistentDogService.shared`, `VisitService.shared`
- **Reactive UI**: SwiftUI with `@Published` properties
- **Async/Await**: Modern concurrency throughout
- **Data Separation**: Persistent vs transient data clearly separated

### Data Models
- **PersistentDog**: Stable dog profile with visit statistics
- **Visit**: Individual daycare/boarding session with activities
- **DogWithVisit**: UI wrapper combining both for display
- **User**: Staff/owner with role-based permissions
- **Record Types**: FeedingRecord, MedicationRecord, PottyRecord, WalkingRecord
- **Activity Arrays**: Individual activity records stored as CloudKit arrays for efficiency

## Critical Development Rules

### From DEVELOPMENT_GUIDELINES.md:
1. **NEVER MAKE ASSUMPTIONS** - Always examine actual code implementation
2. **ALWAYS VERIFY BEFORE CHANGING** - Read implementation, understand current behavior
3. **BE THOROUGH IN ANALYSIS** - Consider full impact, check edge cases
4. **ASK CLARIFYING QUESTIONS** - Better to ask than assume

### Business Critical App
- Real business data - users depend on correctness
- Test thoroughly before committing
- Preserve existing functionality unless explicitly asked to change
- Document significant changes

### Debug Code Requirements (MANDATORY)
**ALL debugging-related code must be wrapped in `#if DEBUG` directives:**

```swift
#if DEBUG
print("Debug message here")
// Other debug-only code
#endif
```

**Critical Rules:**
1. **ALWAYS wrap new debug print statements** in `#if DEBUG` directives
2. **ALWAYS wrap debug-only code blocks** (logging, test helpers, dev tools)
3. **NEVER wrap production functionality** just because it contains one debug statement
4. **Separate debug code from production code** - extract debug statements when needed
5. **This prevents debug code from impacting release builds** and avoids performance overhead

**Examples:**

✅ **Correct - Debug statement wrapped:**
```swift
func saveData() {
    let result = performSave()
    #if DEBUG
    print("Save completed with result: \(result)")
    #endif
    return result
}
```

❌ **Incorrect - Wrapping production functionality:**
```swift
#if DEBUG
func saveData() {
    let result = performSave()
    print("Save completed with result: \(result)")
    return result
}
#endif
```

✅ **Correct - Separate debug from production:**
```swift
func saveData() {
    let result = performSave()
    
    #if DEBUG
    print("Save completed with result: \(result)")
    debugLogSaveOperation(result)
    #endif
    
    return result
}
```

**This is mandatory for all new code** - no exceptions. This prevents the current codebase-wide debug wrapping effort from being needed in the future.

## CloudKit Requirements
- Requires Apple Developer account with CloudKit container
- Uses public database for shared data across all users
- Schema defined in `CloudKit_Schema_Setup.md`
- **NEW Record Types**: User, PersistentDog, Visit
- **Legacy Record Types**: Dog, DogChange (being phased out)
- Activity records now stored as arrays within Visit records for better performance

## Testing
- Unit tests in `DoggyDayCareTests.swift`
- Tests use in-memory data, not CloudKit
- Performance tests for filtering and date calculations
- Always run tests before committing changes

## Key Features
- **Dog Management**: Check-in/out, profile management
- **Activity Tracking**: Feeding, medication, potty, walking records
- **User Roles**: Owner vs Staff permissions
- **Real-time Sync**: CloudKit synchronization
- **History/Backup**: Daily snapshots, export capabilities
- **Background Tasks**: Automated backups, midnight transitions
- **Incremental Sync**: Optimized data fetching

## Common Tasks

### Adding a New Feature
1. Check existing patterns in similar features
2. Update data models if needed
3. Add CloudKit fields (follow schema in `CloudKit_Schema_Setup.md`)
4. Update DataManager for business logic
5. Create/update views following SwiftUI patterns
6. Add unit tests
7. Test CloudKit sync functionality

### Debugging CloudKit Issues
1. Check CloudKit Dashboard for server errors
2. Verify schema matches `CloudKit_Schema_Setup.md`
3. Check `CloudKitService.swift` for sync logic
4. Enable verbose logging in CloudKitService
5. Test with development CloudKit environment first

### Performance Optimization
- Use incremental sync (already implemented)
- Cache data appropriately (see DataManager caching)
- Profile with Instruments for bottlenecks
- Consider pagination for large datasets

## Migration History

### Major Architecture Migration (Completed: commit 3e94279)
**Problem**: Original system had scalability issues where dogs would disappear due to:
- Every visit had its own UUID causing data racing
- Incomplete fetching and server timeouts
- Lack of fallback safety nets
- Inefficient `fetchAllVisits()` loading massive datasets

**Solution**: Migrated to PersistentDog + Visit architecture:
- **PersistentDog**: Stable entity that never disappears
- **Visit**: Separate records linked by dogId
- **Automatic Statistics**: visitCount and lastVisitDate maintained on checkout
- **Scalable Queries**: Date-ranged queries instead of loading all data
- **Data Integrity**: Clear separation prevents racing conditions

**Key Files Changed**:
- `PersistentDog.swift`: New stable dog entity
- `Visit.swift`: New visit entity with activity arrays
- `DogWithVisit.swift`: UI wrapper combining both
- `PersistentDogService.swift`: Service for dog profiles
- `VisitService.swift`: Service for visit management
- `DataManager.swift`: Updated orchestration logic

**Removed Features**:
- `DeleteLogView.swift`: Debugging tool no longer needed
- Migration infrastructure: Temporary migration code removed

**Legacy Fields (DO NOT USE in new architecture)**:
- **`isDeleted` flag**: Used in old architecture for "soft delete" where every visit had its own UUID. In the new PersistentDog + Visit architecture, visits should be truly deleted from CloudKit when no longer needed, not marked with a flag. The `isDeleted` field exists in CloudKit schema for backward compatibility but should NOT be used in new code.
- **Rationale**: Old system needed soft delete because visit UUIDs were the primary identifier. New system uses stable PersistentDog entities, so visits can be safely deleted without losing dog data.

## Commit Message Format
When creating git commits, use simple, clean commit messages with bullet points:
- Do NOT include "Generated with Claude Code" footer
- Do NOT include "Co-Authored-By: Claude" footer  
- Use bullet points to describe changes
- Keep commit titles concise and descriptive

Example format:
```
Fix caching issues and update architecture

- Fixed activity records system to use Visit architecture
- Updated AutomationService to use new PersistentDog + Visit architecture
- Removed problematic midnight departure date clearing
```

## Important Files
- `ContentView.swift`: Main dashboard
- `DataManager.swift`: Core business logic and orchestration
- `PersistentDogService.swift`: Dog profile management
- `VisitService.swift`: Visit and activity management  
- `DogWithVisit.swift`: UI wrapper for combined data
- `PersistentDog.swift`: Stable dog entity model
- `Visit.swift`: Visit entity model
- `CloudKitService.swift`: Legacy backend sync (being phased out)
- `DEVELOPMENT_GUIDELINES.md`: Critical development rules
- `CloudKit_Schema_Setup.md`: Backend schema reference

## Recent Debug Wrapping Progress (Current State: commit 893810f)

### Completed Debug Wrapping:
- ✅ AuthenticationService.swift - All debug statements wrapped
- ✅ CloudKitHistoryService.swift - All debug statements wrapped  
- ✅ CloudKitService.swift - Partially wrapped (Sessions 1-2 completed)

### Debug Wrapping Still Needed:
- CloudKitService.swift - Remaining portions
- DataManager.swift
- PersistentDogService.swift
- VisitService.swift
- Other service files

### Debug Wrapping Rules:
1. Wrap ONLY debug print statements and debug-only code blocks
2. NEVER wrap production functionality
3. Keep debug statements close to their related production code
4. Use proper indentation within #if DEBUG blocks

## Critical Architecture Notes

### CloudKit Record System (IMPORTANT - DO NOT CHANGE):
The app uses **auto-generated CloudKit record IDs** with UUID tracking in record fields. This is the correct approach and must be preserved:

```swift
// CORRECT - How records are created:
let record = CKRecord(recordType: RecordTypes.visit)  // Auto-generated ID
record["id"] = visit.id.uuidString  // Track UUID in field

// CORRECT - How records are found and deleted:
let predicate = NSPredicate(format: "id == %@", visit.id.uuidString)
let query = CKQuery(recordType: RecordTypes.visit, predicate: predicate)
let result = try await publicDatabase.records(matching: query)
let records = result.matchResults.compactMap { try? $0.1.get() }
guard let record = records.first else { throw error }
try await publicDatabase.deleteRecord(withID: record.recordID)
```

### Data Flow Understanding:
1. **DataManager.dogs array**: Contains only currently present dogs and dogs that departed today
   - Created using `DogWithVisit.currentlyPresentFromPersistentDogsAndVisits`
   - Does NOT include future bookings

2. **Future Bookings**: Need separate handling
   - FutureBookingsView currently filters from dataManager.dogs (which won't work)
   - Future visits have arrival dates > today

3. **DogWithVisit.isArrivalTimeSet**: Currently defined as `currentVisit != nil`
   - This causes issues for departed dogs who lose their currentVisit reference

### Key Service Responsibilities:
- **PersistentDogService**: Manages stable dog profiles (never deleted during visits)
- **VisitService**: Manages individual visit records and activities
- **DataManager**: Orchestrates between services, maintains local cache
- **CloudKitService**: Legacy service being phased out

### Important Behavioral Notes:
1. After dog departure, the visit's departureDate is set but the visit remains
2. Deleted visits should actually be deleted from CloudKit, not just marked
3. The app is business-critical - data integrity is paramount
4. User explicitly stated: "people's livelihood depends on accurate data"

## Enterprise Data Integrity System (Current Architecture)

### NEW: DataIntegrityCache System
**Implemented**: Replaced the problematic dual-cache system with enterprise-grade unified cache

The original caching system had critical flaws:
- **Race Conditions**: Dual caches (`persistent_dogs_cache` + `active_visits_cache`) with different expiration times
- **Non-Atomic Updates**: Cache updates weren't synchronized, causing data inconsistencies
- **No Rollback**: CloudKit failures left cache in corrupted state
- **Missing Conflict Resolution**: No handling of multi-user simultaneous edits

### Core Components Added:

#### 1. **DataIntegrityCache** (`DataIntegrityCache.swift`)
- **Unified Cache**: Single atomic cache replacing dual-cache system
- **Thread-Safe**: Concurrent queue with barrier operations
- **Version Tracking**: Every cache change increments version number
- **Pending Operations**: Tracks operations awaiting CloudKit confirmation
- **Atomic Transactions**: All-or-nothing updates (UI + Cache + CloudKit)
- **Automatic Rollback**: Reverts to original state on CloudKit failures

#### 2. **ConflictResolver** (`ConflictResolver.swift`)
- **Business Logic Conflicts**: Prevents operations on departed/deleted dogs
- **Field-Level Merging**: Resolves conflicting field updates intelligently
- **Activity Record Merging**: Combines all unique activity records (never loses data)
- **Precedence Rules**: Owner changes > Medical > Staff > Activity records
- **Pre-Operation Conflict Detection**: Checks for conflicts before attempting operations
- **User Role Awareness**: Different resolution strategies based on user permissions

#### 3. **Multi-User Sync System**
- **Background Sync**: Every 15 seconds to detect changes from other users
- **Smart Sync**: Only syncs when needed (cache age > 30 seconds)
- **Conflict Resolution**: Automatically merges changes during sync
- **Pending Operation Preservation**: Local changes preserved during multi-user sync

### Data Integrity Guarantees:

1. **Atomic Operations**: All data changes are atomic across UI, Cache, and CloudKit
2. **Rollback on Failure**: Any CloudKit failure automatically reverts all changes
3. **Multi-User Consistency**: Changes from other staff appear within 15 seconds
4. **Conflict Prevention**: Business rules prevent invalid operations (e.g., feeding departed dogs)
5. **Data Validation**: Real-time integrity checks detect and report inconsistencies
6. **Activity Record Protection**: Never lose feeding/medication/potty records during conflicts

### Key Improvements:

#### Fixed Issues:
- ✅ **Dogs Disappearing Bug**: Replaced cache refresh with direct UI updates in `addDogWithVisit`
- ✅ **Race Conditions**: Unified cache eliminates dual-cache synchronization issues
- ✅ **CloudKit Failures**: Automatic rollback preserves data integrity
- ✅ **Multi-User Conflicts**: Intelligent merging of simultaneous edits
- ✅ **Data Loss**: Activity records are always preserved and merged

#### Business Critical Features:
- ✅ **Data Accuracy**: All operations validated before execution
- ✅ **Real-Time Updates**: Changes from other users appear automatically
- ✅ **Conflict Protection**: Prevents invalid operations (feeding checked-out dogs)
- ✅ **Audit Trail**: All conflicts and resolutions logged for debugging
- ✅ **Performance**: Responsive UI with background CloudKit sync

### Updated Important Files:
- `DataIntegrityCache.swift`: Enterprise-grade unified cache system
- `ConflictResolver.swift`: Multi-user conflict resolution engine
- `DataManager.swift`: Updated to use new atomic transaction system

### Migration Notes:
- **Old System**: Dual caches with `AdvancedCache.shared.get/set`
- **New System**: Unified `DataIntegrityCache.shared` with atomic operations
- **Breaking Change**: All data operations now go through transaction system
- **Backward Compatibility**: Old cache methods deprecated but functional

### Critical Rules for New System:
1. **ALWAYS use DataIntegrityCache for data operations**
2. **NEVER bypass the transaction system**
3. **ALL CloudKit operations must include rollback capability**
4. **Conflict detection is mandatory for user-facing operations**
5. **Multi-user sync must preserve pending local operations**

This system ensures **absolute data integrity** for the business-critical application where "people's livelihood depends on accurate data."

## Recent Improvements (Session Updates)

### Field-Level Conflict Resolution 
**Problem**: Original conflict resolver created entire new `DogWithVisit` instances for every conflict
- Extremely inefficient (10 users × 100 operations × 10 dogs = 10,000 new objects)
- Memory intensive and battery consuming
- Against the PersistentDog + Visit architecture principles

**Solution**: Redesigned to use field-level updates
- `ConflictResolution` now returns `FieldUpdate` and `RecordMerge` instructions
- Updates specific fields in-place without object creation
- Activity records are merged efficiently without duplication
- Example: Updates just `ownerName` field instead of creating entire new dog instance

### Key Components:
```swift
struct FieldUpdate {
    let dogId: UUID
    let fieldPath: String  // "persistentDog.ownerName"
    let newValue: Any
    let reason: String
}

struct RecordMerge {
    let dogId: UUID
    let recordType: RecordType  // .feeding, .medication, .potty
    let recordsToAdd: [Any]
    let recordsToRemove: [UUID]
    let reason: String
}
```

### Equatable Protocol Implementation
**Purpose**: Enable efficient change detection in multi-user sync
- Added `Equatable` conformance to entire data model chain
- Allows `if self.dogs != updatedDogs` comparison for change detection
- Prevents unnecessary UI updates and CloudKit syncs

**Conformance Chain**:
- `DogWithVisit: Equatable`
- `PersistentDog: Equatable`
- `Visit: Equatable`
- All record types: `FeedingRecord`, `MedicationRecord`, `PottyRecord`, `Medication`, `ScheduledMedication`: Equatable

### Multi-User Sync Timer Fix
**Problem**: `deinit` cannot safely call `@MainActor` methods
**Solution**: Direct timer invalidation without Task wrapper
```swift
deinit {
    multiUserSyncTimer?.invalidate()
    multiUserSyncTimer = nil
}
```

### Performance Optimizations
- **Field-level updates**: Only modified fields are updated
- **Efficient merging**: Activity records merged without object recreation
- **Smart comparison**: Equatable prevents unnecessary updates
- **Reduced memory footprint**: No temporary object creation during conflicts
- **Battery efficient**: Minimal CPU usage for conflict resolution

### Data Integrity Enhancements
- **Atomic field updates**: Each field update is atomic
- **Preserved record ordering**: Activity records maintain chronological order
- **Duplicate detection**: 5-second window for activity record deduplication
- **Precedence rules maintained**: Owner > Medical > Staff > Activity records

### Critical Implementation Notes:
1. **Never create new instances for conflicts** - Always update in-place
2. **Activity records are append-only** - Never delete, only merge
3. **Equatable is required for change detection** - All types must conform
4. **Timer cleanup in deinit must be synchronous** - No Tasks or async operations