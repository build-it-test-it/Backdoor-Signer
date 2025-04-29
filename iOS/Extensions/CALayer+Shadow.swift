import UIKit

extension CALayer {
    /// Apply a blue tinted shadow effect to the layer
    func applyBlueTintedShadow() {
        masksToBounds = false
        shadowColor = UIColor.systemBlue.cgColor
        shadowOffset = CGSize(width: 0, height: 4)
        shadowOpacity = 0.2
        shadowRadius = 8
    }
}