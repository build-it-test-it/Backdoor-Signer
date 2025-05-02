import Foundation
import UIKit

/// BackdoorCLI provides command-line interface capabilities for the Backdoor app
/// This allows for scripting and automation of app signing operations
class BackdoorCLI {
    // MARK: - Singleton
    
    static let shared = BackdoorCLI()
    
    private init() {}
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let commandQueue = DispatchQueue(label: "com.bdg.backdoor.cli", qos: .userInitiated)
    
    // MARK: - Public Methods
    
    /// Execute a CLI command with arguments
    /// - Parameter command: The command string to parse and execute
    /// - Parameter completion: Callback with result of command execution
    func executeCommand(_ command: String, completion: @escaping (Result<String, Error>) -> Void) {
        commandQueue.async { [weak self] in
            guard let self = self else {
                completion(.failure(NSError(domain: "BackdoorCLIErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "CLI instance was deallocated"])))
                return
            }
            
            let components = self.parseCommand(command)
            guard let mainCommand = components.first else {
                completion(.failure(NSError(domain: "BackdoorCLIErrorDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: "No command provided"])))
                return
            }
            
            let arguments = Array(components.dropFirst())
            
            switch mainCommand.lowercased() {
            case "help":
                completion(.success(self.helpCommand()))
            case "sign":
                self.signCommand(arguments: arguments, completion: completion)
            case "list":
                self.listCommand(arguments: arguments, completion: completion)
            case "install":
                self.installCommand(arguments: arguments, completion: completion)
            case "version":
                completion(.success(self.versionCommand()))
            default:
                completion(.failure(NSError(domain: "BackdoorCLIErrorDomain", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unknown command: \(mainCommand)"])))
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func parseCommand(_ command: String) -> [String] {
        var components: [String] = []
        var currentComponent = ""
        var insideQuotes = false
        var escapeNext = false
        
        for char in command {
            if escapeNext {
                currentComponent.append(char)
                escapeNext = false
            } else if char == "\\" {
                escapeNext = true
            } else if char == "\"" {
                insideQuotes.toggle()
            } else if char.isWhitespace && !insideQuotes {
                if !currentComponent.isEmpty {
                    components.append(currentComponent)
                    currentComponent = ""
                }
            } else {
                currentComponent.append(char)
            }
        }
        
        if !currentComponent.isEmpty {
            components.append(currentComponent)
        }
        
        return components
    }
    
    // MARK: - Command Implementations
    
    private func helpCommand() -> String {
        return """
        Backdoor CLI Help:
        ------------------
        help                    - Show this help message
        version                 - Show the app version
        sign <app> <cert> [options] - Sign an application
          Options:
            --bundleid <id>     - Set bundle identifier
            --name <name>       - Set app name
            --version <ver>     - Set app version
            --dylib <path>      - Inject dylib
        list <type>             - List items of specified type
          Types:
            certs               - List available certificates
            apps                - List signed applications
        install <app>           - Install a signed application
        """
    }
    
    private func versionCommand() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "Backdoor CLI v\(appVersion) (Build \(buildNumber))"
    }
    
    private func signCommand(arguments: [String], completion: @escaping (Result<String, Error>) -> Void) {
        guard arguments.count >= 2 else {
            completion(.failure(NSError(domain: "BackdoorCLIErrorDomain", code: 4, userInfo: [NSLocalizedDescriptionKey: "Usage: sign <app> <cert> [options]"])))
            return
        }
        
        let appPath = arguments[0]
        let certName = arguments[1]
        
        // Parse options
        var bundleId: String?
        var appName: String?
        var appVersion: String?
        var dylibPath: String?
        
        var i = 2
        while i < arguments.count {
            switch arguments[i].lowercased() {
            case "--bundleid":
                if i + 1 < arguments.count {
                    bundleId = arguments[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            case "--name":
                if i + 1 < arguments.count {
                    appName = arguments[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            case "--version":
                if i + 1 < arguments.count {
                    appVersion = arguments[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            case "--dylib":
                if i + 1 < arguments.count {
                    dylibPath = arguments[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            default:
                i += 1
            }
        }
        
        // Verify app path
        let appURL = URL(fileURLWithPath: appPath)
        if !fileManager.fileExists(atPath: appURL.path) {
            completion(.failure(NSError(domain: "BackdoorCLIErrorDomain", code: 5, userInfo: [NSLocalizedDescriptionKey: "App not found at path: \(appPath)"])))
            return
        }
        
        // Find certificate
        CoreDataManager.shared.fetchCertificates { result in
            switch result {
            case .success(let certificates):
                guard let certificate = certificates.first(where: { $0.name == certName }) else {
                    completion(.failure(NSError(domain: "BackdoorCLIErrorDomain", code: 6, userInfo: [NSLocalizedDescriptionKey: "Certificate not found: \(certName)"])))
                    return
                }
                
                // Create signing options
                let mainOptions = SigningMainDataWrapper(mainOptions: SigningMainOptions(
                    certificate: certificate,
                    bundleId: bundleId,
                    name: appName,
                    version: appVersion,
                    iconURL: nil,
                    removeInjectPaths: []
                ))
                
                let signingOptions = SigningDataWrapper(signingOptions: SigningOptions(
                    removePlugins: true,
                    removeWatchPlaceHolder: true,
                    removeProvisioningFile: true,
                    forceFileSharing: true,
                    forceiTunesFileSharing: true,
                    removeSupportedDevices: true,
                    removeURLScheme: false,
                    forceProMotion: true,
                    forceGameMode: false,
                    forceForceFullScreen: false,
                    forceMinimumVersion: "Automatic",
                    forceLightDarkAppearence: "Automatic",
                    forceTryToLocalize: true,
                    toInject: dylibPath != nil ? [dylibPath!] : []
                ))
                
                // Create bundle options
                let bundle = BundleOptions(
                    name: appName,
                    bundleId: bundleId,
                    version: appVersion,
                    sourceURL: appURL.absoluteString
                )
                
                // Sign the app
                signInitialApp(
                    bundle: bundle,
                    mainOptions: mainOptions,
                    signingOptions: signingOptions,
                    appPath: appURL
                ) { result in
                    switch result {
                    case .success(let (signedPath, _)):
                        completion(.success("App signed successfully: \(signedPath.path)"))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func listCommand(arguments: [String], completion: @escaping (Result<String, Error>) -> Void) {
        guard let type = arguments.first?.lowercased() else {
            completion(.failure(NSError(domain: "BackdoorCLIErrorDomain", code: 7, userInfo: [NSLocalizedDescriptionKey: "Usage: list <type> (certs|apps)"])))
            return
        }
        
        switch type {
        case "certs":
            CoreDataManager.shared.fetchCertificates { result in
                switch result {
                case .success(let certificates):
                    if certificates.isEmpty {
                        completion(.success("No certificates found."))
                    } else {
                        var output = "Available Certificates:\n"
                        for (index, cert) in certificates.enumerated() {
                            let expirationDate = cert.expirationDate?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown"
                            output += "\(index + 1). \(cert.name ?? "Unnamed") (Expires: \(expirationDate))\n"
                        }
                        completion(.success(output))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            
        case "apps":
            CoreDataManager.shared.fetchSignedApps { result in
                switch result {
                case .success(let apps):
                    if apps.isEmpty {
                        completion(.success("No signed apps found."))
                    } else {
                        var output = "Signed Applications:\n"
                        for (index, app) in apps.enumerated() {
                            let name = app.name ?? "Unnamed"
                            let bundleId = app.bundleidentifier ?? "Unknown"
                            let version = app.version ?? "Unknown"
                            output += "\(index + 1). \(name) (\(bundleId), v\(version))\n"
                        }
                        completion(.success(output))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            
        default:
            completion(.failure(NSError(domain: "BackdoorCLIErrorDomain", code: 8, userInfo: [NSLocalizedDescriptionKey: "Unknown list type: \(type). Use 'certs' or 'apps'."])))
        }
    }
    
    private func installCommand(arguments: [String], completion: @escaping (Result<String, Error>) -> Void) {
        guard let appPath = arguments.first else {
            completion(.failure(NSError(domain: "BackdoorCLIErrorDomain", code: 9, userInfo: [NSLocalizedDescriptionKey: "Usage: install <app>"])))
            return
        }
        
        let appURL = URL(fileURLWithPath: appPath)
        if !fileManager.fileExists(atPath: appURL.path) {
            completion(.failure(NSError(domain: "BackdoorCLIErrorDomain", code: 10, userInfo: [NSLocalizedDescriptionKey: "App not found at path: \(appPath)"])))
            return
        }
        
        // Attempt to install the app
        DispatchQueue.main.async {
            let installManager = InstallManager.shared
            installManager.installApp(at: appURL) { success, error in
                if success {
                    completion(.success("App installed successfully"))
                } else if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.failure(NSError(domain: "BackdoorCLIErrorDomain", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to install app for unknown reason"])))
                }
            }
        }
    }
}

// MARK: - InstallManager Mock

/// Mock class for InstallManager to make the code compile
/// This should be replaced with the actual implementation
class InstallManager {
    static let shared = InstallManager()
    
    private init() {}
    
    func installApp(at url: URL, completion: @escaping (Bool, Error?) -> Void) {
        // In a real implementation, this would use LSApplicationWorkspace or similar
        // to install the app
        Debug.shared.log(message: "Installing app at \(url.path)", type: .info)
        
        // Simulate installation success
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(true, nil)
        }
    }
}
