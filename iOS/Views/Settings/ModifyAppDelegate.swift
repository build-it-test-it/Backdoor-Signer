import UIKit
import Foundation

/// ModifyAppDelegate provides functionality to modify app delegate files in iOS applications
/// This allows for customizing app behavior by injecting code into the app delegate
class ModifyAppDelegate {
    // MARK: - Singleton
    
    static let shared = ModifyAppDelegate()
    
    private init() {}
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    
    // MARK: - Public Methods
    
    /// Analyze an app's delegate file to find injection points
    /// - Parameter appURL: URL to the .app directory
    /// - Returns: Array of potential injection points
    func analyzeAppDelegate(at appURL: URL) -> [InjectionPoint] {
        guard let appDelegateURL = findAppDelegateFile(in: appURL) else {
            Debug.shared.log(message: "Could not find AppDelegate file", type: .error)
            return []
        }
        
        do {
            let appDelegateContent = try String(contentsOf: appDelegateURL, encoding: .utf8)
            return findInjectionPoints(in: appDelegateContent)
        } catch {
            Debug.shared.log(message: "Error reading AppDelegate file: \(error.localizedDescription)", type: .error)
            return []
        }
    }
    
    /// Inject code into an app's delegate file at a specific injection point
    /// - Parameters:
    ///   - appURL: URL to the .app directory
    ///   - injectionPoint: The point at which to inject code
    ///   - code: The Swift code to inject
    /// - Returns: Success or failure with error
    func injectCode(at appURL: URL, injectionPoint: InjectionPoint, code: String) -> Result<Void, Error> {
        guard let appDelegateURL = findAppDelegateFile(in: appURL) else {
            return .failure(NSError(domain: "ModifyAppDelegateErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find AppDelegate file"]))
        }
        
        do {
            var appDelegateContent = try String(contentsOf: appDelegateURL, encoding: .utf8)
            
            // Create a backup of the original file
            let backupURL = appDelegateURL.deletingLastPathComponent().appendingPathComponent("AppDelegate.swift.backup")
            try appDelegateContent.write(to: backupURL, atomically: true, encoding: .utf8)
            
            // Inject the code at the specified point
            let modifiedContent = injectCodeAtPoint(content: appDelegateContent, injectionPoint: injectionPoint, code: code)
            
            // Write the modified content back to the file
            try modifiedContent.write(to: appDelegateURL, atomically: true, encoding: .utf8)
            
            Debug.shared.log(message: "Successfully injected code into AppDelegate", type: .success)
            return .success(())
        } catch {
            Debug.shared.log(message: "Error modifying AppDelegate file: \(error.localizedDescription)", type: .error)
            return .failure(error)
        }
    }
    
    /// Add a new method to the AppDelegate class
    /// - Parameters:
    ///   - appURL: URL to the .app directory
    ///   - methodName: Name of the method to add
    ///   - methodCode: The Swift code for the method body
    ///   - returnType: The return type of the method (default: "Void")
    ///   - parameters: Array of parameter names and types
    /// - Returns: Success or failure with error
    func addMethod(at appURL: URL, methodName: String, methodCode: String, returnType: String = "Void", parameters: [(name: String, type: String)] = []) -> Result<Void, Error> {
        guard let appDelegateURL = findAppDelegateFile(in: appURL) else {
            return .failure(NSError(domain: "ModifyAppDelegateErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find AppDelegate file"]))
        }
        
        do {
            var appDelegateContent = try String(contentsOf: appDelegateURL, encoding: .utf8)
            
            // Create a backup of the original file
            let backupURL = appDelegateURL.deletingLastPathComponent().appendingPathComponent("AppDelegate.swift.backup")
            try appDelegateContent.write(to: backupURL, atomically: true, encoding: .utf8)
            
            // Format the parameters
            let parameterString = parameters.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
            
            // Create the method
            let methodString = """
            
                // Added by Backdoor
                func \(methodName)(\(parameterString)) -> \(returnType) {
                    \(methodCode)
                }
            """
            
            // Find the end of the AppDelegate class
            if let range = appDelegateContent.range(of: "}\\s*$", options: .regularExpression) {
                // Insert the method before the closing brace
                appDelegateContent.insert(contentsOf: methodString, at: range.lowerBound)
                
                // Write the modified content back to the file
                try appDelegateContent.write(to: appDelegateURL, atomically: true, encoding: .utf8)
                
                Debug.shared.log(message: "Successfully added method \(methodName) to AppDelegate", type: .success)
                return .success(())
            } else {
                return .failure(NSError(domain: "ModifyAppDelegateErrorDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not find end of AppDelegate class"]))
            }
        } catch {
            Debug.shared.log(message: "Error modifying AppDelegate file: \(error.localizedDescription)", type: .error)
            return .failure(error)
        }
    }
    
    /// Add import statements to the AppDelegate file
    /// - Parameters:
    ///   - appURL: URL to the .app directory
    ///   - imports: Array of module names to import
    /// - Returns: Success or failure with error
    func addImports(at appURL: URL, imports: [String]) -> Result<Void, Error> {
        guard let appDelegateURL = findAppDelegateFile(in: appURL) else {
            return .failure(NSError(domain: "ModifyAppDelegateErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find AppDelegate file"]))
        }
        
        do {
            var appDelegateContent = try String(contentsOf: appDelegateURL, encoding: .utf8)
            
            // Create a backup of the original file
            let backupURL = appDelegateURL.deletingLastPathComponent().appendingPathComponent("AppDelegate.swift.backup")
            try appDelegateContent.write(to: backupURL, atomically: true, encoding: .utf8)
            
            // Format the import statements
            let importStatements = imports.map { "import \($0)" }.joined(separator: "\n")
            
            // Find the last import statement
            if let range = appDelegateContent.range(of: "import [^\\n]+", options: .regularExpression, range: nil, locale: nil) {
                let searchRange = appDelegateContent.startIndex..<appDelegateContent.endIndex
                let matches = appDelegateContent.matches(of: /import [^\n]+/, in: searchRange)
                
                if let lastMatch = matches.last {
                    // Insert the new imports after the last existing import
                    let insertionPoint = lastMatch.range.upperBound
                    appDelegateContent.insert(contentsOf: "\n\(importStatements)", at: insertionPoint)
                    
                    // Write the modified content back to the file
                    try appDelegateContent.write(to: appDelegateURL, atomically: true, encoding: .utf8)
                    
                    Debug.shared.log(message: "Successfully added imports to AppDelegate", type: .success)
                    return .success(())
                }
            }
            
            // If no existing imports found, add at the beginning of the file
            appDelegateContent = importStatements + "\n\n" + appDelegateContent
            try appDelegateContent.write(to: appDelegateURL, atomically: true, encoding: .utf8)
            
            Debug.shared.log(message: "Successfully added imports to AppDelegate", type: .success)
            return .success(())
        } catch {
            Debug.shared.log(message: "Error modifying AppDelegate file: \(error.localizedDescription)", type: .error)
            return .failure(error)
        }
    }
    
    // MARK: - Private Methods
    
    /// Find the AppDelegate.swift file in an app bundle
    private func findAppDelegateFile(in appURL: URL) -> URL? {
        do {
            // Look for AppDelegate.swift in the app bundle
            let appContents = try fileManager.contentsOfDirectory(at: appURL, includingPropertiesForKeys: nil, options: [])
            
            // First check for a direct match
            if let appDelegateURL = appContents.first(where: { $0.lastPathComponent == "AppDelegate.swift" }) {
                return appDelegateURL
            }
            
            // If not found directly, search recursively
            for url in appContents where url.hasDirectoryPath {
                if let found = searchRecursively(for: "AppDelegate.swift", in: url) {
                    return found
                }
            }
            
            return nil
        } catch {
            Debug.shared.log(message: "Error searching for AppDelegate file: \(error.localizedDescription)", type: .error)
            return nil
        }
    }
    
    /// Search recursively for a file with the given name
    private func searchRecursively(for fileName: String, in directory: URL) -> URL? {
        do {
            let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [])
            
            // Check for a direct match
            if let match = contents.first(where: { $0.lastPathComponent == fileName }) {
                return match
            }
            
            // Recursively search subdirectories
            for url in contents where url.hasDirectoryPath {
                if let found = searchRecursively(for: fileName, in: url) {
                    return found
                }
            }
            
            return nil
        } catch {
            return nil
        }
    }
    
    /// Find potential injection points in the AppDelegate content
    private func findInjectionPoints(in content: String) -> [InjectionPoint] {
        var injectionPoints: [InjectionPoint] = []
        
        // Look for application lifecycle methods
        let lifecycleMethods = [
            "application(_:didFinishLaunchingWithOptions:)",
            "applicationDidBecomeActive(_:)",
            "applicationWillResignActive(_:)",
            "applicationDidEnterBackground(_:)",
            "applicationWillEnterForeground(_:)",
            "applicationWillTerminate(_:)"
        ]
        
        for method in lifecycleMethods {
            if let range = content.range(of: "func \\s*\(method.replacingOccurrences(of: "(", with: "\\(").replacingOccurrences(of: ")", with: "\\)").replacingOccurrences(of: ":", with: "\\:"))\\s*[{]", options: .regularExpression) {
                // Find the opening brace
                if let openBraceRange = content.range(of: "{", options: [], range: range.lowerBound..<content.endIndex) {
                    // Add injection point at the beginning of the method body
                    let startPoint = content.index(after: openBraceRange.lowerBound)
                    injectionPoints.append(InjectionPoint(
                        name: "Beginning of \(method)",
                        position: .methodStart(method: method),
                        index: startPoint
                    ))
                    
                    // Try to find the return statement or end of method
                    if let returnRange = content.range(of: "return\\s+[^\\n]+", options: .regularExpression, range: startPoint..<content.endIndex) {
                        // Add injection point before the return statement
                        injectionPoints.append(InjectionPoint(
                            name: "Before return in \(method)",
                            position: .beforeReturn(method: method),
                            index: returnRange.lowerBound
                        ))
                    }
                    
                    // Find the end of the method
                    var depth = 1
                    var currentIndex = content.index(after: openBraceRange.lowerBound)
                    
                    while depth > 0 && currentIndex < content.endIndex {
                        let char = content[currentIndex]
                        if char == "{" {
                            depth += 1
                        } else if char == "}" {
                            depth -= 1
                            if depth == 0 {
                                // Add injection point at the end of the method body
                                let endPoint = content.index(before: currentIndex)
                                injectionPoints.append(InjectionPoint(
                                    name: "End of \(method)",
                                    position: .methodEnd(method: method),
                                    index: endPoint
                                ))
                            }
                        }
                        currentIndex = content.index(after: currentIndex)
                    }
                }
            }
        }
        
        // Look for class declaration to add properties
        if let classRange = content.range(of: "class\\s+AppDelegate\\s*:\\s*[^{]+\\s*{", options: .regularExpression) {
            if let openBraceRange = content.range(of: "{", options: [], range: classRange.lowerBound..<content.endIndex) {
                let startPoint = content.index(after: openBraceRange.lowerBound)
                injectionPoints.append(InjectionPoint(
                    name: "Class properties",
                    position: .classProperties,
                    index: startPoint
                ))
            }
        }
        
        // Look for end of class to add methods
        if let lastBraceRange = content.range(of: "}\\s*$", options: .regularExpression) {
            injectionPoints.append(InjectionPoint(
                name: "End of class (add methods)",
                position: .classEnd,
                index: lastBraceRange.lowerBound
            ))
        }
        
        return injectionPoints
    }
    
    /// Inject code at a specific injection point
    private func injectCodeAtPoint(content: String, injectionPoint: InjectionPoint, code: String) -> String {
        var modifiedContent = content
        
        // Add a comment to indicate the injected code
        let injectedCode = "\n    // Injected by Backdoor\n    \(code)\n"
        
        // Insert the code at the specified index
        modifiedContent.insert(contentsOf: injectedCode, at: injectionPoint.index)
        
        return modifiedContent
    }
}

// MARK: - Supporting Types

/// Represents a point in the code where new code can be injected
struct InjectionPoint {
    /// User-friendly name for the injection point
    let name: String
    
    /// Position type for the injection point
    let position: InjectionPosition
    
    /// The exact index in the string where code should be injected
    let index: String.Index
}

/// Enum representing different types of injection positions
enum InjectionPosition {
    /// Beginning of a method body
    case methodStart(method: String)
    
    /// Before a return statement in a method
    case beforeReturn(method: String)
    
    /// End of a method body
    case methodEnd(method: String)
    
    /// After class declaration (for adding properties)
    case classProperties
    
    /// End of class (for adding methods)
    case classEnd
}

