# History Feature Documentation

## Overview

The History feature provides a comprehensive backup system that records daily snapshots of all dogs present in the facility. This ensures that even if dogs disappear from the main page due to data issues, you have a complete record of who was present each day.

## Key Features

### 1. Daily Snapshots
- **Automatic Recording**: Daily snapshots are automatically recorded when the app fetches data
- **Manual Recording**: Owners can manually record snapshots from the main page menu
- **Complete Information**: Each snapshot includes all important dog information:
  - Name and owner information
  - Profile pictures
  - Arrival and departure times
  - Service type (boarding/daycare)
  - Medical information and special instructions
  - Walking requirements and notes

### 2. History View
- **Date Selection**: Choose any date to view historical records
- **Filtering**: Filter by service type (boarding/daycare) or status (present/departed)
- **Search**: Search dogs by name or owner name
- **Detailed View**: Tap any dog to see complete historical information

### 3. Data Management
- **Local Storage**: All history records are stored locally using UserDefaults
- **Export Functionality**: Export all history as CSV file
- **Automatic Cleanup**: Old records (90+ days) are automatically cleaned up
- **Manual Cleanup**: Owners can manually trigger cleanup

## How to Use

### Accessing History
1. From the main page, tap the clock icon (🕐) in the toolbar
2. This opens the History view showing today's records by default

### Recording Snapshots
- **Automatic**: Snapshots are recorded automatically when data is fetched
- **Manual**: From the main page menu (three dots), select "Record Today's History"

### Viewing Historical Data
1. In the History view, tap the date button to select a different date
2. Use the filter buttons to show specific types of dogs
3. Use the search bar to find specific dogs
4. Tap any dog to see detailed historical information

### Exporting Data
1. In the History view, tap the menu button (three dots)
2. Select "Export History"
3. Choose how to share the CSV file

## Technical Details

### Data Structure
Each history record (`DogHistoryRecord`) contains:
- Complete dog information at the time of recording
- Date and time of the snapshot
- All medical and care information
- Service type and status

### Storage
- Records are stored locally using UserDefaults
- JSON encoding/decoding for persistence
- Automatic cleanup of old records

### Background Tasks
- Daily snapshots are recorded automatically
- Midnight transitions trigger snapshot recording
- Background tasks ensure data is preserved

## Benefits

1. **Data Backup**: Complete backup of daily operations
2. **Audit Trail**: Track which dogs were present each day
3. **Troubleshooting**: Identify when dogs disappeared from the system
4. **Compliance**: Maintain records for business purposes
5. **Peace of Mind**: Know that daily operations are preserved

## Troubleshooting

### If History is Empty
1. Check if you're viewing the correct date
2. Try manually recording a snapshot from the main page menu
3. Verify that the app has fetched data recently

### If Export Fails
1. Ensure you have sufficient storage space
2. Try sharing to a different app (Files, Mail, etc.)
3. Check that the history contains data

### If Records are Missing
1. Check the date selection
2. Try refreshing the history view
3. Verify that snapshots were recorded for that date

## Future Enhancements

- Cloud backup of history records
- Advanced filtering and search
- Statistical analysis of historical data
- Integration with reporting systems 