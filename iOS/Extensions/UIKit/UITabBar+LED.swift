import UIKit

extension UITabBar {
    /// Add LED effect to the tab bar with simplified parameters
    /// With improved error handling to prevent crashes
    @objc func addTabBarLEDEffect(color: UIColor) {
        // Skip adding effects if not in view hierarchy or not visible
        guard window != nil, !isHidden, superview != nil else {
            Debug.shared.log(message: "Skipping LED effect - tab bar not ready", type: .warning)
            return
        }
        
        // Use a milder effect to prevent performance issues
        let safeIntensity: CGFloat = 0.2 // Reduced from 0.3
        let safeWidth: CGFloat = 1.5  // Reduced from 2.0
        let safeSpeed: TimeInterval = 6.0 // Increased from 5.0 (slower animation)
        
        // Add with try-catch to prevent crashes
        do {
            // Don't execute on main thread to avoid UI blocking
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                // Switch back to main thread for UI updates
                DispatchQueue.main.async {
                    // Use the main method with safer values
                    self.addFlowingLEDEffect(
                        color: color,
                        intensity: safeIntensity,
                        width: safeWidth,
                        speed: safeSpeed
                    )
                    
                    Debug.shared.log(message: "Tab bar LED effect applied successfully", type: .debug)
                }
            }
        } catch {
            // Log any errors
            Debug.shared.log(message: "Failed to apply tab bar LED effect: \(error.localizedDescription)", type: .error)
        }
    }
}