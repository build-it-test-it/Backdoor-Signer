import UIKit

#if DEBUG

    /// View controller for the console tab in the debugger
    class ConsoleViewController: UIViewController {
        // MARK: - Properties

        /// The debugger engine
        private let debuggerEngine = DebuggerEngine.shared

        /// Logger instance
        private let logger = Debug.shared

        /// Text view for displaying console output
        private let consoleTextView: UITextView = {
            let textView = UITextView()
            textView.translatesAutoresizingMaskIntoConstraints = false
            textView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            textView.isEditable = false
            textView.autocorrectionType = .no
            textView.autocapitalizationType = .none
            textView.backgroundColor = UIColor.systemBackground
            textView.textColor = UIColor.label
            return textView
        }()

        /// Command input field
        private let commandTextField: UITextField = {
            let textField = UITextField()
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.placeholder = "Enter LLDB command..."
            textField.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            textField.borderStyle = .roundedRect
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .none
            textField.returnKeyType = .send
            textField.clearButtonMode = .whileEditing
            return textField
        }()

        /// Execute button
        private let executeButton: UIButton = {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setTitle("Execute", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            return button
        }()

        /// Clear button
        private let clearButton: UIButton = {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setTitle("Clear", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            button.tintColor = UIColor.systemRed
            return button
        }()

        /// Command history
        private var commandHistory: [String] = []

        /// Current position in command history
        private var historyPosition = -1

        // MARK: - Lifecycle

        override func viewDidLoad() {
            super.viewDidLoad()

            setupUI()
            setupActions()
            setupNotifications()

            // Set title
            title = "Console"

            // Load command history
            commandHistory = debuggerEngine.getCommandHistory()

            // Add welcome message
            appendToConsole("iOS Runtime Debugger Console\n")
            appendToConsole("Type 'help' for available commands\n")
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)

            // Register for keyboard notifications
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillShow),
                name: UIResponder.keyboardWillShowNotification,
                object: nil
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillHide),
                name: UIResponder.keyboardWillHideNotification,
                object: nil
            )
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)

            // Unregister for keyboard notifications
            NotificationCenter.default.removeObserver(
                self,
                name: UIResponder.keyboardWillShowNotification,
                object: nil
            )

            NotificationCenter.default.removeObserver(
                self,
                name: UIResponder.keyboardWillHideNotification,
                object: nil
            )
        }

        // MARK: - Setup

        private func setupUI() {
            // Set background color
            view.backgroundColor = UIColor.systemBackground

            // Add console text view
            view.addSubview(consoleTextView)

            // Add command input field
            view.addSubview(commandTextField)

            // Add execute button
            view.addSubview(executeButton)

            // Add clear button
            view.addSubview(clearButton)

            // Set up constraints
            NSLayoutConstraint.activate([
                // Console text view
                consoleTextView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                consoleTextView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                consoleTextView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),

                // Command input field
                commandTextField.topAnchor.constraint(equalTo: consoleTextView.bottomAnchor, constant: 8),
                commandTextField.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
                commandTextField.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),

                // Execute button
                executeButton.topAnchor.constraint(equalTo: commandTextField.topAnchor),
                executeButton.leadingAnchor.constraint(equalTo: commandTextField.trailingAnchor, constant: 8),
                executeButton.bottomAnchor.constraint(equalTo: commandTextField.bottomAnchor),
                executeButton.widthAnchor.constraint(equalToConstant: 70),

                // Clear button
                clearButton.topAnchor.constraint(equalTo: commandTextField.topAnchor),
                clearButton.leadingAnchor.constraint(equalTo: executeButton.trailingAnchor, constant: 8),
                clearButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
                clearButton.bottomAnchor.constraint(equalTo: commandTextField.bottomAnchor),
                clearButton.widthAnchor.constraint(equalToConstant: 50),
            ])
        }

        private func setupActions() {
            // Add target for execute button
            executeButton.addTarget(self, action: #selector(executeCommand), for: .touchUpInside)

            // Add target for clear button
            clearButton.addTarget(self, action: #selector(clearConsole), for: .touchUpInside)

            // Set text field delegate
            commandTextField.delegate = self
        }

        private func setupNotifications() {
            // Listen for exception notifications
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleExceptionCaught),
                name: .debuggerExceptionCaught,
                object: nil
            )

            // Listen for breakpoint hit notifications
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleBreakpointHit),
                name: .debuggerBreakpointHit,
                object: nil
            )
        }

        // MARK: - Actions

        @objc private func executeCommand() {
            guard let command = commandTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !command.isEmpty
            else {
                return
            }

            // Add command to console with prompt
            appendToConsole("(lldb) \(command)\n")

            // Execute command
            let result = debuggerEngine.executeCommand(command)

            // Display result
            if !result.output.isEmpty {
                appendToConsole("\(result.output)\n")
            }

            // Clear text field
            commandTextField.text = ""

            // Reset history position
            historyPosition = -1
        }

        @objc private func clearConsole() {
            consoleTextView.text = ""

            // Add welcome message
            appendToConsole("iOS Runtime Debugger Console\n")
            appendToConsole("Type 'help' for available commands\n")
        }

        @objc private func handleExceptionCaught(_ notification: Notification) {
            guard let exceptionInfo = notification.object as? ExceptionInfo else { return }

            // Display exception information
            appendToConsole("\n*** Exception caught: \(exceptionInfo.name) ***\n")
            appendToConsole("Reason: \(exceptionInfo.reason)\n")

            // Display call stack
            appendToConsole("\nCall Stack:\n")
            for (index, symbol) in exceptionInfo.callStack.enumerated() {
                appendToConsole("\(index): \(symbol)\n")
            }

            appendToConsole("\n")
        }

        @objc private func handleBreakpointHit(_ notification: Notification) {
            guard let breakpoint = notification.object as? Breakpoint else { return }

            // Display breakpoint information
            appendToConsole("\n*** Breakpoint hit: \(breakpoint.file):\(breakpoint.line) ***\n")

            // Display backtrace
            let frames = debuggerEngine.getBacktrace()
            appendToConsole("\nBacktrace:\n")
            for frame in frames {
                appendToConsole("\(frame.index): \(frame.symbol)\n")
            }

            appendToConsole("\n")
        }

        @objc private func keyboardWillShow(_ notification: Notification) {
            guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                return
            }

            let keyboardHeight = keyboardFrame.height

            // Adjust console text view bottom constraint
            let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight, right: 0)
            consoleTextView.contentInset = contentInsets
            consoleTextView.scrollIndicatorInsets = contentInsets
        }

        @objc private func keyboardWillHide(_: Notification) {
            // Reset console text view bottom constraint
            let contentInsets = UIEdgeInsets.zero
            consoleTextView.contentInset = contentInsets
            consoleTextView.scrollIndicatorInsets = contentInsets
        }

        // MARK: - Helper Methods

        private func appendToConsole(_ text: String) {
            // Add text to console
            consoleTextView.text.append(text)

            // Scroll to bottom
            let range = NSRange(location: consoleTextView.text.count, length: 0)
            consoleTextView.scrollRangeToVisible(range)
        }

        private func showPreviousCommand() {
            // Update history position
            if historyPosition < commandHistory.count - 1 {
                historyPosition += 1
                commandTextField.text = commandHistory[historyPosition]
            }
        }

        private func showNextCommand() {
            // Update history position
            if historyPosition > 0 {
                historyPosition -= 1
                commandTextField.text = commandHistory[historyPosition]
            } else if historyPosition == 0 {
                historyPosition = -1
                commandTextField.text = ""
            }
        }
    }

    // MARK: - UITextFieldDelegate

    extension ConsoleViewController: UITextFieldDelegate {
        func textFieldShouldReturn(_: UITextField) -> Bool {
            executeCommand()
            return true
        }

        func textField(_: UITextField, shouldChangeCharactersIn _: NSRange, replacementString _: String) -> Bool {
            // Reset history position when user types
            historyPosition = -1
            return true
        }
    }

#endif // DEBUG
