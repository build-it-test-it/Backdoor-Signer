import Nuke
import SwiftUI
import UIKit

class SettingsViewController: FRSTableViewController {
    let aboutSection = [
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ABOUT", arguments: "Backdoor"),
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SUBMIT_FEEDBACK"),
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_GITHUB"),
    ]

    let displaySection = [
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_DISPLAY"),
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_APP_ICON"),
    ]

    let certificateSection = [
        "Current Certificate",
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ADD_CERTIFICATES"),
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SIGN_OPTIONS"),
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SERVER_OPTIONS"),
    ]

    let aiSection = [
        "AI Learning Settings",
        "AI Search Settings",
    ]

    let terminalSection = [
        "Terminal",
        "Terminal Settings",
        "Terminal Button",
    ]

    let logsSection = [
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_VIEW_LOGS"),
    ]

    let foldersSection = [
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_APPS_FOLDER"),
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_CERTS_FOLDER"),
    ]

    let resetSection = [
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET"),
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET_ALL"),
    ]

    // Flag to prevent double initialization
    private var isInitialized = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // Defensive programming - ensure we're on the main thread for UI setup
        if !Thread.isMainThread {
            backdoor.Debug.shared.log(
                message: "SettingsViewController.viewDidLoad called off main thread, dispatching to main",
                type: .error
            )
            DispatchQueue.main.async { [weak self] in
                self?.viewDidLoad()
            }
            return
        }

        // Set the title immediately for better user experience
        title = String.localized("TAB_SETTINGS")

        // Initialize with a try-catch inside a separate error-protected block
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Set up UI with proper error handling
                try self.safeInitialize()
                backdoor.Debug.shared.log(message: "SettingsViewController initialized successfully", type: .info)
            } catch {
                backdoor.Debug.shared.log(message: "SettingsViewController initialization failed: \(error)", type: .error)

                // Show an error dialog if initialization fails
                let alert = UIAlertController(
                    title: "Settings Error",
                    message: "There was a problem loading settings. Please try again.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true, completion: nil)
                
                // Still set the isInitialized flag to prevent further crashes
                // and populate with empty data as a fallback
                self.setupEmergencyBackupStructure()
            }
        }
    }
    
    /// Emergency backup structure to prevent crashes if normal initialization fails
    private func setupEmergencyBackupStructure() {
        // Create a minimal valid structure even in error state
        tableData = [["Settings"]];
        sectionTitles = [""];
        isInitialized = true;
        backdoor.Debug.shared.log(message: "Emergency backup structure initialized for Settings", type: .warning)
    }

    /// Add LED effects to highlight important settings cells
    private func addLEDEffectsToImportantCells() {
        // Only apply effects if the view is visible and initialized
        guard isViewLoaded && view.window != nil && isInitialized else { return }
        
        // Get visible cells to apply effects only to what the user can see
        let visibleCells = tableView.visibleCells
        
        for cell in visibleCells {
            // Apply LED effects based on cell content
            guard let textLabel = cell.textLabel, 
                  let text = textLabel.text,
                  !text.isEmpty else { 
                continue 
            }
            
            // Use a do-catch block to prevent any exceptions from LED effects crashing the app
            do {
                switch text {
                case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ABOUT", arguments: "Backdoor"):
                    // About section gets brand color glow
                    cell.contentView.addLEDEffect(
                        color: UIColor(hex: "#FF6482"),
                        intensity: 0.3,
                        spread: 10,
                        animated: true,
                        animationDuration: 3.0
                    )

                case "Current Certificate":
                    // Certificate section gets flowing LED to draw attention
                    // Guard against Core Data access errors
                    if let cert = getCertificateSafely() {
                        let isExpiring = isCertificateExpiringSoon(cert)
                        let color: UIColor = isExpiring ? .systemOrange : .systemGreen

                        cell.contentView.addFlowingLEDEffect(
                            color: color,
                            intensity: isExpiring ? 0.6 : 0.4,
                            width: 2,
                            speed: isExpiring ? 3.0 : 5.0
                        )
                    }

                case "Terminal":
                    // Terminal gets a tech-like glow
                    cell.contentView.addLEDEffect(
                        color: .systemGreen,
                        intensity: 0.4,
                        spread: 8,
                        animated: true,
                        animationDuration: 4.0
                    )

                case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET"),
                     String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET_ALL"):
                    // Reset buttons get subtle warning glow
                    cell.contentView.addLEDEffect(
                        color: .systemRed,
                        intensity: 0.3,
                        spread: 5,
                        animated: true,
                        animationDuration: 2.0
                    )

                default:
                    break
                }
            } catch {
                backdoor.Debug.shared.log(message: "Error applying LED effect: \(error)", type: .error)
                // Continue processing other cells even if one fails
            }
        }
    }
    
    /// Get certificate safely with error handling
    private func getCertificateSafely() -> Certificate? {
        do {
            return CoreDataManager.shared.getCurrentCertificate()
        } catch {
            backdoor.Debug.shared.log(message: "Error fetching certificate: \(error)", type: .error)
            return nil
        }
    }

    /// Check if certificate is expiring within 7 days
    private func isCertificateExpiringSoon(_ certificate: Certificate) -> Bool {
        guard let expirationDate = certificate.certData?.expirationDate else {
            return false
        }

        let currentDate = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: currentDate, to: expirationDate)
        let daysLeft = components.day ?? 0

        return daysLeft < 7 && daysLeft >= 0
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Only add LED effects if view is initialized
        if isInitialized {
            // Delay LED effects to ensure view is fully loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.addLEDEffectsToImportantCells()
            }
        }
    }

    override func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt _: IndexPath) {
        // Only apply LED effects if view is initialized
        guard isInitialized else { return }
        
        // Apply LED effects to newly visible cells
        if let text = cell.textLabel?.text {
            switch text {
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ABOUT", arguments: "Backdoor"):
                cell.contentView.addLEDEffect(
                    color: UIColor(hex: "#FF6482"),
                    intensity: 0.3,
                    spread: 10,
                    animated: true,
                    animationDuration: 3.0
                )

            case "Current Certificate":
                if let cert = CoreDataManager.shared.getCurrentCertificate() {
                    let isExpiring = isCertificateExpiringSoon(cert)
                    cell.contentView.addFlowingLEDEffect(
                        color: isExpiring ? .systemOrange : .systemGreen,
                        intensity: isExpiring ? 0.6 : 0.4,
                        width: 2,
                        speed: isExpiring ? 3.0 : 5.0
                    )
                }

            // Other cases as needed...

            default:
                break
            }
        }
    }

    private func safeInitialize() throws {
        // Initialize settings with error handling
        do {
            initializeTableData()
            setupNavigation()
            
            // Validate table structure
            ensureTableDataHasSections()
            
            // Mark as initialized only if everything succeeds
            isInitialized = true
            
            // Log successful initialization with stats
            backdoor.Debug.shared.log(message: "Settings initialized successfully with \(tableData.count) sections", type: .info)
        } catch {
            // Log the specific error and rethrow
            backdoor.Debug.shared.log(message: "Failed to initialize settings: \(error)", type: .error)
            throw error
        }
    }

    // Separate method for initialization to make error handling clearer
    private func initializeTableData() {
        // Use a defensive approach for section initialization
        var sections: [[String]] = []
        
        // Build each section carefully, with try-catch for any potential errors
        do {
            sections.append(aboutSection)
            sections.append(displaySection)
            sections.append(certificateSection)
            sections.append(aiSection)
            sections.append(terminalSection)
            sections.append(logsSection)
            sections.append(foldersSection)
            sections.append(resetSection)
        } catch {
            backdoor.Debug.shared.log(message: "Error building sections: \(error)", type: .error)
            // If there's an error, provide a minimal valid table structure
            sections = [["Settings"]]
        }
        
        tableData = sections
        
        // Create appropriate number of section titles
        sectionTitles = Array(repeating: "", count: tableData.count)
        
        // Double-check the table structure
        ensureTableDataHasSections()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Only reload if already initialized to prevent crashes
        if isInitialized {
            tableView.reloadData()
        } else {
            // If not initialized yet, trigger viewDidLoad again
            viewDidLoad()
        }
    }

    fileprivate func setupNavigation() {
        title = String.localized("TAB_SETTINGS")

        // Ensure the navigation bar is properly configured
        if let navController = navigationController {
            navController.navigationBar.prefersLargeTitles = true
            navController.navigationBar.tintColor = Preferences.appTintColor.uiColor
        }
    }

    // MARK: - ViewControllerRefreshable

    override func refreshContent() {
        // Only refresh if view is loaded and initialized
        if isViewLoaded && isInitialized {
            tableView.reloadData()
        }
    }

    // MARK: - UITableViewDataSource & UITableViewDelegate overrides

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Safety check to prevent crashes
        guard isInitialized, section < tableData.count else {
            backdoor.Debug.shared.log(message: "Invalid section in numberOfRowsInSection: \(section)", type: .error)
            return 0
        }
        
        // Defensive check to ensure tableData is valid
        let rowCount = tableData[section].count
        
        // Log if there's an empty section which could indicate a problem
        if rowCount == 0 {
            backdoor.Debug.shared.log(message: "Empty section in tableData: \(section)", type: .warning)
        }
        
        return rowCount
    }

    override func numberOfSections(in _: UITableView) -> Int {
        // Safety check to prevent crashes
        guard isInitialized else {
            backdoor.Debug.shared.log(message: "Table view accessed before initialization", type: .error)
            return 0
        }
        
        // Defensive check for empty tableData
        if tableData.isEmpty {
            backdoor.Debug.shared.log(message: "tableData is empty, returning minimum section count", type: .warning)
            return 1 // Return minimum section count to prevent crashes
        }
        
        return tableData.count
    }
    
    // MARK: - Safe table setup helpers
    
    /// Verify table structure is valid and fix it if not
    private func ensureTableDataHasSections() {
        // If tableData is somehow nil, initialize it
        if tableData == nil {
            tableData = [["Settings"]]
            backdoor.Debug.shared.log(message: "tableData was nil, initialized with default value", type: .error)
        }
        
        // If tableData is empty, add a default section
        if tableData.isEmpty {
            tableData = [["Settings"]]
            backdoor.Debug.shared.log(message: "tableData was empty, added default section", type: .warning)
        }
        
        // If sectionTitles is nil or wrong length, fix it
        if sectionTitles == nil || sectionTitles.count != tableData.count {
            sectionTitles = Array(repeating: "", count: tableData.count)
            backdoor.Debug.shared.log(message: "Fixed sectionTitles to match tableData count", type: .warning)
        }
    }

    // Note: tableView:cellForRowAt: implementation moved to the extension below
}

extension SettingsViewController {
    override func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
        if Preferences.beta, section == 0 {
            return String.localized("SETTINGS_VIEW_CONTROLLER_SECTION_FOOTER_ISSUES")
        } else if !Preferences.beta, section == 1 {
            return String.localized("SETTINGS_VIEW_CONTROLLER_SECTION_FOOTER_ISSUES")
        }

        switch section {
        case sectionTitles.count - 1:
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
            return "Backdoor \(appVersion) (\(buildNumber)) • iOS \(UIDevice.current.systemVersion)"
        default:
            return nil
        }
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "Cell"
        let cell = UITableViewCell(style: .value1, reuseIdentifier: reuseIdentifier)
        cell.accessoryType = .none
        cell.selectionStyle = .none

        // Safety check to prevent crashes
        guard isInitialized, 
              indexPath.section < tableData.count,
              indexPath.row < tableData[indexPath.section].count else {
            // Return a valid cell with some indication that something went wrong
            cell.textLabel?.text = "Settings"
            cell.textLabel?.textColor = .secondaryLabel
            backdoor.Debug.shared.log(message: "Invalid indexPath in cellForRowAt: \(indexPath)", type: .error)
            return cell
        }

        // Use defensive programming for cell text retrieval
        let cellText: String
        do {
            cellText = tableData[indexPath.section][indexPath.row]
        } catch {
            backdoor.Debug.shared.log(message: "Error retrieving cell text: \(error)", type: .error)
            cell.textLabel?.text = "Settings Item"
            return cell
        }
        
        // Set text safely
        cell.textLabel?.text = cellText

        // Use do-catch to gracefully handle any switch case errors
        do {
            switch cellText {
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ABOUT", arguments: "Backdoor"):
                cell.setAccessoryIcon(with: "info.circle")
                cell.selectionStyle = .default

            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SUBMIT_FEEDBACK"),
                 String.localized("SETTINGS_VIEW_CONTROLLER_CELL_GITHUB"):
                cell.textLabel?.textColor = .tintColor
                cell.setAccessoryIcon(with: "safari")
                cell.selectionStyle = .default

            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_DISPLAY"):
                cell.setAccessoryIcon(with: "paintbrush")
                cell.selectionStyle = .default

            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_APP_ICON"):
                cell.setAccessoryIcon(with: "app.dashed")
                cell.selectionStyle = .default

            case "Current Certificate":
                // Use safe certificate retrieval
                if let hasGotCert = getCertificateSafely() {
                    let certCell = CertificateViewTableViewCell()
                    
                    // Safely configure the cell
                    do {
                        certCell.configure(with: hasGotCert, isSelected: false)
                        certCell.selectionStyle = .none
                        return certCell
                    } catch {
                        backdoor.Debug.shared.log(message: "Error configuring certificate cell: \(error)", type: .error)
                        // Fall back to basic cell if custom configuration fails
                        cell.textLabel?.text = "Certificate Available"
                        cell.selectionStyle = .none
                    }
                } else {
                    cell.textLabel?.text = String.localized("SETTINGS_VIEW_CONTROLLER_CELL_CURRENT_CERTIFICATE_NOSELECTED")
                    cell.textLabel?.textColor = .secondaryLabel
                    cell.selectionStyle = .none
                }

            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ADD_CERTIFICATES"):
                cell.setAccessoryIcon(with: "plus")
                cell.selectionStyle = .default

            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SIGN_OPTIONS"):
                cell.setAccessoryIcon(with: "signature")
                cell.selectionStyle = .default

            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SERVER_OPTIONS"):
                cell.setAccessoryIcon(with: "server.rack")
                cell.selectionStyle = .default

            case "Terminal":
                cell.setAccessoryIcon(with: "terminal")
                cell.selectionStyle = .default

            case "Terminal Settings":
                cell.setAccessoryIcon(with: "gear")
                cell.selectionStyle = .default

            case "Terminal Button":
                // Create UI components safely
                let isEnabled = UserDefaults.standard.bool(forKey: "show_terminal_button")
                let toggleSwitch = UISwitch()
                toggleSwitch.isOn = isEnabled
                toggleSwitch.onTintColor = .tintColor
                toggleSwitch.addTarget(self, action: #selector(terminalButtonToggled(_:)), for: .valueChanged)
                cell.accessoryView = toggleSwitch
                cell.selectionStyle = .none

            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_VIEW_LOGS"):
                cell.setAccessoryIcon(with: "newspaper")
                cell.selectionStyle = .default

            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_APPS_FOLDER"),
                 String.localized("SETTINGS_VIEW_CONTROLLER_CELL_CERTS_FOLDER"):
                cell.accessoryType = .disclosureIndicator
                cell.textLabel?.textColor = .tintColor
                cell.selectionStyle = .default

            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET"),
                 String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET_ALL"):
                cell.textLabel?.textColor = .tintColor
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default

            default:
                // Default configuration for any unhandled cell type
                cell.selectionStyle = .default
            }
        } catch {
            backdoor.Debug.shared.log(message: "Error configuring cell: \(error)", type: .error)
            // Still return a valid cell even if configuration fails
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Safety check to prevent crashes
        guard isInitialized,
              indexPath.section < tableData.count,
              indexPath.row < tableData[indexPath.section].count else {
            tableView.deselectRow(at: indexPath, animated: true)
            backdoor.Debug.shared.log(message: "Invalid indexPath in didSelectRowAt: \(indexPath)", type: .error)
            return
        }
        
        // Get the tapped item safely
        let itemTapped: String
        do {
            itemTapped = tableData[indexPath.section][indexPath.row]
        } catch {
            backdoor.Debug.shared.log(message: "Error retrieving item text: \(error)", type: .error)
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        
        // Always deselect row - we'll do this early to prevent UI issues if navigation fails
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Handle the selection in a try-catch block to prevent crashes
        do {
            switch itemTapped {
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ABOUT", arguments: "Backdoor"):
                navigateSafely(to: AboutViewController())
                
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_GITHUB"):
                openURLSafely("https://github.com/khcrysalis/Backdoor")
                
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SUBMIT_FEEDBACK"):
                openURLSafely("https://github.com/khcrysalis/Backdoor/issues")
                
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_DISPLAY"):
                navigateSafely(to: DisplayViewController())
                
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_APP_ICON"):
                navigateSafely(to: IconsListViewController())
                
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ADD_CERTIFICATES"):
                navigateSafely(to: CertificatesViewController())
                
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SIGN_OPTIONS"):
                // Get signing options safely
                let signingOptions = UserDefaults.standard.signingOptions 
                let signingDataWrapper = SigningDataWrapper(signingOptions: signingOptions)
                navigateSafely(to: SigningsOptionViewController(signingDataWrapper: signingDataWrapper))
                
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SERVER_OPTIONS"):
                navigateSafely(to: ServerOptionsViewController())
                
            case "AI Learning Settings":
                navigateSafely(to: AILearningSettingsViewController(style: .grouped))
                
            case "AI Search Settings":
                navigateSafely(to: SearchSettingsViewController(style: .grouped))
                
            case "Terminal":
                presentTerminalSafely()
                
            case "Terminal Settings":
                navigateSafely(to: TerminalSettingsViewController(style: .grouped))
                
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_VIEW_LOGS"):
                navigateSafely(to: LogsViewController())
                
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_APPS_FOLDER"):
                openDirectorySafely(named: "Apps")
                
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_CERTS_FOLDER"):
                openDirectorySafely(named: "Certificates")
                
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET"):
                resetOptionsActionSafely()
                
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET_ALL"):
                resetAllActionSafely()
                
            default:
                backdoor.Debug.shared.log(message: "Unhandled settings item: \(itemTapped)", type: .debug)
            }
        } catch {
            backdoor.Debug.shared.log(message: "Error handling settings selection: \(error)", type: .error)
            
            // Show an error alert to provide feedback to the user
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Action Error",
                    message: "There was a problem performing this action. Please try again later.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }
    
    // MARK: - Safe Navigation Helpers
    
    /// Navigate to a view controller with error handling
    private func navigateSafely(to viewController: UIViewController) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let navigationController = self.navigationController else {
                backdoor.Debug.shared.log(message: "Cannot navigate: navigation controller is nil", type: .error)
                return
            }
            
            navigationController.pushViewController(viewController, animated: true)
        }
    }
    
    /// Present terminal view controller with error handling
    private func presentTerminalSafely() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let terminalVC = TerminalViewController()
            let navController = UINavigationController(rootViewController: terminalVC)
            self.present(navController, animated: true) { 
                backdoor.Debug.shared.log(message: "Terminal presented successfully", type: .info)
            }
        }
    }
    
    /// Open URL with error handling
    private func openURLSafely(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            backdoor.Debug.shared.log(message: "Invalid URL: \(urlString)", type: .error)
            return
        }
        
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    backdoor.Debug.shared.log(message: "Failed to open URL: \(urlString)", type: .error)
                }
            }
        }
    }
    
    /// Open directory with error handling
    private func openDirectorySafely(named directoryName: String) {
        do {
            openDirectory(named: directoryName)
        } catch {
            backdoor.Debug.shared.log(message: "Failed to open directory: \(directoryName), error: \(error)", type: .error)
        }
    }
    
    /// Reset options with error handling
    private func resetOptionsActionSafely() {
        do {
            resetOptionsAction()
        } catch {
            backdoor.Debug.shared.log(message: "Failed to reset options: \(error)", type: .error)
        }
    }
    
    /// Reset all with error handling
    private func resetAllActionSafely() {
        do {
            resetAllAction()
        } catch {
            backdoor.Debug.shared.log(message: "Failed to reset all: \(error)", type: .error)
        }
    }
}

extension UITableViewCell {
    func setAccessoryIcon(
        with symbolName: String,
        tintColor: UIColor = .tertiaryLabel,
        renderingMode: UIImage.RenderingMode = .alwaysOriginal
    ) {
        if let image = UIImage(systemName: symbolName)?.withTintColor(tintColor, renderingMode: renderingMode) {
            let imageView = UIImageView(image: image)
            accessoryView = imageView
        } else {
            accessoryView = nil
        }
    }
}

private extension SettingsViewController {
    func openDirectory(named directoryName: String) {
        let directoryURL = getDocumentsDirectory().appendingPathComponent(directoryName)
        let path = directoryURL.absoluteString.replacingOccurrences(of: "file://", with: "shareddocuments://")

        UIApplication.shared.open(URL(string: path)!, options: [:]) { success in
            if success {
                backdoor.Debug.shared.log(message: "File opened successfully.")
            } else {
                backdoor.Debug.shared.log(message: "Failed to open file.")
            }
        }
    }

    // Terminal button toggle handler moved to SettingsViewController+Terminal.swift
}
