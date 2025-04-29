import UIKit

extension UITabBar {
    /// Add LED effect to the tab bar with simplified parameters
    @objc func addTabBarLEDEffect(color: UIColor) {
        // Call the full implementation with default values
        addFlowingLEDEffect(
            color: color,
            intensity: 0.3,
            width: 2,
            speed: 5.0
        )
    }
}