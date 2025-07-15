import Foundation

extension DateFormatter {
    static let rfc3339: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    // Adding a formatter that handles fractional seconds for backward compatibility
    static let rfc3339WithMilliseconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    // PostgreSQL TIMESTAMPTZ formatter
    static let postgresTimestampTZ: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZZZ"  // Format for PostgreSQL TIMESTAMPTZ
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    static let localDisplay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = .current // Use local timezone for display
        return formatter
    }()
}

extension String {
    func formattedDate() -> String {
        // Try parsing with standard RFC3339 format first
        if let date = DateFormatter.rfc3339.date(from: self) {
            return DateFormatter.localDisplay.string(from: date)
        }
        
        // Try with milliseconds format 
        if let date = DateFormatter.rfc3339WithMilliseconds.date(from: self) {
            return DateFormatter.localDisplay.string(from: date)
        }
        
        // Try with PostgreSQL TIMESTAMPTZ format
        if let date = DateFormatter.postgresTimestampTZ.date(from: self) {
            return DateFormatter.localDisplay.string(from: date)
        }
        
        return self
    }
    
    func toDate() -> Date? {
        // Try all available date formats
        if let date = DateFormatter.rfc3339.date(from: self) {
            return date
        }
        
        if let date = DateFormatter.rfc3339WithMilliseconds.date(from: self) {
            return date
        }
        
        if let date = DateFormatter.postgresTimestampTZ.date(from: self) {
            return date
        }
        
        return nil
    }
}

extension Date {
    func formattedForDisplay() -> String {
        return DateFormatter.localDisplay.string(from: self)
    }
    
    func rfc3339String() -> String {
        return DateFormatter.rfc3339.string(from: self)
    }
}
