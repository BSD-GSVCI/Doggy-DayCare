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
} 