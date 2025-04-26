import UIKit

#if DEBUG

/// Extension to AppDelegate for initializing the debugger
extension AppDelegate {
    /// Initialize the debugger
    func initializeDebugger() {
        // Initialize the debugger manager
        DebuggerManager.shared.initialize()
        
        // Log initialization
        Debug.shared.log(message: "Debugger initialized", type: .info)
    }
}

#endif // DEBUG
