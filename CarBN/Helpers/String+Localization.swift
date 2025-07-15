// MARK: - String+Localization.swift
import Foundation

extension String {
    /// Returns a localized string, using self as the key.
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// Returns a localized string with format arguments, using self as the key.
    /// - Parameter args: The arguments to insert into the format string.
    /// - Returns: A localized string with the arguments inserted.
    func localizedFormat(_ args: CVarArg...) -> String {
        let localizedFormat = NSLocalizedString(self, comment: "")
        return String(format: localizedFormat, arguments: args)
    }
}