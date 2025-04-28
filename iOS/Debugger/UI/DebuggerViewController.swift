import UIKit

/// Protocol for debugger view controller delegate
protocol DebuggerViewControllerDelegate: AnyObject {
    /// Called when the debugger view controller requests dismissal
    func debuggerViewControllerDidRequestDismissal(_ viewController: DebuggerViewController)
}

/// Main view controller for the debugger UI
class DebuggerViewController: UIViewController {
    // MARK: - Properties

    /// Delegate for handling view controller events
    weak var delegate: DebuggerViewControllerDelegate?

    /// The debugger engine
    private let debuggerEngine = DebuggerEngine.shared

    /// Logger instance
    private let logger = Debug.shared

    /// Tab bar controller for different debugger features
    private let tabBarController = UITabBarController()

    /// View controllers for each tab
    private var viewControllers: [UIViewController] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationBar()
        setupTabBarController()

        logger.log(message: "DebuggerViewController loaded", type: .info)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Register as delegate for debugger engine
        debuggerEngine.delegate = self
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Unregister as delegate
        if debuggerEngine.delegate === self {
            debuggerEngine.delegate = nil
        }
    }

    // MARK: - Setup

    private func setupNavigationBar() {
        // Set title
        title = "Runtime Debugger"

        // Add close button
        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
        navigationItem.rightBarButtonItem = closeButton

        // Add execution control buttons
        let pauseButton = UIBarButtonItem(
            image: UIImage(systemName: "pause.fill"),
            style: .plain,
            target: self,
            action: #selector(pauseButtonTapped)
        )

        let resumeButton = UIBarButtonItem(
            image: UIImage(systemName: "play.fill"),
            style: .plain,
            target: self,
            action: #selector(resumeButtonTapped)
        )

        let stepOverButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.right"),
            style: .plain,
            target: self,
            action: #selector(stepOverButtonTapped)
        )

        let stepIntoButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.down"),
            style: .plain,
            target: self,
            action: #selector(stepIntoButtonTapped)
        )

        let stepOutButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.up"),
            style: .plain,
            target: self,
            action: #selector(stepOutButtonTapped)
        )

        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        // Add toolbar with execution controls
        navigationController?.isToolbarHidden = false
        toolbarItems = [
            pauseButton,
            flexibleSpace,
            resumeButton,
            flexibleSpace,
            stepOverButton,
            flexibleSpace,
            stepIntoButton,
            flexibleSpace,
            stepOutButton,
        ]
    }

    private func setupTabBarController() {
        // Add tab bar controller as child view controller
        addChild(tabBarController)
        view.addSubview(tabBarController.view)
        tabBarController.view.frame = view.bounds
        tabBarController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tabBarController.didMove(toParent: self)

        // Create view controllers for each tab
        let consoleVC = createConsoleViewController()
        let breakpointsVC = createBreakpointsViewController()
        let variablesVC = createVariablesViewController()
        let memoryVC = createMemoryViewController()
        let networkVC = createNetworkViewController()
        let performanceVC = createPerformanceViewController()

        // Set tab bar items
        consoleVC.tabBarItem = UITabBarItem(title: "Console", image: UIImage(systemName: "terminal"), tag: 0)
        breakpointsVC.tabBarItem = UITabBarItem(
            title: "Breakpoints",
            image: UIImage(systemName: "pause.circle"),
            tag: 1
        )
        variablesVC.tabBarItem = UITabBarItem(title: "Variables", image: UIImage(systemName: "list.bullet"), tag: 2)
        memoryVC.tabBarItem = UITabBarItem(title: "Memory", image: UIImage(systemName: "memorychip"), tag: 3)
        networkVC.tabBarItem = UITabBarItem(title: "Network", image: UIImage(systemName: "network"), tag: 4)
        performanceVC.tabBarItem = UITabBarItem(title: "Performance", image: UIImage(systemName: "gauge"), tag: 5)

        // Set view controllers
        viewControllers = [
            UINavigationController(rootViewController: consoleVC),
            UINavigationController(rootViewController: breakpointsVC),
            UINavigationController(rootViewController: variablesVC),
            UINavigationController(rootViewController: memoryVC),
            UINavigationController(rootViewController: networkVC),
            UINavigationController(rootViewController: performanceVC),
        ]

        tabBarController.viewControllers = viewControllers
        tabBarController.selectedIndex = 0
    }

    // MARK: - Tab View Controllers

    private func createConsoleViewController() -> UIViewController {
        return ConsoleViewController()
    }

    private func createBreakpointsViewController() -> UIViewController {
        return BreakpointsViewController()
    }

    private func createVariablesViewController() -> UIViewController {
        return VariablesViewController()
    }

    private func createMemoryViewController() -> UIViewController {
        return MemoryViewController()
    }

    private func createNetworkViewController() -> UIViewController {
        return NetworkMonitorViewController()
    }

    private func createPerformanceViewController() -> UIViewController {
        return PerformanceViewController()
    }

    // MARK: - Actions

    @objc private func closeButtonTapped() {
        delegate?.debuggerViewControllerDidRequestDismissal(self)
    }

    @objc private func pauseButtonTapped() {
        debuggerEngine.pause()
    }

    @objc private func resumeButtonTapped() {
        debuggerEngine.resume()
    }

    @objc private func stepOverButtonTapped() {
        debuggerEngine.stepOver()
    }

    @objc private func stepIntoButtonTapped() {
        debuggerEngine.stepInto()
    }

    @objc private func stepOutButtonTapped() {
        debuggerEngine.stepOut()
    }
}

// MARK: - DebuggerEngineDelegate

extension DebuggerViewController: DebuggerEngineDelegate {
    func debuggerEngine(_: DebuggerEngine, didHitBreakpoint breakpoint: Breakpoint) {
        logger.log(message: "Hit breakpoint at \(breakpoint.file):\(breakpoint.line)", type: .info)

        // Switch to breakpoints tab
        DispatchQueue.main.async {
            self.tabBarController.selectedIndex = 1
        }
    }

    func debuggerEngine(
        _: DebuggerEngine,
        didTriggerWatchpoint watchpoint: Watchpoint,
        oldValue _: Any?,
        newValue _: Any?
    ) {
        logger.log(message: "Watchpoint triggered at address \(watchpoint.address)", type: .info)
    }

    func debuggerEngine(_: DebuggerEngine, didCatchException exception: ExceptionInfo) {
        logger.log(message: "Caught exception: \(exception.name) - \(exception.reason)", type: .error)

        // Switch to console tab
        DispatchQueue.main.async {
            self.tabBarController.selectedIndex = 0
        }
    }

    func debuggerEngine(_: DebuggerEngine, didChangeExecutionState state: ExecutionState) {
        logger.log(message: "Execution state changed to \(state)", type: .info)

        // Update UI based on execution state
        DispatchQueue.main.async {
            self.updateUIForExecutionState(state)
        }
    }

    private func updateUIForExecutionState(_ state: ExecutionState) {
        // Update toolbar buttons based on execution state
        guard let toolbarItems = toolbarItems else { return }

        let pauseButton = toolbarItems[0]
        let resumeButton = toolbarItems[2]
        let stepOverButton = toolbarItems[4]
        let stepIntoButton = toolbarItems[6]
        let stepOutButton = toolbarItems[8]

        switch state {
        case .running:
            pauseButton.isEnabled = true
            resumeButton.isEnabled = false
            stepOverButton.isEnabled = false
            stepIntoButton.isEnabled = false
            stepOutButton.isEnabled = false
        case .paused:
            pauseButton.isEnabled = false
            resumeButton.isEnabled = true
            stepOverButton.isEnabled = true
            stepIntoButton.isEnabled = true
            stepOutButton.isEnabled = true
        case .stepping:
            pauseButton.isEnabled = false
            resumeButton.isEnabled = false
            stepOverButton.isEnabled = false
            stepIntoButton.isEnabled = false
            stepOutButton.isEnabled = false
        }
    }
}
