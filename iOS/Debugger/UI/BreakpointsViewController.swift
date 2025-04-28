import UIKit


    /// View controller for the breakpoints tab in the debugger
    class BreakpointsViewController: UIViewController {
        // MARK: - Properties

        /// The debugger engine
        private let debuggerEngine = DebuggerEngine.shared

        /// Logger instance
        private let logger = Debug.shared

        /// Table view for displaying breakpoints
        private let tableView: UITableView = {
            let tableView = UITableView(frame: .zero, style: .plain)
            tableView.translatesAutoresizingMaskIntoConstraints = false
            tableView.register(
                BreakpointTableViewCell.self,
                forCellReuseIdentifier: BreakpointTableViewCell.reuseIdentifier
            )
            return tableView
        }()

        /// Add breakpoint button
        private let addButton: UIButton = {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setTitle("Add Breakpoint", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            return button
        }()

        /// Current breakpoints
        private var breakpoints: [Breakpoint] = []

        // MARK: - Lifecycle

        override func viewDidLoad() {
            super.viewDidLoad()

            setupUI()
            setupActions()
            setupNotifications()

            // Set title
            title = "Breakpoints"

            // Load breakpoints
            reloadBreakpoints()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)

            // Reload breakpoints when view appears
            reloadBreakpoints()
        }

        // MARK: - Setup

        private func setupUI() {
            // Set background color
            view.backgroundColor = UIColor.systemBackground

            // Add table view
            view.addSubview(tableView)

            // Add add button
            view.addSubview(addButton)

            // Set up constraints
            NSLayoutConstraint.activate([
                // Table view
                tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                tableView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -8),

                // Add button
                addButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
                addButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
                addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
                addButton.heightAnchor.constraint(equalToConstant: 44),
            ])

            // Set up table view
            tableView.delegate = self
            tableView.dataSource = self
        }

        private func setupActions() {
            // Add target for add button
            addButton.addTarget(self, action: #selector(addBreakpointTapped), for: .touchUpInside)
        }

        private func setupNotifications() {
            // Listen for breakpoint added notifications
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleBreakpointAdded),
                name: .debuggerBreakpointAdded,
                object: nil
            )

            // Listen for breakpoint removed notifications
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleBreakpointRemoved),
                name: .debuggerBreakpointRemoved,
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

        @objc private func addBreakpointTapped() {
            // Show add breakpoint alert
            let alertController = UIAlertController(
                title: "Add Breakpoint",
                message: "Enter file path and line number",
                preferredStyle: .alert
            )

            // Add file text field
            alertController.addTextField { textField in
                textField.placeholder = "File path"
                textField.autocorrectionType = .no
                textField.autocapitalizationType = .none
            }

            // Add line text field
            alertController.addTextField { textField in
                textField.placeholder = "Line number"
                textField.keyboardType = .numberPad
            }

            // Add condition text field
            alertController.addTextField { textField in
                textField.placeholder = "Condition (optional)"
                textField.autocorrectionType = .no
                textField.autocapitalizationType = .none
            }

            // Add cancel action
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

            // Add add action
            let addAction = UIAlertAction(title: "Add", style: .default) { [weak self, weak alertController] _ in
                guard let self = self,
                      let alertController = alertController,
                      let fileTextField = alertController.textFields?[0],
                      let lineTextField = alertController.textFields?[1],
                      let conditionTextField = alertController.textFields?[2],
                      let file = fileTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                      let lineString = lineTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                      let line = Int(lineString),
                      !file.isEmpty
                else {
                    return
                }

                // Get condition
                let condition = conditionTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalCondition = condition?.isEmpty == false ? condition : nil

                // Add breakpoint
                self.debuggerEngine.addBreakpoint(file: file, line: line, condition: finalCondition)

                // Reload breakpoints
                self.reloadBreakpoints()
            }

            // Add actions
            alertController.addAction(cancelAction)
            alertController.addAction(addAction)

            // Present alert
            present(alertController, animated: true)
        }

        @objc private func handleBreakpointAdded(_: Notification) {
            // Reload breakpoints
            reloadBreakpoints()
        }

        @objc private func handleBreakpointRemoved(_: Notification) {
            // Reload breakpoints
            reloadBreakpoints()
        }

        @objc private func handleBreakpointHit(_: Notification) {
            // Reload breakpoints to update hit counts
            reloadBreakpoints()
        }

        // MARK: - Helper Methods

        private func reloadBreakpoints() {
            // Get breakpoints from debugger engine
            breakpoints = debuggerEngine.getBreakpoints()

            // Reload table view
            tableView.reloadData()
        }
    }

    // MARK: - UITableViewDelegate

    extension BreakpointsViewController: UITableViewDelegate {
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: true)

            // Get breakpoint
            let breakpoint = breakpoints[indexPath.row]

            // Show breakpoint details alert
            let alertController = UIAlertController(
                title: "Breakpoint Details",
                message: "File: \(breakpoint.file)\nLine: \(breakpoint.line)\nCondition: \(breakpoint.condition ?? "None")\nHit Count: \(breakpoint.hitCount)",
                preferredStyle: .actionSheet
            )

            // Add toggle action
            let toggleTitle = breakpoint.isEnabled ? "Disable" : "Enable"
            let toggleAction = UIAlertAction(title: toggleTitle, style: .default) { [weak self] _ in
                guard let self = self else { return }

                // Toggle breakpoint
                if let index = self.breakpoints.firstIndex(where: { $0.id == breakpoint.id }) {
                    self.breakpoints[index].isEnabled.toggle()

                    // Reload table view
                    self.tableView.reloadRows(at: [indexPath], with: .automatic)
                }
            }

            // Add delete action
            let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
                guard let self = self else { return }

                // Remove breakpoint
                self.debuggerEngine.removeBreakpoint(id: breakpoint.id)

                // Reload breakpoints
                self.reloadBreakpoints()
            }

            // Add cancel action
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

            // Add actions
            alertController.addAction(toggleAction)
            alertController.addAction(deleteAction)
            alertController.addAction(cancelAction)

            // Present alert
            present(alertController, animated: true)
        }

        func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
            return 60
        }
    }

    // MARK: - UITableViewDataSource

    extension BreakpointsViewController: UITableViewDataSource {
        func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
            return breakpoints.count
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: BreakpointTableViewCell.reuseIdentifier,
                for: indexPath
            ) as? BreakpointTableViewCell else {
                return UITableViewCell()
            }

            // Configure cell
            let breakpoint = breakpoints[indexPath.row]
            cell.configure(with: breakpoint)

            return cell
        }

        func tableView(
            _: UITableView,
            commit editingStyle: UITableViewCell.EditingStyle,
            forRowAt indexPath: IndexPath
        ) {
            if editingStyle == .delete {
                // Get breakpoint
                let breakpoint = breakpoints[indexPath.row]

                // Remove breakpoint
                debuggerEngine.removeBreakpoint(id: breakpoint.id)

                // Reload breakpoints
                reloadBreakpoints()
            }
        }
    }

    // MARK: - BreakpointTableViewCell

    class BreakpointTableViewCell: UITableViewCell {
        // MARK: - Properties

        static let reuseIdentifier = "BreakpointTableViewCell"

        /// File label
        private let fileLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            return label
        }()

        /// Line label
        private let lineLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = UIFont.systemFont(ofSize: 14)
            label.textColor = UIColor.secondaryLabel
            return label
        }()

        /// Condition label
        private let conditionLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = UIFont.systemFont(ofSize: 12)
            label.textColor = UIColor.secondaryLabel
            return label
        }()

        /// Hit count label
        private let hitCountLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            label.textAlignment = .right
            return label
        }()

        // MARK: - Initialization

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)

            setupUI()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)

            setupUI()
        }

        // MARK: - Setup

        private func setupUI() {
            // Add file label
            contentView.addSubview(fileLabel)

            // Add line label
            contentView.addSubview(lineLabel)

            // Add condition label
            contentView.addSubview(conditionLabel)

            // Add hit count label
            contentView.addSubview(hitCountLabel)

            // Set up constraints
            NSLayoutConstraint.activate([
                // File label
                fileLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
                fileLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                fileLabel.trailingAnchor.constraint(equalTo: hitCountLabel.leadingAnchor, constant: -8),

                // Line label
                lineLabel.topAnchor.constraint(equalTo: fileLabel.bottomAnchor, constant: 4),
                lineLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                lineLabel.trailingAnchor.constraint(equalTo: hitCountLabel.leadingAnchor, constant: -8),

                // Condition label
                conditionLabel.topAnchor.constraint(equalTo: lineLabel.bottomAnchor, constant: 2),
                conditionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                conditionLabel.trailingAnchor.constraint(equalTo: hitCountLabel.leadingAnchor, constant: -8),
                conditionLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8),

                // Hit count label
                hitCountLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                hitCountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                hitCountLabel.widthAnchor.constraint(equalToConstant: 60),
            ])
        }

        // MARK: - Configuration

        func configure(with breakpoint: Breakpoint) {
            // Set file label
            let fileName = (breakpoint.file as NSString).lastPathComponent
            fileLabel.text = fileName

            // Set line label
            lineLabel.text = "Line: \(breakpoint.line)"

            // Set condition label
            if let condition = breakpoint.condition {
                conditionLabel.text = "Condition: \(condition)"
                conditionLabel.isHidden = false
            } else {
                conditionLabel.isHidden = true
            }

            // Set hit count label
            hitCountLabel.text = "Hits: \(breakpoint.hitCount)"

            // Set enabled state
            if breakpoint.isEnabled {
                fileLabel.textColor = UIColor.label
                accessoryType = .none
            } else {
                fileLabel.textColor = UIColor.tertiaryLabel
                accessoryType = .detailButton
            }
        }
    }

#endif // DEBUG
