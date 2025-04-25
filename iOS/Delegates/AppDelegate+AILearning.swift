import Foundation
import UIKit

extension AppDelegate {
    // MARK: - AI Learning Integration

    /// Initialize AI Learning system
    func initializeAILearning() {
        // Enable AI learning by default
        if UserDefaults.standard.object(forKey: "AILearningEnabled") == nil {
            AILearningManager.shared.setLearningEnabled(true)
        }

        // Enable server sync by default
        if UserDefaults.standard.object(forKey: "AIServerSyncEnabled") == nil {
            AILearningManager.shared.setServerSyncEnabled(true)
        }

        // Add notification observer for model updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleModelUpdate),
            name: Notification.Name("AIModelUpdated"),
            object: nil
        )

        Debug.shared.log(message: "AI Learning system initialized", type: .info)
    }

    @objc func handleModelUpdate() {
        Debug.shared.log(message: "AI model updated with local learning", type: .info)

        // Reload the model in CoreMLManager
        CoreMLManager.shared.loadModelWithLocalLearning()
    }
}
