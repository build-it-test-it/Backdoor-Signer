import UIKit
import ZIPFoundation

class DirectoryViewController: HomeViewController {
    // MARK: - Properties

    /// The directory URL this controller is showing
    private var directoryURL: URL

    /// Callback to notify parent when changes occur
    var onContentChanged: (() -> Void)?

    // MARK: - Initialization

    /// Initialize with a directory URL
    /// - Parameter directory: The URL of the directory to display
    init(directory: URL) {
        directoryURL = directory
        super.init(nibName: nil, bundle: nil)
        title = directory.lastPathComponent
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupFileManagementUI() // Call the setup method from the extension
    }

    // MARK: - Overrides

    /// Override documentsDirectory to use the specified directory URL
    override var documentsDirectory: URL {
        return directoryURL
    }

    /// Reload content when returning to view
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadFiles()
    }
}
