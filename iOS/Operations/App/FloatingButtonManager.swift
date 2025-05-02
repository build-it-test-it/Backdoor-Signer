import SwiftUI
import UIKit

// MARK: - Notification Names

extension Notification.Name {
    static let showAIAssistant = Notification.Name("showAIAssistant")
    // Tab change notifications are defined in TabbarView.swift
}

/// Manages AI assistant functionality across the app
final class FloatingButtonManager {
    // Singleton instance
    static let shared = FloatingButtonManager()

    // Thread-safe state tracking with a dedicated queue
    private let stateQueue = DispatchQueue(label: "com.backdoor.floatingButtonState", qos: .userInteractive)
    private var _isPresentingChat = false
    private var isPresentingChat: Bool {
        get { stateQueue.sync { _isPresentingChat } }
        set { stateQueue.sync { _isPresentingChat = newValue } }
    }

    // Processing queue for handling asynchronous tasks
    private let processingQueue = DispatchQueue(label: "com.backdoor.floatingButtonProcessing", qos: .userInitiated)

    // Monitor whether app is in active state
    private var isAppActive = true

    private init() {
        // Log initialization
        Debug.shared.log(message: "AI Manager initialized", type: .info)

        // Set up notification observers
        setupObservers()

        // Set up the AI interaction
        setupAIInteraction()
    }

    deinit {
        // Clean up observers to prevent memory leaks
        NotificationCenter.default.removeObserver(self)
        Debug.shared.log(message: "AI Manager deinit", type: .debug)
    }

    private func setupObservers() {
        // Use processingQueue to ensure thread safety when setting up observers
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            // Listen for button taps
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.handleAIRequest),
                name: .showAIAssistant,
                object: nil
            )

            // Listen for app lifecycle events
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.handleAppDidBecomeActive),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.handleAppWillResignActive),
                name: UIApplication.willResignActiveNotification,
                object: nil
            )
        }
    }

    @objc private func handleAppDidBecomeActive() {
        isAppActive = true
    }

    @objc private func handleAppWillResignActive() {
        isAppActive = false
    }

    private func setupAIInteraction() {
        // Set up AI interaction
        Debug.shared.log(message: "AI interaction setup complete", type: .debug)
    }

    // MARK: - Public Methods

    /// Programmatically show the AI assistant
    func showAIAssistant() {
        handleAIRequest()
    }
    
    /// Show the floating button - wrapper for showAIAssistant
    func show() {
        showAIAssistant()
    }
    
    /// Hide the floating button
    func hide() {
        // Reset state if currently presenting
        if isPresentingChat {
            isPresentingChat = false
        }
        
        Debug.shared.log(message: "Floating button hidden", type: .debug)
    }

    // MARK: - AI Request Handling

    @objc private func handleAIRequest() {
        // Skip if already presenting or app is inactive
        guard !isPresentingChat, isAppActive else {
            Debug.shared.log(message: "Skipping AI request - already presenting or app inactive", type: .debug)
            return
        }

        // Set state to presenting
        isPresentingChat = true

        // Find the top view controller to present from
        guard let topVC = UIApplication.shared.topMostViewController() else {
            Debug.shared.log(message: "No view controller found to present AI assistant", type: .error)
            isPresentingChat = false
            return
        }

        // Skip if view controller is in transition
        guard !topVC.isBeingDismissed, !topVC.isBeingPresented else {
            Debug.shared.log(message: "View controller in transition, skipping AI request", type: .debug)
            isPresentingChat = false
            return
        }

        // Use a background task ID to ensure we have time to complete the task
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            // End the task if we run out of time
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }

        // Prepare chat data on background queue
        processingQueue.async { [weak self, weak topVC] in
            guard let self = self else {
                // End background task if we've been deallocated
                if backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                }
                return
            }

            do {
                // First verify the context exists with a try-catch
                guard let topVCStillValid = topVC, !topVCStillValid.isBeingDismissed else {
                    throw NSError(domain: "com.backdoor.aiManager", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "View controller no longer valid"])
                }

                // Update AI context
                AppContextManager.shared.updateContext(topVCStillValid)
                CustomAIContextProvider.shared.refreshContext()

                // Create a new chat session with error handling
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .short
                let timestamp = dateFormatter.string(from: Date())
                let title = "Chat on \(timestamp)"

                // Create the session with explicit error handling
                guard let session = try? CoreDataManager.shared.createAIChatSession(title: title) else {
                    throw NSError(domain: "com.backdoor.aiManager", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "Failed to create chat session"])
                }

                // Present the UI on the main thread
                DispatchQueue.main.async { [weak self, weak topVCStillValid] in
                    guard let self = self else {
                        if backgroundTaskID != .invalid {
                            UIApplication.shared.endBackgroundTask(backgroundTaskID)
                        }
                        return
                    }

                    // Verify view controller is still valid before presentation
                    if let validTopVC = topVCStillValid, !validTopVC.isBeingDismissed {
                        self.presentChatInterfaceSafely(with: session, from: validTopVC)
                    } else {
                        // Reset state if view controller is no longer valid
                        self.isPresentingChat = false
                        Debug.shared.log(
                            message: "View controller no longer valid for chat presentation",
                            type: .warning
                        )
                    }

                    // End background task
                    if backgroundTaskID != .invalid {
                        UIApplication.shared.endBackgroundTask(backgroundTaskID)
                        backgroundTaskID = .invalid
                    }
                }
            } catch {
                Debug.shared.log(message: "Failed to create chat session: \(error.localizedDescription)", type: .error)

                // Reset state and show UI feedback on main thread
                DispatchQueue.main.async { [weak self, weak topVC] in
                    guard let self = self else { return }
                    self.isPresentingChat = false

                    // Show error alert if view controller is still valid
                    if let validTopVC = topVC, !validTopVC.isBeingDismissed {
                        self.showErrorAlert(
                            message: "Chat initialization failed. Please try again later.",
                            on: validTopVC
                        )
                    }

                    // End background task
                    if backgroundTaskID != .invalid {
                        UIApplication.shared.endBackgroundTask(backgroundTaskID)
                        backgroundTaskID = .invalid
                    }
                }
            }
        }
    }

    private func presentChatInterfaceSafely(with session: ChatSession, from presenter: UIViewController) {
        // Validate the presenter is still valid and not in transition
        guard !presenter.isBeingDismissed,
              !presenter.isBeingPresented,
              !presenter.isMovingToParent,
              !presenter.isMovingFromParent,
              presenter.view.window != nil
        else {
            Debug.shared.log(message: "Cannot present chat - view controller in invalid state", type: .error)
            // Reset state
            isPresentingChat = false
            return
        }

        // Create chat view controller with the session
        let chatVC = ChatViewController(session: session)

        // Ensure we have a valid dismissal handler
        chatVC.dismissHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.isPresentingChat = false
            }
        }

        // Wrap in navigation controller for better presentation
        let navController = UINavigationController(rootViewController: chatVC)

        // Configure presentation style based on device
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad-specific presentation
            navController.modalPresentationStyle = .formSheet
            navController.preferredContentSize = CGSize(width: 540, height: 620)
        } else {
            // iPhone presentation
            if #available(iOS 15.0, *) {
                if let sheet = navController.sheetPresentationController {
                    // Use sheet presentation for iOS 15+
                    sheet.detents = [.medium(), .large()]
                    sheet.prefersGrabberVisible = true
                    sheet.preferredCornerRadius = 24

                    // Add delegate to handle dismissal properly
                    sheet.delegate = chatVC
                }
            } else {
                // Fallback for older iOS versions
                navController.modalPresentationStyle = .fullScreen
            }
        }

        // Ensure safe presentation
        presentViewControllerSafely(navController, from: presenter)
    }

    private func presentViewControllerSafely(_ viewController: UIViewController, from presenter: UIViewController) {
        // Check if presenter is valid - if not, reset state and return
        guard !presenter.isBeingDismissed, !presenter.isBeingPresented, presenter.view.window != nil else {
            Debug.shared.log(message: "Presenter view controller is in invalid state for presentation", type: .error)
            isPresentingChat = false
            return
        }

        // Handle pending dismissals of any currently presented view controller
        if let presentedVC = presenter.presentedViewController {
            // If there's already a presented VC, dismiss it first
            presentedVC.dismiss(animated: true) { [weak self, weak presenter, weak viewController] in
                guard let self = self,
                      let presenter = presenter,
                      let viewController = viewController,
                      !presenter.isBeingDismissed
                else {
                    self?.isPresentingChat = false
                    return
                }

                // Now present the chat interface
                self.performPresentation(viewController, from: presenter)
            }
        } else {
            // No existing presentation, present directly
            performPresentation(viewController, from: presenter)
        }
    }

    private func performPresentation(_ viewController: UIViewController, from presenter: UIViewController) {
        // Present directly without try-catch since UIKit presentation doesn't throw
        presenter.present(viewController, animated: true) {
            // Log success
            Debug.shared.log(message: "AI assistant presented successfully", type: .info)
        }

        // Handle presentation failure through the completion handler if needed
        // This is more reliable than a try-catch that will never be executed
    }

    private func showErrorAlert(message: String, on viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Chat Error",
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default))

        // Present alert with a slight delay to ensure any pending transitions complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if viewController.presentedViewController == nil, !viewController.isBeingDismissed {
                viewController.present(alert, animated: true)
            } else {
                // If we can't present, at least log the error
                Debug.shared.log(message: "Could not present error alert: \(message)", type: .error)
                self.isPresentingChat = false
            }
        }
    }
}
