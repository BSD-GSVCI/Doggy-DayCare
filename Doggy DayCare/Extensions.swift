import SwiftUI

// Phone number formatting utility
extension String {
    func formatPhoneNumber() -> String {
        // Remove all non-digit characters
        let digits = self.filter { $0.isNumber }
        
        // Handle different phone number formats
        if digits.count == 10 {
            // Standard US format: (123) 456 - 7890
            let areaCode = String(digits.prefix(3))
            let prefix = String(digits.dropFirst(3).prefix(3))
            let lineNumber = String(digits.dropFirst(6))
            return "(\(areaCode)) \(prefix) - \(lineNumber)"
        } else if digits.count == 11 && digits.hasPrefix("1") {
            // US with country code: +1 (123) 456 - 7890
            let areaCode = String(digits.dropFirst(1).prefix(3))
            let prefix = String(digits.dropFirst(4).prefix(3))
            let lineNumber = String(digits.dropFirst(7))
            return "+1 (\(areaCode)) \(prefix) - \(lineNumber)"
        } else if digits.count == 7 {
            // Local format: 456 - 7890
            let prefix = String(digits.prefix(3))
            let lineNumber = String(digits.dropFirst(3))
            return "\(prefix) - \(lineNumber)"
        }
        
        // Return original if no recognized format
        return self
    }
    
    func unformatPhoneNumber() -> String {
        // Remove all formatting characters, keep only digits
        return self.filter { $0.isNumber }
    }
    
    func formatPhoneNumberRealTime() -> String {
        // Remove all non-digit characters first
        let digits = self.filter { $0.isNumber }
        
        // Auto-add +1 if no country code and we have at least one digit
        var workingDigits = digits
        if digits.count >= 1 && !digits.hasPrefix("1") {
            workingDigits = "1" + digits
        }
        
        // Progressive formatting based on length
        switch workingDigits.count {
        case 0:
            return ""
        case 1:
            return "+1"
        case 2...4:
            let countryCode = String(workingDigits.prefix(1))
            let remaining = String(workingDigits.dropFirst(1))
            return "+\(countryCode) \(remaining)"
        case 5...7:
            let countryCode = String(workingDigits.prefix(1))
            let areaCode = String(workingDigits.dropFirst(1).prefix(3))
            let remaining = String(workingDigits.dropFirst(4))
            return "+\(countryCode) (\(areaCode)) \(remaining)"
        case 8...10:
            let countryCode = String(workingDigits.prefix(1))
            let areaCode = String(workingDigits.dropFirst(1).prefix(3))
            let prefix = String(workingDigits.dropFirst(4).prefix(3))
            let remaining = String(workingDigits.dropFirst(7))
            if remaining.isEmpty {
                return "+\(countryCode) (\(areaCode)) \(prefix)"
            } else {
                return "+\(countryCode) (\(areaCode)) \(prefix) - \(remaining)"
            }
        case 11:
            let countryCode = String(workingDigits.prefix(1))
            let areaCode = String(workingDigits.dropFirst(1).prefix(3))
            let prefix = String(workingDigits.dropFirst(4).prefix(3))
            let lineNumber = String(workingDigits.dropFirst(7))
            return "+\(countryCode) (\(areaCode)) \(prefix) - \(lineNumber)"
        default:
            // Handle longer numbers by truncating
            let truncated = String(workingDigits.prefix(11))
            return truncated.formatPhoneNumberRealTime()
        }
    }
} 