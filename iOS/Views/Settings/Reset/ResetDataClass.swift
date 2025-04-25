import Foundation
import Nuke

class ResetDataClass {
    static let shared = ResetDataClass()

    init() {}
    deinit {}

    func clearNetworkCache() {
        URLCache.shared.removeAllCachedResponses()
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)

        if let dataCache = ImagePipeline.shared.configuration.dataCache as? DataCache {
            dataCache.removeAll()
        }

        if let imageCache = ImagePipeline.shared.configuration.imageCache as? Nuke.ImageCache {
            imageCache.removeAll()
        }
    }

    func deleteSignedApps() {
        do {
            try CoreDataManager.shared.clearSignedApps()
            deleteDirectory(named: "Apps", additionalComponents: ["Signed"])
        } catch {
            Debug.shared.log(message: "Error clearing signed apps: \(error)", type: .error)
        }
    }

    func deleteDownloadedApps() {
        do {
            try CoreDataManager.shared.clearDownloadedApps()
            deleteDirectory(named: "Apps", additionalComponents: ["Unsigned"])
        } catch {
            Debug.shared.log(message: "Error clearing downloaded apps: \(error)", type: .error)
        }
    }

    func resetCertificates(resetAll: Bool) {
        if !resetAll { Preferences.selectedCert = 0 }
        do {
            try CoreDataManager.shared.clearCertificate()
            deleteDirectory(named: "Certificates")
        } catch {
            Debug.shared.log(message: "Error clearing certificates: \(error)", type: .error)
        }
    }

    func resetSources(resetAll: Bool) {
        if !resetAll { Preferences.defaultRepos = false }
        do {
            try CoreDataManager.shared.clearSources()
        } catch {
            Debug.shared.log(message: "Error clearing sources: \(error)", type: .error)
        }
    }

    private func resetAllUserDefaults() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }

    func resetAll() {
        deleteSignedApps()
        deleteDownloadedApps()
        resetCertificates(resetAll: true)
        resetSources(resetAll: true)
        resetAllUserDefaults()
        clearNetworkCache()
    }

    private func deleteDirectory(named directoryName: String, additionalComponents: [String]? = nil) {
        var directoryURL = getDocumentsDirectory().appendingPathComponent(directoryName)

        if let components = additionalComponents {
            for component in components {
                directoryURL.appendPathComponent(component)
            }
        }

        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(at: directoryURL)
        } catch {
            Debug.shared.log(message: "Couldn't delete this, but thats ok!: \(error)", type: .debug)
        }
    }
}
