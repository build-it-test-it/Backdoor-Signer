import UIKit

/// Floating button that provides quick access to the terminal
class FloatingTerminalButton: UIButton {
    // Default position values
    private let defaultPosition = CGPoint(x: 60, y: 500)
    private let cornerRadius: CGFloat = 25
    private let buttonSize: CGFloat = 50
    
    // Accessibility properties
    private let accessibilityEdgeMargin: CGFloat = 20
    private let minimumTouchArea: CGFloat = 60

    // Pan gesture for dragging the button
    private var panGesture: UIPanGestureRecognizer!

    // Logger instance
    private let logger = Debug.shared

    // Keys for saving position
    private let positionXKey = "floating_terminal_button_x"
    private let positionYKey = "floating_terminal_button_y"

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }

    private func setupButton() {
        // Configure button appearance
        frame = CGRect(x: 0, y: 0, width: buttonSize, height: buttonSize)
        layer.cornerRadius = cornerRadius

        // Shadow for better visibility
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 4

        // Button image
        let image = UIImage(systemName: "terminal")
        setImage(image, for: .normal)
        tintColor = .white
        imageView?.contentMode = .scaleAspectFit

        // Set up gestures
        setupGestures()

        // Set up appearance
        updateAppearance()

        // Add target action for tap
        addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        
        // Configure accessibility
        setupAccessibility()

        logger.log(message: "Floating terminal button initialized", type: .info)
    }
    
    private func setupAccessibility() {
        // Set accessibility traits
        accessibilityTraits = .button
        
        // Set accessibility label and hint
        accessibilityLabel = "Terminal"
        accessibilityHint = "Double tap to open terminal. Drag to move button."
        
        // Make sure it's accessible
        isAccessibilityElement = true
        
        // Increase hit area for better touch accessibility
        if #available(iOS 15.0, *) {
            // Use configuration for iOS 15+
            var config = UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
            configuration = config
        } else {
            // Use deprecated property for older iOS versions
            contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        }
    }

    private func setupGestures() {
        // Pan gesture for dragging
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        addGestureRecognizer(panGesture)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview else { return }

        let translation = gesture.translation(in: superview)

        switch gesture.state {
        case .began:
            // Animate a slight scale up when dragging begins
            UIView.animate(withDuration: 0.2) {
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }

        case .changed:
            // Update button position
            center = CGPoint(
                x: center.x + translation.x,
                y: center.y + translation.y
            )

            // Reset translation
            gesture.setTranslation(.zero, in: superview)

        case .ended, .cancelled:
            // Constrain to safe area with additional margin for accessibility
            let safeArea = superview.safeAreaInsets
            let minX = buttonSize / 2 + safeArea.left + accessibilityEdgeMargin
            let maxX = superview.bounds.width - buttonSize / 2 - safeArea.right - accessibilityEdgeMargin
            let minY = buttonSize / 2 + safeArea.top + accessibilityEdgeMargin
            let maxY = superview.bounds.height - buttonSize / 2 - safeArea.bottom - accessibilityEdgeMargin
            
            // Ensure button stays within accessible bounds
            var constrainedX = min(max(center.x, minX), maxX)
            var constrainedY = min(max(center.y, minY), maxY)
            
            // Snap to edge if close to it for better accessibility
            let edgeSnapThreshold: CGFloat = 30
            
            // Snap to left or right edge if close
            if constrainedX < minX + edgeSnapThreshold {
                constrainedX = minX
            } else if constrainedX > maxX - edgeSnapThreshold {
                constrainedX = maxX
            }
            
            // Snap to top or bottom edge if close
            if constrainedY < minY + edgeSnapThreshold {
                constrainedY = minY
            } else if constrainedY > maxY - edgeSnapThreshold {
                constrainedY = maxY
            }

            // Animate to constrained position
            UIView.animate(withDuration: 0.3, animations: {
                self.center = CGPoint(x: constrainedX, y: constrainedY)
                self.transform = .identity
            }) { _ in
                // Save position for future sessions
                self.savePosition()
            }

        default:
            break
        }
    }

    private func savePosition() {
        UserDefaults.standard.set(center.x, forKey: positionXKey)
        UserDefaults.standard.set(center.y, forKey: positionYKey)
    }

    private func restorePosition() {
        // Get saved position, or use default
        let x = UserDefaults.standard.double(forKey: positionXKey)
        let y = UserDefaults.standard.double(forKey: positionYKey)

        if x > 0 && y > 0 {
            center = CGPoint(x: x, y: y)
        } else {
            center = defaultPosition
        }
        
        // Ensure position is valid after restoration
        ensureAccessiblePosition()
    }
    
    /// Ensures the button is in an accessible position within the screen bounds
    private func ensureAccessiblePosition() {
        guard let superview = superview else { return }
        
        // Get safe area
        let safeArea = superview.safeAreaInsets
        
        // Calculate accessible bounds
        let minX = buttonSize / 2 + safeArea.left + accessibilityEdgeMargin
        let maxX = superview.bounds.width - buttonSize / 2 - safeArea.right - accessibilityEdgeMargin
        let minY = buttonSize / 2 + safeArea.top + accessibilityEdgeMargin
        let maxY = superview.bounds.height - buttonSize / 2 - safeArea.bottom - accessibilityEdgeMargin
        
        // Check if current position is outside bounds
        let currentX = center.x
        let currentY = center.y
        
        if currentX < minX || currentX > maxX || currentY < minY || currentY > maxY {
            // Calculate new position within bounds
            let newX = min(max(currentX, minX), maxX)
            let newY = min(max(currentY, minY), maxY)
            
            // Animate to new position
            UIView.animate(withDuration: 0.3) {
                self.center = CGPoint(x: newX, y: newY)
            } completion: { _ in
                self.savePosition()
            }
        }
    }

    /// Update button appearance based on system theme
    func updateAppearance() {
        // Get current trait collection
        let interfaceStyle = UIScreen.main.traitCollection.userInterfaceStyle

        if interfaceStyle == .dark {
            // Dark mode
            backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        } else {
            // Light mode
            backgroundColor = UIColor.systemBlue
        }
    }

    @objc private func buttonTapped() {
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Post notification to launch terminal
        NotificationCenter.default.post(name: .showTerminal, object: nil)

        logger.log(message: "Floating terminal button tapped", type: .info)
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        // Restore position when added to view
        if superview != nil {
            restorePosition()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        // Update appearance when theme changes
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateAppearance()
        }
    }
    
    // Override point inside to increase touch area
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Expand touch area for better accessibility
        let expandedBounds = bounds.insetBy(dx: -15, dy: -15)
        return expandedBounds.contains(point)
    }
    
    // Handle layout changes
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Ensure button is in accessible position after layout changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.ensureAccessiblePosition()
        }
    }
}

// Add notification names for terminal button control
extension Notification.Name {
    static let showTerminal = Notification.Name("showTerminal")
    static let showTerminalButton = Notification.Name("showTerminalButton")
    static let hideTerminalButton = Notification.Name("hideTerminalButton")
}
