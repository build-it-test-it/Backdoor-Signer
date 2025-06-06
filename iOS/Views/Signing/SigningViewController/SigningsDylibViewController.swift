import UIKit

class SigningsDylibViewController: UITableViewController {
    var applicationPath: URL
    var groupedDylibs: [String: [String]] = [:]
    var dylibSections: [String] = ["@rpath", "@executable_path", "/usr/lib", "/System/Library", "Other"]
    var dylibstoremove: [String] = [] {
        didSet {
            mainOptions.mainOptions.removeInjectPaths = dylibstoremove
        }
    }

    var mainOptions: SigningMainDataWrapper

    init(mainOptions: SigningMainDataWrapper, app: URL) {
        self.mainOptions = mainOptions
        applicationPath = app
        super.init(style: .insetGrouped)

        do {
            if let executablePath = try TweakHandler.findExecutable(at: applicationPath),
               let dylibs = listDylibs(filePath: executablePath.path) {
                groupDylibs(dylibs)
            }
        } catch {
            print(error)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupNavigation()
        dylibstoremove = mainOptions.mainOptions.removeInjectPaths
    }

    fileprivate func setupViews() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "dylibCell")

        let alertController = UIAlertController(
            title: "ADVANCED USERS ONLY",
            message: "This section can make installed applications UNUSABLE and potentially UNSTABLE. USE THIS SECTION WITH CAUTION, IF YOU HAVE NO IDEA WHAT YOU'RE DOING, PLEASE LEAVE.\n\nIF YOU MAKE AN ISSUE ON THIS, IT WILL IMMEDIATELY BE CLOSED AND IGNORED.",
            preferredStyle: .alert
        )

        let continueAction = UIAlertAction(title: "WHO CARES", style: .destructive, handler: nil)

        alertController.addAction(continueAction)

        present(alertController, animated: true, completion: nil)
    }

    fileprivate func setupNavigation() {
        title = "Remove Dylibs"
    }

    fileprivate func groupDylibs(_ dylibs: [String]) {
        groupedDylibs["@rpath"] = dylibs.filter { $0.hasPrefix("@rpath") }
        groupedDylibs["@executable_path"] = dylibs.filter { $0.hasPrefix("@executable_path") }
        groupedDylibs["/usr/lib"] = dylibs.filter { $0.hasPrefix("/usr/lib") }
        groupedDylibs["/System/Library"] = dylibs.filter { $0.hasPrefix("/System/Library") }
        groupedDylibs["Other"] = dylibs.filter { dylib in
            !dylib.hasPrefix("@rpath") &&
                !dylib.hasPrefix("@executable_path") &&
                !dylib.hasPrefix("/usr/lib") &&
                !dylib.hasPrefix("/System/Library")
        }
    }

    override func numberOfSections(in _: UITableView) -> Int {
        return dylibSections.count
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        let key = dylibSections[section]
        return groupedDylibs[key]?.count ?? 0
    }

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        return dylibSections[section]
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "dylibCell", for: indexPath)
        let key = dylibSections[indexPath.section]
        if let dylib = groupedDylibs[key]?[indexPath.row] {
            cell.textLabel?.text = dylib
            cell.textLabel?.textColor = dylibstoremove.contains(dylib) ? .systemRed : .label
        }
        return cell
    }

    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        if editingStyle == .delete {
            let key = dylibSections[indexPath.section]
            if let dylib = groupedDylibs[key]?[indexPath.row] {
                if !dylibstoremove.contains(dylib) {
                    dylibstoremove.append(dylib)
                }
                tableView.reloadRows(at: [indexPath], with: .automatic)
                print(dylibstoremove)
            }
        }
    }
}
