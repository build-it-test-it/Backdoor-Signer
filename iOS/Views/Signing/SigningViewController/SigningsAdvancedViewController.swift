import Foundation
import SwiftUI // For ObservableObject support
import UIKit

class SigningsAdvancedViewController: FRSITableViewController {
    private var toggleOptions: [TogglesOption]

    override init(signingDataWrapper: SigningDataWrapper, mainOptions: SigningMainDataWrapper) {
        toggleOptions = backdoor.toggleOptions(signingDataWrapper: signingDataWrapper)
        super.init(signingDataWrapper: signingDataWrapper, mainOptions: mainOptions)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableData = [
            [String.localized("APP_SIGNING_INPUT_VIEW_CONTROLLER_SECTION_TITLE_APPEARENCE")],
            [String.localized("APP_SIGNING_INPUT_VIEW_CONTROLLER_SECTION_TITLE_MINIMUM_APP_VERSION")],
            ["Custom Entitlements"],
            [],
        ]

        sectionTitles = [
            String.localized("APP_SIGNING_INPUT_VIEW_CONTROLLER_SECTION_TITLE_APPEARENCE"),
            String.localized("APP_SIGNING_INPUT_VIEW_CONTROLLER_SECTION_TITLE_MINIMUM_APP_VERSION"),
            "Entitlements",
            String.localized("APP_SIGNING_INPUT_VIEW_CONTROLLER_SECTION_TITLE_PROPERTIES"),
        ]

        title = String.localized("APP_SIGNING_INPUT_VIEW_CONTROLLER_SECTION_TITLE_PROPERTIES")
        tableData[3] = toggleOptions.map { $0.title }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Add LED effects to important cells
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.addLEDEffectsToImportantCells()
        }
    }

    /// Add LED effects to highlight important settings cells
    private func addLEDEffectsToImportantCells() {
        // Get visible cells to apply effects only to what the user can see
        let visibleCells = tableView.visibleCells

        for cell in visibleCells {
            // Apply LED effects based on cell content
            if let textLabel = cell.textLabel, let text = textLabel.text {
                if text == "Custom Entitlements" {
                    // Custom entitlements gets a bright blue glow to attract attention
                    cell.contentView.addLEDEffect(
                        color: UIColor.systemBlue,
                        intensity: 0.4,
                        spread: 10,
                        animated: true,
                        animationDuration: 2.5
                    )
                }
            }
        }
    }
}

extension SigningsAdvancedViewController {
    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "Cell"
        let cell = UITableViewCell(style: .value1, reuseIdentifier: reuseIdentifier)
        cell.accessoryType = .none
        cell.selectionStyle = .gray

        let cellText = tableData[indexPath.section][indexPath.row]
        cell.textLabel?.text = cellText

        switch cellText {
        case String.localized("APP_SIGNING_INPUT_VIEW_CONTROLLER_SECTION_TITLE_APPEARENCE"):
            let forceLightDarkAppearence = TweakLibraryViewCell()
            forceLightDarkAppearence.selectionStyle = .none
            forceLightDarkAppearence.configureSegmentedControl(
                with: mainOptions.mainOptions.forceLightDarkAppearenceString,
                selectedIndex: 0
            )
            forceLightDarkAppearence.segmentedControl.addTarget(
                self,
                action: #selector(forceLightDarkAppearenceDidChange(_:)),
                for: .valueChanged
            )

            return forceLightDarkAppearence

        case String.localized("APP_SIGNING_INPUT_VIEW_CONTROLLER_SECTION_TITLE_MINIMUM_APP_VERSION"):
            let forceMinimumVersion = TweakLibraryViewCell()
            forceMinimumVersion.selectionStyle = .none
            forceMinimumVersion.configureSegmentedControl(
                with: mainOptions.mainOptions.forceMinimumVersionString,
                selectedIndex: 0
            )
            forceMinimumVersion.segmentedControl.addTarget(
                self,
                action: #selector(forceMinimumVersionDidChange(_:)),
                for: .valueChanged
            )

            return forceMinimumVersion

        case "Custom Entitlements":
            // Create cell for custom entitlements with disclosure indicator
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default

            // Add count of current entitlements as detail text if any exist
            if let entitlements = signingDataWrapper.signingOptions.customEntitlements, !entitlements.isEmpty {
                cell.detailTextLabel?.text = "\(entitlements.count) entitlement(s)"
                cell.detailTextLabel?.textColor = .systemGreen
            } else {
                cell.detailTextLabel?.text = "Not configured"
                cell.detailTextLabel?.textColor = .secondaryLabel
            }

            return cell

        default:
            break
        }

        if indexPath.section == 3 {
            let toggleOption = toggleOptions[indexPath.row]
            cell.textLabel?.text = toggleOption.title
            let toggleSwitch = UISwitch()
            toggleSwitch.isOn = toggleOption.binding
            toggleSwitch.tag = indexPath.row
            toggleSwitch.addTarget(self, action: #selector(toggleOptionsSwitches(_:)), for: .valueChanged)
            cell.accessoryView = toggleSwitch
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellText = tableData[indexPath.section][indexPath.row]

        if cellText == "Custom Entitlements" {
            // Navigate to entitlements editor
            let entitlementsVC = EntitlementsEditorViewController(
                signingDataWrapper: signingDataWrapper,
                mainOptions: mainOptions
            )
            navigationController?.pushViewController(entitlementsVC, animated: true)
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension SigningsAdvancedViewController {
    @objc private func forceLightDarkAppearenceDidChange(_ sender: UISegmentedControl) {
        signingDataWrapper.signingOptions.forceLightDarkAppearence =
            mainOptions.mainOptions.forceLightDarkAppearenceString[sender.selectedSegmentIndex]
    }

    @objc private func forceMinimumVersionDidChange(_ sender: UISegmentedControl) {
        signingDataWrapper.signingOptions.forceMinimumVersion =
            mainOptions.mainOptions.forceMinimumVersionString[sender.selectedSegmentIndex]
    }

    @objc func toggleOptionsSwitches(_ sender: UISwitch) {
        switch sender.tag {
        case 0:
            signingDataWrapper.signingOptions.removePlugins = sender.isOn
        case 1:
            signingDataWrapper.signingOptions.forceFileSharing = sender.isOn
        case 2:
            signingDataWrapper.signingOptions.removeSupportedDevices = sender.isOn
        case 3:
            signingDataWrapper.signingOptions.removeURLScheme = sender.isOn
        case 4:
            signingDataWrapper.signingOptions.forceProMotion = sender.isOn
        case 5:
            signingDataWrapper.signingOptions.forceForceFullScreen = sender.isOn
        case 6:
            signingDataWrapper.signingOptions.forceiTunesFileSharing = sender.isOn
        case 7:
            signingDataWrapper.signingOptions.forceTryToLocalize = sender.isOn
        case 8:
            signingDataWrapper.signingOptions.removeProvisioningFile = sender.isOn
        case 9:
            signingDataWrapper.signingOptions.removeWatchPlaceHolder = sender.isOn
        default:
            break
        }
    }
}
