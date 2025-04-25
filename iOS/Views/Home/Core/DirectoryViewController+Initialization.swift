import UIKit

extension DirectoryViewController {
    /// Initialize with a directory URL and title
    /// - Parameters:
    ///   - directoryURL: The URL of the directory to display
    ///   - title: The title to display in the navigation bar
    convenience init(directoryURL: URL, title: String) {
        self.init(directory: directoryURL)
        self.title = title
    }
}
