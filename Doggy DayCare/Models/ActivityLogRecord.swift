import Foundation
import CloudKit

struct ActivityLogRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let userId: String
    let userName: String
    let action: String
    let timestamp: Date
    let dogId: String?
    let dogName: String?
    let details: String?
    
    init(id: UUID = UUID(), userId: String, userName: String, action: String, timestamp: Date = Date(), dogId: String? = nil, dogName: String? = nil, details: String? = nil) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.action = action
        self.timestamp = timestamp
        self.dogId = dogId
        self.dogName = dogName
        self.details = details
    }
    
    init?(from record: CKRecord) {
        guard
            let userId = record["userId"] as? String,
            let userName = record["userName"] as? String,
            let action = record["action"] as? String,
            let timestamp = record["timestamp"] as? Date
        else { return nil }
        self.id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        self.userId = userId
        self.userName = userName
        self.action = action
        self.timestamp = timestamp
        self.dogId = record["dogId"] as? String
        self.dogName = record["dogName"] as? String
        self.details = record["details"] as? String
    }
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "ActivityLogRecord", recordID: CKRecord.ID(recordName: id.uuidString))
        record["userId"] = userId as CKRecordValue
        record["userName"] = userName as CKRecordValue
        record["action"] = action as CKRecordValue
        record["timestamp"] = timestamp as CKRecordValue
        if let dogId = dogId { record["dogId"] = dogId as CKRecordValue }
        if let dogName = dogName { record["dogName"] = dogName as CKRecordValue }
        if let details = details { record["details"] = details as CKRecordValue }
        return record
    }
} 