import Foundation
import Nuke

// Extension to add Objective-C exposed method for memory warning handling
extension ImageCache {
    @objc func removeAllImages() {
        // Clear all cached images
        ImageCache.shared.clearCache()
    }
}
