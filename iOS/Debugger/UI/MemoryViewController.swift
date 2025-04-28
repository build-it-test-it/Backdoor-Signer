import UIKit


    /// View controller for the memory tab in the debugger
    class MemoryViewController: UIViewController {
        // MARK: - Properties

        /// The debugger engine
        private let debuggerEngine = DebuggerEngine.shared

        /// Logger instance
        private let logger = Debug.shared

        /// Text view for displaying memory content
        private let memoryTextView: UITextView = {
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

        /// Address input field
        private let addressTextField: UITextField = {
            let textField = UITextField()
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.placeholder = "Memory address (e.g., 0x1000)"
            textField.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            textField.borderStyle = .roundedRect
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .none
            textField.keyboardType = .asciiCapable
            textField.returnKeyType = .done
            textField.clearButtonMode = .whileEditing
            return textField
        }()

        /// Size input field
        private let sizeTextField: UITextField = {
            let textField = UITextField()
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.placeholder = "Size (bytes)"
            textField.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            textField.borderStyle = .roundedRect
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .none
            textField.keyboardType = .numberPad
            textField.returnKeyType = .done
            textField.clearButtonMode = .whileEditing
            textField.text = "128"
            return textField
        }()

        /// Examine button
        private let examineButton: UIButton = {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setTitle("Examine", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            return button
        }()

        /// Format segmented control
        private let formatSegmentedControl: UISegmentedControl = {
            let items = ["Hex", "ASCII", "Decimal", "Binary"]
            let segmentedControl = UISegmentedControl(items: items)
            segmentedControl.translatesAutoresizingMaskIntoConstraints = false
            segmentedControl.selectedSegmentIndex = 0
            return segmentedControl
        }()

        // MARK: - Lifecycle

        override func viewDidLoad() {
            super.viewDidLoad()

            setupUI()
            setupActions()

            // Set title
            title = "Memory"
        }

        // MARK: - Setup

        private func setupUI() {
            // Set background color
            view.backgroundColor = UIColor.systemBackground

            // Add address text field
            view.addSubview(addressTextField)

            // Add size text field
            view.addSubview(sizeTextField)

            // Add examine button
            view.addSubview(examineButton)

            // Add format segmented control
            view.addSubview(formatSegmentedControl)

            // Add memory text view
            view.addSubview(memoryTextView)

            // Set up constraints
            NSLayoutConstraint.activate([
                // Address text field
                addressTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
                addressTextField.leadingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                    constant: 16
                ),
                addressTextField.trailingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                    constant: -16
                ),

                // Size text field
                sizeTextField.topAnchor.constraint(equalTo: addressTextField.bottomAnchor, constant: 8),
                sizeTextField.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
                sizeTextField.widthAnchor.constraint(equalToConstant: 120),

                // Examine button
                examineButton.topAnchor.constraint(equalTo: addressTextField.bottomAnchor, constant: 8),
                examineButton.leadingAnchor.constraint(equalTo: sizeTextField.trailingAnchor, constant: 16),
                examineButton.trailingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                    constant: -16
                ),
                examineButton.heightAnchor.constraint(equalTo: sizeTextField.heightAnchor),

                // Format segmented control
                formatSegmentedControl.topAnchor.constraint(equalTo: sizeTextField.bottomAnchor, constant: 16),
                formatSegmentedControl.leadingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                    constant: 16
                ),
                formatSegmentedControl.trailingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                    constant: -16
                ),

                // Memory text view
                memoryTextView.topAnchor.constraint(equalTo: formatSegmentedControl.bottomAnchor, constant: 16),
                memoryTextView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
                memoryTextView.trailingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                    constant: -16
                ),
                memoryTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            ])

            // Set delegates
            addressTextField.delegate = self
            sizeTextField.delegate = self
        }

        private func setupActions() {
            // Add target for examine button
            examineButton.addTarget(self, action: #selector(examineButtonTapped), for: .touchUpInside)

            // Add target for format segmented control
            formatSegmentedControl.addTarget(self, action: #selector(formatChanged), for: .valueChanged)
        }

        // MARK: - Actions

        @objc private func examineButtonTapped() {
            // Dismiss keyboard
            view.endEditing(true)

            // Get address and size
            guard let addressText = addressTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let sizeText = sizeTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !addressText.isEmpty,
                  !sizeText.isEmpty,
                  let size = Int(sizeText)
            else {
                showError("Please enter a valid address and size")
                return
            }

            // Execute memory command
            let result = debuggerEngine.executeCommand("memory \(addressText) \(size)")

            if result.success {
                // Format the result based on selected format
                let formattedResult = formatMemoryOutput(result.output)

                // Display result
                memoryTextView.text = formattedResult
            } else {
                // Show error
                memoryTextView.text = "Error: \(result.output)"
            }
        }

        @objc private func formatChanged(_: UISegmentedControl) {
            // Re-format the current memory output
            if !memoryTextView.text.isEmpty {
                let formattedResult = formatMemoryOutput(memoryTextView.text)
                memoryTextView.text = formattedResult
            }
        }

        // MARK: - Helper Methods

        private func showError(_ message: String) {
            let alertController = UIAlertController(
                title: "Error",
                message: message,
                preferredStyle: .alert
            )

            let okAction = UIAlertAction(title: "OK", style: .default)
            alertController.addAction(okAction)

            present(alertController, animated: true)
        }

        private func formatMemoryOutput(_ output: String) -> String {
            // In a real implementation, this would parse and format the memory output
            // based on the selected format (hex, ASCII, decimal, binary)

            // For now, just return the original output
            return output
        }
    }

    // MARK: - UITextFieldDelegate

    extension MemoryViewController: UITextFieldDelegate {
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if textField == addressTextField {
                sizeTextField.becomeFirstResponder()
            } else {
                textField.resignFirstResponder()
                examineButtonTapped()
            }

            return true
        }
    }
