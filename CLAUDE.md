# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview
Doggy DayCare is a professional iOS app for managing a dog daycare facility. It uses SwiftUI, CloudKit for backend, and follows modern iOS development patterns.

## Development Commands

### Build and Run
```bash
# Open in Xcode
open "Doggy DayCare.xcodeproj"

# Build from command line
xcodebuild -project "Doggy DayCare.xcodeproj" -scheme "Doggy DayCare" build

# Run tests
xcodebuild test -project "Doggy DayCare.xcodeproj" -scheme "Doggy DayCare" -destination 'platform=iOS Simulator,name=iPhone 15'

# Clean build
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