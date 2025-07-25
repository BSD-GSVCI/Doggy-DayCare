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
- **CloudKitService** (`CloudKitService.swift`): CloudKit backend integration, manages sync with public database
- **AuthenticationService** (`AuthenticationService.swift`): User authentication and session management

### Data Flow
1. Views observe ViewModels (DataManager, AuthenticationService) via `@StateObject`/`@EnvironmentObject`
2. ViewModels call CloudKitService for data operations
3. CloudKitService syncs with CloudKit public database
4. All changes tracked in audit trail (DogChange records)

### Key Patterns
- **MVVM**: Views + Observable ViewModels
- **Singleton Services**: `DataManager.shared`, `CloudKitService.shared`
- **Reactive UI**: SwiftUI with `@Published` properties
- **Async/Await**: Modern concurrency throughout

### Data Models
- **Dog**: Main entity with nested records (feeding, medication, potty, walking)
- **User**: Staff/owner with role-based permissions
- **Record Types**: FeedingRecord, MedicationRecord, PottyRecord, WalkingRecord
- **Audit**: DogChange records track all modifications

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
- Record types: User, Dog, DogChange, FeedingRecord, MedicationRecord, PottyRecord

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

## Important Files
- `ContentView.swift`: Main dashboard
- `DataManager.swift`: Core business logic
- `CloudKitService.swift`: Backend sync
- `Dog.swift`: Main data model
- `DEVELOPMENT_GUIDELINES.md`: Critical development rules
- `CloudKit_Schema_Setup.md`: Backend schema reference