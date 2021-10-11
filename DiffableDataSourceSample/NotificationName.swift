/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An extension that declares app-specific notification names.
*/

import Foundation

/// - Tag: NSNotification.Name
extension NSNotification.Name {
    static let recipeDidChange = Notification.Name("com.example.apple-samplecode.DiffableDataSourceSample.recipeDidChange")
}

// Custom keys to use with userInfo dictionaries.
enum NotificationKeys: String {
    case recipeId
}
