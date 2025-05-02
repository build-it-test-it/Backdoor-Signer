import UIKit

/// Manages the floating terminal button across the app
final class TerminalButtonManager {
    // Singleton instance
    static let shared = TerminalButtonManager()

    // UI components
    private let floatingButton = FloatingTerminalButton()

    // Thread-safe state tracking
    private let stateQueue = DispatchQueue(label: "com.backdoor.terminalButtonState", qos: .userInteractive)
    private var _isPresentingTerminal = false
    private var isPresentingTerminal: Bool {
        get { stateQueue.sync { _isPresentingTerminal } }
        set { stateQueue.sync { _isPresentingTerminal = newValue } }
    }

    // Setup state
    private var _isSetUp = false
    private var isSetUp: Bool {
        get { stateQueue.sync { _isSetUp } }
        set { stateQueue.sync { _isSetUp = newValue } }
    }

    // Parent view references
    private weak var parentViewController: UIViewController?
    private weak var parentView: UIView?

    // Recovery counter
    private var _recoveryAttempts = 0
    private var recoveryAttempts: Int {
        get { stateQueue.sync { _recoveryAttempts } }
        set { stateQueue.sync { _recoveryAttempts = newValue } }
    }

    private let maxRecoveryAttempts = 5 // Increased from 3 to 5 for better recovery

    // Monitor app state
    private var isAppActive = true
    
    // Position recovery timer
    private var positionCheckTimer: Timer?

    // Logger
    private let logger = Debug.shared

    private init() {
        logger.log(message: "TerminalButtonManager initialized", type: .info)

        // Configure button
        configureFloatingButton()

        // Set up observers
        setupObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        positionCheckTimer?.invalidate()
        logger.log(message: "TerminalButtonManager deinit", type: .debug)
    }

    private func configureFloatingButton() {
        // Ensure it's above other views but below AI button
        floatingButton.layer.zPosition = 998
        floatingButton.isUserInteractionEnabled = true
        
        // Start position check timer for continuous accessibility
        startPositionCheckTimer()
    }
    
    private func startPositionCheckTimer() {
        // Invalidate existing timer if any
        positionCheckTimer?.invalidate()
        
        // Create a new timer that periodically checks button position
        positionCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isAppActive, !self.isPresentingTerminal else { return }
            
            // Check if button is still accessible
            self.checkButtonAccessibility()
        }
    }
    
    private func checkButtonAccessibility() {
        // Skip if button is hidden or not in a view
        guard !floatingButton.isHidden, floatingButton.superview != nil else { return }
        
        // Check if button is visible on screen
        if let parentVC = parentViewController, parentVC.view.window != nil {
            // Get safe area
            let safeArea = parentVC.view.safeAreaInsets
            
            // Check if button is outside safe area
            let buttonFrame = floatingButton.frame
            let _ = parentVC.view.bounds
            
            // Add margin for better accessibility
            let margin: CGFloat = 20
            let accessibleBounds = parentVC.view.bounds.inset(by: UIEdgeInsets(
                top: safeArea.top + margin,
                left: safeArea.left + margin,
                bottom: safeArea.bottom + margin,
                right: safeArea.right + margin
            ))
            
            // If button is outside accessible bounds, reposition it
            if !accessibleBounds.contains(buttonFrame) {
                logger.log(message: "Terminal button outside accessible area, repositioning", type: .warning)
                updateButtonPosition()
            }
        }
    }

    private func setupObservers() {
        // Observe orientation changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )

        // Observe interface style changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateButtonAppearance),
            name: NSNotification.Name("UIInterfaceStyleChanged"),
            object: nil
        )

        // Listen for button taps
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTerminalRequest),
            name: .showTerminal,
            object: nil
        )

        // Listen for app lifecycle events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        // Listen for tab changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTabChange),
            name: .tabDidChange,
            object: nil
        )
        
        // Listen for keyboard appearance
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func handleKeyboardWillShow(_ notification: Notification) {
        guard !isPresentingTerminal, !floatingButton.isHidden, 
              let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let parentVC = parentViewController else { return }
        
        // Convert keyboard frame to view coordinates
        let keyboardFrameInView = parentVC.view.convert(keyboardFrame, from: nil)
        
        // Check if button overlaps with keyboard
        if floatingButton.frame.intersects(keyboardFrameInView) {
            // Move button above keyboard
            let newY = keyboardFrameInView.minY - floatingButton.frame.height - 20
            
            UIView.animate(withDuration: 0.3) {
                self.floatingButton.center.y = newY
            }
        }
    }
    
    @objc private func handleKeyboardWillHide(_ notification: Notification) {
        // Reset button position when keyboard hides
        if !isPresentingTerminal && !floatingButton.isHidden {
            updateButtonPosition()
        }
    }

    @objc private func handleTabChange(_: Notification) {
        // Skip if app is inactive
        guard isAppActive else {
            logger.log(message: "Tab change ignored - app inactive", type: .debug)
            return
        }

        // Wait for tab change to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            if !self.isPresentingTerminal {
                self.recoveryAttempts = 0
                self.attachToRootView()
            }
        }
    }

    private func attachToRootView() {
        // Skip if presenting terminal
        guard !isPresentingTerminal else {
            logger.log(message: "Skipping button attach - terminal is presenting", type: .debug)
            return
        }

        // Find top view controller
        guard let rootVC = UIApplication.shared.topMostViewController() else {
            logger.log(message: "No root view controller found", type: .error)
            
            // Retry after delay with exponential backoff
            let delay = min(pow(1.5, Double(recoveryAttempts)), 5.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                if self.recoveryAttempts < self.maxRecoveryAttempts {
                    self.recoveryAttempts += 1
                    self.attachToRootView()
                }
            }
            return
        }

        // Check view controller state
        guard !rootVC.isBeingDismissed, !rootVC.isBeingPresented,
              rootVC.view.window != nil, rootVC.isViewLoaded
        else {
            logger.log(message: "View controller in invalid state for button attachment", type: .warning)

            // Retry after delay with exponential backoff
            let delay = min(pow(1.5, Double(recoveryAttempts)), 5.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                if self.recoveryAttempts < self.maxRecoveryAttempts {
                    self.recoveryAttempts += 1
                    self.attachToRootView()
                }
            }
            return
        }

        // Clean up existing button
        floatingButton.removeFromSuperview()

        // Store parent references
        parentViewController = rootVC
        parentView = rootVC.view

        // Set frame size
        floatingButton.frame = CGRect(x: 0, y: 0, width: 50, height: 50)

        // Add to view
        rootVC.view.addSubview(floatingButton)

        // Ensure correct position
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak rootVC] in
            guard let self = self, let rootVC = rootVC else { return }

            // Adjust for safe area
            let safeArea = rootVC.view.safeAreaInsets
            let minX = 20 + safeArea.left
            let maxX = rootVC.view.bounds.width - 20 - safeArea.right
            let minY = 60 + safeArea.top
            let maxY = rootVC.view.bounds.height - 60 - safeArea.bottom

            // Adjust position if needed
            let currentCenter = self.floatingButton.center
            let xPos = min(max(currentCenter.x, minX), maxX)
            let yPos = min(max(currentCenter.y, minY), maxY)

            if xPos != currentCenter.x || yPos != currentCenter.y {
                UIView.animate(withDuration: 0.3) {
                    self.floatingButton.center = CGPoint(x: xPos, y: yPos)
                }
            }

            self.logger.log(message: "Terminal button positioned at \(self.floatingButton.center)", type: .debug)
        }

        // Mark setup complete
        isSetUp = true
        recoveryAttempts = 0

        logger.log(message: "Terminal button attached to root view", type: .info)
    }

    @objc private func handleOrientationChange() {
        DispatchQueue.main.async { [weak self] in
            self?.updateButtonPosition()
        }
    }

    private func updateButtonPosition() {
        // Skip if button is hidden or app inactive
        guard !floatingButton.isHidden, isAppActive else { return }

        // Verify parent is valid
        guard let parentVC = parentViewController, parentVC.view.window != nil,
              !parentVC.isBeingDismissed, !parentVC.isBeingPresented
        else {
            // Try to recover
            if recoveryAttempts < maxRecoveryAttempts {
                recoveryAttempts += 1
                logger.log(message: "Trying to recover terminal button (attempt \(recoveryAttempts))", type: .warning)
                attachToRootView()
            }
            return
        }

        // Reset recovery counter
        recoveryAttempts = 0

        // Update position for current orientation
        let safeArea = parentVC.view.safeAreaInsets
        
        // Calculate accessible position that doesn't interfere with common UI elements
        // Default to bottom right with margins
        let maxX = parentVC.view.bounds.width - 80 - safeArea.right
        let maxY = parentVC.view.bounds.height - 160 - safeArea.bottom
        
        // Check if current position is valid
        let currentCenter = floatingButton.center
        let _ = parentVC.view.bounds
        let buttonSize = floatingButton.frame.size
        
        // Add margin for better accessibility
        let margin: CGFloat = 20
        let minX = buttonSize.width/2 + safeArea.left + margin
        let minY = buttonSize.height/2 + safeArea.top + margin
        
        // Only animate if position needs adjustment
        if currentCenter.x < minX || currentCenter.x > maxX || 
           currentCenter.y < minY || currentCenter.y > maxY {
            
            // Calculate new position
            let newX = min(max(currentCenter.x, minX), maxX)
            let newY = min(max(currentCenter.y, minY), maxY)
            
            UIView.animate(withDuration: 0.3) {
                self.floatingButton.center = CGPoint(x: newX, y: newY)
            }
        }
    }

    @objc private func handleAppDidBecomeActive() {
        isAppActive = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }

            if !self.isPresentingTerminal {
                self.show()
            }
        }
        
        // Restart position check timer
        startPositionCheckTimer()
    }

    @objc private func handleAppWillResignActive() {
        isAppActive = false
        hide()
        
        // Invalidate timer when app is inactive
        positionCheckTimer?.invalidate()
        positionCheckTimer = nil
    }

    @objc private func updateButtonAppearance() {
        DispatchQueue.main.async { [weak self] in
            self?.floatingButton.updateAppearance()
        }
    }

    /// Show the terminal button
    func show() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Don't show if presenting terminal
            if self.isPresentingTerminal {
                return
            }

            // Make button visible
            self.floatingButton.isHidden = false

            // Attach if needed
            if !self.isSetUp || self.parentView?.window == nil {
                self.attachToRootView()
            } else {
                self.updateButtonPosition()
            }
        }
    }

    /// Hide the terminal button
    func hide() {
        DispatchQueue.main.async { [weak self] in
            self?.floatingButton.isHidden = true
        }
    }

    @objc private func handleTerminalRequest() {
        // Ensure we're on main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.handleTerminalRequest()
            }
            return
        }

        // Prevent multiple presentations
        if isPresentingTerminal {
            logger.log(message: "Already presenting terminal, ignoring request", type: .warning)
            return
        }

        // Set flag to prevent multiple presentations
        isPresentingTerminal = true

        // Haptic feedback
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()

        // Hide button
        hide()

        // Find top view controller
        guard let topVC = UIApplication.shared.topMostViewController() else {
            logger.log(message: "Could not find top view controller to present terminal", type: .error)
            isPresentingTerminal = false
            show() // Show button again
            return
        }

        // Check if view controller is in valid state
        if topVC.isBeingDismissed || topVC.isBeingPresented {
            logger.log(message: "View controller is in transition, delaying terminal presentation", type: .warning)

            // Delay and retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.isPresentingTerminal = false
                self?.handleTerminalRequest()
            }
            return
        }

        // Present terminal
        let terminalVC = TerminalViewController()
        let navController = UINavigationController(rootViewController: terminalVC)

        // Add dismiss handler
        let dismissButton = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissTerminal)
        )
        terminalVC.navigationItem.leftBarButtonItem = dismissButton

        // Present terminal
        topVC.present(navController, animated: true, completion: nil)
    }

    @objc private func dismissTerminal() {
        guard let presentingVC = UIApplication.shared.topMostViewController()?.presentingViewController else {
            isPresentingTerminal = false
            show()
            return
        }

        presentingVC.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.isPresentingTerminal = false
            self.show()
        }
    }
}
