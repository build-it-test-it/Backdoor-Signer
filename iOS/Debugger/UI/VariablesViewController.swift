import UIKit

#if DEBUG

/// View controller for the variables tab in the debugger
class VariablesViewController: UIViewController {
    // MARK: - Properties
    
    /// The debugger engine
    private let debuggerEngine = DebuggerEngine.shared
    
    /// Logger instance
    private let logger = Debug.shared
    
    /// Table view for displaying variables
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(VariableTableViewCell.self, forCellReuseIdentifier: VariableTableViewCell.reuseIdentifier)
        return tableView
    }()
    
    /// Search bar for filtering variables
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = "Filter variables..."
        searchBar.searchBarStyle = .minimal
        return searchBar
    }()
    
    /// Refresh control for pulling to refresh
    private let refreshControl = UIRefreshControl()
    
    /// Current variables
    private var variables: [Variable] = []
    
    /// Filtered variables
    private var filteredVariables: [Variable] = []
    
    /// Current search text
    private var searchText: String = ""
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupActions()
        setupNotifications()
        
        // Set title
        title = "Variables"
        
        // Load variables
        reloadVariables()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Reload variables when view appears
        reloadVariables()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Set background color
        view.backgroundColor = UIColor.systemBackground
        
        // Add search bar
        view.addSubview(searchBar)
        
        // Add table view
        view.addSubview(tableView)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Search bar
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            
            // Table view
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        // Set up table view
        tableView.delegate = self
        tableView.dataSource = self
        
        // Add refresh control
        tableView.refreshControl = refreshControl
        
        // Set up search bar
        searchBar.delegate = self
    }
    
    private func setupActions() {
        // Add target for refresh control
        refreshControl.addTarget(self, action: #selector(refreshVariables), for: .valueChanged)
    }
    
    private func setupNotifications() {
        // Listen for execution state change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExecutionStateChanged),
            name: .debuggerExecutionPaused,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExecutionStateChanged),
            name: .debuggerExecutionResumed,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExecutionStateChanged),
            name: .debuggerStepCompleted,
            object: nil
        )
    }
    
    // MARK: - Actions
    
    @objc private func refreshVariables() {
        // Reload variables
        reloadVariables()
        
        // End refreshing
        refreshControl.endRefreshing()
    }
    
    @objc private func handleExecutionStateChanged(_ notification: Notification) {
        // Reload variables when execution state changes
        reloadVariables()
    }
    
    // MARK: - Helper Methods
    
    private func reloadVariables() {
        // Get variables from debugger engine
        variables = debuggerEngine.getVariables()
        
        // Apply filter
        filterVariables()
        
        // Reload table view
        tableView.reloadData()
    }
    
    private func filterVariables() {
        // Apply search filter
        if searchText.isEmpty {
            filteredVariables = variables
        } else {
            filteredVariables = variables.filter { variable in
                return variable.name.lowercased().contains(searchText.lowercased()) ||
                       variable.type.lowercased().contains(searchText.lowercased()) ||
                       variable.value.lowercased().contains(searchText.lowercased())
            }
        }
    }
}

// MARK: - UITableViewDelegate

extension VariablesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Get variable
        let variable = filteredVariables[indexPath.row]
        
        // Show variable details alert
        let alertController = UIAlertController(
            title: variable.name,
            message: "Type: \(variable.type)\nValue: \(variable.value)\nSummary: \(variable.summary)",
            preferredStyle: .alert
        )
        
        // Add print action
        let printAction = UIAlertAction(title: "Print Description", style: .default) { [weak self] _ in
            guard let self = self else { return }
            
            // Execute po command
            let result = self.debuggerEngine.executeCommand("po \(variable.name)")
            
            // Show result
            let resultAlert = UIAlertController(
                title: "Print Result",
                message: result.output,
                preferredStyle: .alert
            )
            
            // Add OK action
            let okAction = UIAlertAction(title: "OK", style: .default)
            
            // Add actions
            resultAlert.addAction(okAction)
            
            // Present alert
            self.present(resultAlert, animated: true)
        }
        
        // Add OK action
        let okAction = UIAlertAction(title: "OK", style: .default)
        
        // Add actions
        alertController.addAction(printAction)
        alertController.addAction(okAction)
        
        // Present alert
        present(alertController, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

// MARK: - UITableViewDataSource

extension VariablesViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredVariables.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: VariableTableViewCell.reuseIdentifier, for: indexPath) as? VariableTableViewCell else {
            return UITableViewCell()
        }
        
        // Configure cell
        let variable = filteredVariables[indexPath.row]
        cell.configure(with: variable)
        
        return cell
    }
}

// MARK: - UISearchBarDelegate

extension VariablesViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Update search text
        self.searchText = searchText
        
        // Apply filter
        filterVariables()
        
        // Reload table view
        tableView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        // Dismiss keyboard
        searchBar.resignFirstResponder()
    }
}

// MARK: - VariableTableViewCell

class VariableTableViewCell: UITableViewCell {
    // MARK: - Properties
    
    static let reuseIdentifier = "VariableTableViewCell"
    
    /// Name label
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        return label
    }()
    
    /// Type label
    private let typeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.secondaryLabel
        return label
    }()
    
    /// Value label
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
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
        // Add name label
        contentView.addSubview(nameLabel)
        
        // Add type label
        contentView.addSubview(typeLabel)
        
        // Add value label
        contentView.addSubview(valueLabel)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Name label
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: valueLabel.leadingAnchor, constant: -8),
            
            // Type label
            typeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            typeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            typeLabel.trailingAnchor.constraint(equalTo: valueLabel.leadingAnchor, constant: -8),
            typeLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8),
            
            // Value label
            valueLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            valueLabel.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.5)
        ])
    }
    
    // MARK: - Configuration
    
    func configure(with variable: Variable) {
        // Set name label
        nameLabel.text = variable.name
        
        // Set type label
        typeLabel.text = variable.type
        
        // Set value label
        valueLabel.text = variable.value
        
        // Set accessory type
        accessoryType = variable.children != nil ? .disclosureIndicator : .none
    }
}

#endif // DEBUG
