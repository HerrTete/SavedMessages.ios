import Foundation

enum StorageConstants {
    static let appGroupID = "group.com.HerrTete.SavedMessages"
    static let iCloudContainerID = "iCloud.com.HerrTete.SavedMessages"
    static let itemsFileName = "items.json"
    static let filesDirectoryName = "Files"

    static var appGroupURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    static var filesURL: URL? {
        appGroupURL?.appendingPathComponent(filesDirectoryName, isDirectory: true)
    }

    static var itemsFileURL: URL? {
        appGroupURL?.appendingPathComponent(itemsFileName)
    }
}
