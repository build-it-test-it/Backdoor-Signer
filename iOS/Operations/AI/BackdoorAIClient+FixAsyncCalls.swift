import Foundation

/// Extension for BackdoorAIClient to ensure all async calls are properly awaited
extension BackdoorAIClient {
    // Fixed method to support access to the private member variable
    var modelVersionKey: String {
        return "currentModelVersion"
    }

    // Other utility methods can be added here
}
