# CloudKit Schema Setup Guide for Doggy DayCare

## Overview
This document provides the complete CloudKit schema configuration needed for the Doggy DayCare app. All users will share the same data through the public CloudKit database.

## Prerequisites
1. Apple Developer Account
2. App ID with CloudKit enabled
3. CloudKit container created and configured

## CloudKit Dashboard Setup

### 1. Access CloudKit Dashboard
- Go to [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/)
- Select your app's CloudKit container
- Navigate to **Schema** tab

### 2. Create Record Types

#### Record Type: User
**Purpose**: Store staff and owner information

**Fields**:
- `id` (String, Queryable, Indexed)
- `name` (String, Queryable, Indexed)
- `email` (String, Queryable, Indexed)
- `isActive` (Int64, Queryable) - 1 = true, 0 = false
- `isOwner` (Int64, Queryable) - 1 = true, 0 = false
- `isWorkingToday` (Int64, Queryable) - 1 = true, 0 = false
- `isOriginalOwner` (Int64, Queryable) - 1 = true, 0 = false
- `createdAt` (Date/Time, Queryable)
- `updatedAt` (Date/Time, Queryable)
- `lastLogin` (Date/Time, Queryable)
- `scheduledDays` (Int64 (List), Queryable) - Array of weekday numbers
- `scheduleStartTime` (Date/Time, Queryable)
- `scheduleEndTime` (Date/Time, Queryable)
- `canAddDogs` (Int64, Queryable) - 1 = true, 0 = false
- `canAddFutureBookings` (Int64, Queryable) - 1 = true, 0 = false
- `canManageStaff` (Int64, Queryable) - 1 = true, 0 = false
- `canManageMedications` (Int64, Queryable) - 1 = true, 0 = false
- `canManageFeeding` (Int64, Queryable) - 1 = true, 0 = false
- `canManageWalking` (Int64, Queryable) - 1 = true, 0 = false
- `hashedPassword` (String, Queryable) - SHA-256 hashed password with salt
- `createdBy` (String, Queryable, Indexed)
- `modifiedBy` (String, Queryable, Indexed)
- `modificationCount` (Int64, Queryable)

#### Record Type: Dog
**Purpose**: Store dog information and status

**Fields**:
- `id` (String, Queryable, Indexed)
- `name` (String, Queryable, Indexed)
- `ownerName` (String, Queryable, Indexed)
- `arrivalDate` (Date/Time, Queryable)
- `departureDate` (Date/Time, Queryable)
- `boardingEndDate` (Date/Time, Queryable)
- `isBoarding` (Int64, Queryable) - 1 = true, 0 = false
- `isDaycareFed` (Int64, Queryable) - 1 = true, 0 = false
- `needsWalking` (Int64, Queryable) - 1 = true, 0 = false
- `walkingNotes` (String, Queryable)
- `medications` (String, Queryable)
- `allergiesAndFeedingInstructions` (String, Queryable)
- `notes` (String, Queryable)
- `profilePictureData` (Bytes, Queryable)
- `createdAt` (Date/Time, Queryable)
- `updatedAt` (Date/Time, Queryable)
- `createdBy` (String, Queryable, Indexed)
- `modifiedBy` (String, Queryable, Indexed)
- `modificationCount` (Int64, Queryable)

#### Record Type: DogChange
**Purpose**: Audit trail for all dog-related changes

**Fields**:
- `id` (String, Queryable, Indexed)
- `timestamp` (Date/Time, Queryable)
- `changeType` (String, Queryable, Indexed)
- `fieldName` (String, Queryable)
- `oldValue` (String, Queryable)
- `newValue` (String, Queryable)
- `dogID` (String, Queryable, Indexed)
- `modifiedBy` (String, Queryable, Indexed)
- `createdAt` (Date/Time, Queryable)

#### Record Type: FeedingRecord
**Purpose**: Track feeding activities for dogs

**Fields**:
- `id` (String, Queryable, Indexed)
- `timestamp` (Date/Time, Queryable)
- `type` (String, Queryable, Indexed)
- `notes` (String, Queryable)
- `recordedBy` (String, Queryable, Indexed)
- `dogID` (String, Queryable, Indexed)
- `createdAt` (Date/Time, Queryable)
- `updatedAt` (Date/Time, Queryable)

#### Record Type: MedicationRecord
**Purpose**: Track medication administration

**Fields**:
- `id` (String, Queryable, Indexed)
- `timestamp` (Date/Time, Queryable)
- `notes` (String, Queryable)
- `recordedBy` (String, Queryable, Indexed)
- `dogID` (String, Queryable, Indexed)
- `createdAt` (Date/Time, Queryable)
- `updatedAt` (Date/Time, Queryable)

#### Record Type: PottyRecord
**Purpose**: Track potty activities for dogs

**Fields**:
- `id` (String, Queryable, Indexed)
- `timestamp` (Date/Time, Queryable)
- `type` (String, Queryable, Indexed)
- `notes` (String, Queryable)
- `recordedBy` (String, Queryable, Indexed)
- `dogID` (String, Queryable, Indexed)
- `createdAt` (Date/Time, Queryable)
- `updatedAt` (Date/Time, Queryable)

## Security Configuration

### Public Database Permissions
Since this is a business app where all users need to see and modify the same data:

1. **Custom Role "Authenticated Users"** (Create this custom role):
   - **Create**: Allow
   - **Read**: Allow
   - **Write**: Allow

**Note**: The default `_world` role cannot be modified. Create a custom role called "Authenticated Users" with the permissions above.

### Indexes
Create indexes for frequently queried fields:
- `User.id`
- `User.name`
- `User.email`
- `Dog.id`
- `Dog.name`
- `Dog.arrivalDate`
- `DogChange.dogID`
- `DogChange.timestamp`
- `FeedingRecord.dogID`
- `MedicationRecord.dogID`
- `PottyRecord.dogID`

## Deployment

### Development Environment
1. Create all record types in **Development** environment
2. Test with development app builds
3. Verify all CRUD operations work correctly

### Production Environment
1. Deploy schema to **Production** environment
2. Test with TestFlight builds
3. Monitor CloudKit usage and quotas

## Important Notes

### Data Security
- All changes are tracked with audit trails
- User authentication is required for all operations
- Each record includes metadata about who created/modified it

### Performance Considerations
- Indexes are created on frequently queried fields
- Queries are optimized for common use cases
- Pagination is implemented for large datasets

### Backup and Recovery
- CloudKit automatically handles data backup
- Audit trails provide change history
- Data can be exported through CloudKit Dashboard

## Testing Checklist

- [ ] User authentication works
- [ ] Dogs can be created, read, updated, deleted
- [ ] Audit trails are created for all changes
- [ ] Multiple users can see the same data
- [ ] Changes sync across devices
- [ ] Feeding, medication, and potty records work
- [ ] Error handling works correctly
- [ ] Performance is acceptable with large datasets

## Support

If you encounter issues:
1. Check CloudKit Dashboard for errors
2. Verify schema matches exactly
3. Test with development environment first
4. Check Apple Developer forums for CloudKit issues