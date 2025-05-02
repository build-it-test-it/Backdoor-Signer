import Foundation
import UIKit

/// TerminalFileManager provides file system operations for the Terminal interface
/// This allows users to navigate, view, and manipulate files within the app sandbox
class TerminalFileManager {
    // MARK: - Singleton
    
    static let shared = TerminalFileManager()
    
    private init() {}
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private var currentDirectory: URL
    
    // MARK: - Initialization
    
    init() {
        // Start in the Documents directory
        currentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // MARK: - Directory Navigation
    
    /// Change the current working directory
    /// - Parameter path: The path to change to (absolute or relative)
    /// - Returns: Result with new path or error
    func changeDirectory(to path: String) -> Result<String, Error> {
        let targetURL: URL
        
        if path.starts(with: "/") {
            // Absolute path
            targetURL = URL(fileURLWithPath: path)
        } else if path == ".." {
            // Parent directory
            targetURL = currentDirectory.deletingLastPathComponent()
        } else if path == "~" {
            // Home directory
            targetURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        } else {
            // Relative path
            targetURL = currentDirectory.appendingPathComponent(path)
        }
        
        // Check if directory exists
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: targetURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            currentDirectory = targetURL
            return .success(currentDirectory.path)
        } else {
            return .failure(NSError(domain: "TerminalFileManagerErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Directory not found: \(path)"]))
        }
    }
    
    /// Get the current working directory
    /// - Returns: The path of the current directory
    func getCurrentDirectory() -> String {
        return currentDirectory.path
    }
    
    // MARK: - File Operations
    
    /// List files in the current directory
    /// - Parameter showHidden: Whether to show hidden files (starting with .)
    /// - Returns: Result with array of file information or error
    func listFiles(showHidden: Bool = false) -> Result<[FileInfo], Error> {
        do {
            let contents = try fileManager.contentsOfDirectory(at: currentDirectory, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .creationDateKey, .contentModificationDateKey], options: [])
            
            let fileInfos = try contents.compactMap { url -> FileInfo? in
                let filename = url.lastPathComponent
                
                // Skip hidden files if not requested
                if !showHidden && filename.starts(with: ".") {
                    return nil
                }
                
                let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .creationDateKey, .contentModificationDateKey])
                let isDirectory = resourceValues.isDirectory ?? false
                let fileSize = resourceValues.fileSize ?? 0
                let creationDate = resourceValues.creationDate
                let modificationDate = resourceValues.contentModificationDate
                
                return FileInfo(
                    name: filename,
                    path: url.path,
                    isDirectory: isDirectory,
                    size: fileSize,
                    creationDate: creationDate,
                    modificationDate: modificationDate
                )
            }
            
            // Sort directories first, then by name
            let sortedFiles = fileInfos.sorted { (file1, file2) -> Bool in
                if file1.isDirectory && !file2.isDirectory {
                    return true
                } else if !file1.isDirectory && file2.isDirectory {
                    return false
                } else {
                    return file1.name.localizedStandardCompare(file2.name) == .orderedAscending
                }
            }
            
            return .success(sortedFiles)
        } catch {
            return .failure(error)
        }
    }
    
    /// Create a new directory
    /// - Parameter name: Name of the directory to create
    /// - Returns: Result with success message or error
    func createDirectory(name: String) -> Result<String, Error> {
        let newDirectoryURL = currentDirectory.appendingPathComponent(name)
        
        do {
            try fileManager.createDirectory(at: newDirectoryURL, withIntermediateDirectories: false, attributes: nil)
            return .success("Directory created: \(name)")
        } catch {
            return .failure(error)
        }
    }
    
    /// Delete a file or directory
    /// - Parameter name: Name of the file or directory to delete
    /// - Returns: Result with success message or error
    func delete(name: String) -> Result<String, Error> {
        let itemURL = currentDirectory.appendingPathComponent(name)
        
        do {
            try fileManager.removeItem(at: itemURL)
            return .success("Deleted: \(name)")
        } catch {
            return .failure(error)
        }
    }
    
    /// Move or rename a file or directory
    /// - Parameters:
    ///   - sourceName: Name of the source file or directory
    ///   - destinationName: New name or path for the file or directory
    /// - Returns: Result with success message or error
    func move(sourceName: String, destinationName: String) -> Result<String, Error> {
        let sourceURL = currentDirectory.appendingPathComponent(sourceName)
        
        // Determine if destination is a path or just a new name
        let destinationURL: URL
        if destinationName.contains("/") {
            // It's a path
            if destinationName.starts(with: "/") {
                // Absolute path
                destinationURL = URL(fileURLWithPath: destinationName)
            } else {
                // Relative path
                destinationURL = currentDirectory.appendingPathComponent(destinationName)
            }
        } else {
            // It's just a new name in the same directory
            destinationURL = currentDirectory.appendingPathComponent(destinationName)
        }
        
        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
            return .success("Moved: \(sourceName) to \(destinationName)")
        } catch {
            return .failure(error)
        }
    }
    
    /// Copy a file or directory
    /// - Parameters:
    ///   - sourceName: Name of the source file or directory
    ///   - destinationName: New name or path for the copy
    /// - Returns: Result with success message or error
    func copy(sourceName: String, destinationName: String) -> Result<String, Error> {
        let sourceURL = currentDirectory.appendingPathComponent(sourceName)
        
        // Determine if destination is a path or just a new name
        let destinationURL: URL
        if destinationName.contains("/") {
            // It's a path
            if destinationName.starts(with: "/") {
                // Absolute path
                destinationURL = URL(fileURLWithPath: destinationName)
            } else {
                // Relative path
                destinationURL = currentDirectory.appendingPathComponent(destinationName)
            }
        } else {
            // It's just a new name in the same directory
            destinationURL = currentDirectory.appendingPathComponent(destinationName)
        }
        
        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return .success("Copied: \(sourceName) to \(destinationName)")
        } catch {
            return .failure(error)
        }
    }
    
    // MARK: - File Content Operations
    
    /// Read the contents of a text file
    /// - Parameter name: Name of the file to read
    /// - Returns: Result with file contents or error
    func readFile(name: String) -> Result<String, Error> {
        let fileURL = currentDirectory.appendingPathComponent(name)
        
        do {
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            return .success(contents)
        } catch {
            return .failure(error)
        }
    }
    
    /// Write text to a file
    /// - Parameters:
    ///   - name: Name of the file to write
    ///   - contents: Text contents to write
    ///   - append: Whether to append to existing file or overwrite
    /// - Returns: Result with success message or error
    func writeFile(name: String, contents: String, append: Bool = false) -> Result<String, Error> {
        let fileURL = currentDirectory.appendingPathComponent(name)
        
        do {
            if append && fileManager.fileExists(atPath: fileURL.path) {
                // Read existing content
                let existingContent = try String(contentsOf: fileURL, encoding: .utf8)
                // Append new content
                let newContent = existingContent + contents
                try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
            } else {
                // Write new content
                try contents.write(to: fileURL, atomically: true, encoding: .utf8)
            }
            return .success("Wrote to file: \(name)")
        } catch {
            return .failure(error)
        }
    }
    
    /// Get information about a file or directory
    /// - Parameter name: Name of the file or directory
    /// - Returns: Result with file information or error
    func getFileInfo(name: String) -> Result<FileInfo, Error> {
        let itemURL = currentDirectory.appendingPathComponent(name)
        
        do {
            let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .creationDateKey, .contentModificationDateKey])
            let isDirectory = resourceValues.isDirectory ?? false
            let fileSize = resourceValues.fileSize ?? 0
            let creationDate = resourceValues.creationDate
            let modificationDate = resourceValues.contentModificationDate
            
            let fileInfo = FileInfo(
                name: name,
                path: itemURL.path,
                isDirectory: isDirectory,
                size: fileSize,
                creationDate: creationDate,
                modificationDate: modificationDate
            )
            
            return .success(fileInfo)
        } catch {
            return .failure(error)
        }
    }
    
    /// Search for files matching a pattern
    /// - Parameters:
    ///   - pattern: The search pattern (supports * and ? wildcards)
    ///   - recursive: Whether to search recursively in subdirectories
    /// - Returns: Result with array of matching file paths or error
    func findFiles(pattern: String, recursive: Bool = false) -> Result<[String], Error> {
        do {
            var matchingFiles: [String] = []
            
            // Convert pattern to NSPredicate format
            let predicate: NSPredicate
            if pattern.contains("*") || pattern.contains("?") {
                predicate = NSPredicate(format: "SELF LIKE %@", pattern)
            } else {
                predicate = NSPredicate(format: "SELF == %@", pattern)
            }
            
            if recursive {
                // Get all files recursively
                let enumerator = fileManager.enumerator(at: currentDirectory, includingPropertiesForKeys: nil)
                while let url = enumerator?.nextObject() as? URL {
                    let filename = url.lastPathComponent
                    if predicate.evaluate(with: filename) {
                        matchingFiles.append(url.path)
                    }
                }
            } else {
                // Get files in current directory only
                let contents = try fileManager.contentsOfDirectory(at: currentDirectory, includingPropertiesForKeys: nil)
                for url in contents {
                    let filename = url.lastPathComponent
                    if predicate.evaluate(with: filename) {
                        matchingFiles.append(url.path)
                    }
                }
            }
            
            return .success(matchingFiles)
        } catch {
            return .failure(error)
        }
    }
    
    /// Get file permissions
    /// - Parameter name: Name of the file or directory
    /// - Returns: Result with permissions string (e.g., "rwxr-xr--") or error
    func getPermissions(name: String) -> Result<String, Error> {
        let itemURL = currentDirectory.appendingPathComponent(name)
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: itemURL.path)
            if let posixPermissions = attributes[.posixPermissions] as? NSNumber {
                let permissions = posixPermissions.intValue
                
                // Convert to string representation (e.g., "rwxr-xr--")
                var result = ""
                
                // Owner permissions
                result += (permissions & 0o400) != 0 ? "r" : "-"
                result += (permissions & 0o200) != 0 ? "w" : "-"
                result += (permissions & 0o100) != 0 ? "x" : "-"
                
                // Group permissions
                result += (permissions & 0o040) != 0 ? "r" : "-"
                result += (permissions & 0o020) != 0 ? "w" : "-"
                result += (permissions & 0o010) != 0 ? "x" : "-"
                
                // Other permissions
                result += (permissions & 0o004) != 0 ? "r" : "-"
                result += (permissions & 0o002) != 0 ? "w" : "-"
                result += (permissions & 0o001) != 0 ? "x" : "-"
                
                return .success(result)
            } else {
                return .failure(NSError(domain: "TerminalFileManagerErrorDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not get permissions for: \(name)"]))
            }
        } catch {
            return .failure(error)
        }
    }
    
    /// Set file permissions
    /// - Parameters:
    ///   - name: Name of the file or directory
    ///   - permissions: Octal permissions value (e.g., 0o755)
    /// - Returns: Result with success message or error
    func setPermissions(name: String, permissions: Int) -> Result<String, Error> {
        let itemURL = currentDirectory.appendingPathComponent(name)
        
        do {
            try fileManager.setAttributes([.posixPermissions: NSNumber(value: permissions)], ofItemAtPath: itemURL.path)
            return .success("Set permissions for \(name) to \(String(format: "%o", permissions))")
        } catch {
            return .failure(error)
        }
    }
}

// MARK: - Supporting Types

/// Represents information about a file or directory
struct FileInfo {
    /// Name of the file or directory
    let name: String
    
    /// Full path to the file or directory
    let path: String
    
    /// Whether the item is a directory
    let isDirectory: Bool
    
    /// Size of the file in bytes (0 for directories)
    let size: Int
    
    /// Creation date of the file or directory
    let creationDate: Date?
    
    /// Last modification date of the file or directory
    let modificationDate: Date?
    
    /// Formatted size string (e.g., "1.2 MB")
    var formattedSize: String {
        if isDirectory {
            return "-"
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
    
    /// Formatted creation date string
    var formattedCreationDate: String {
        guard let date = creationDate else { return "-" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Formatted modification date string
    var formattedModificationDate: String {
        guard let date = modificationDate else { return "-" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Type indicator for display (e.g., "d" for directory, "f" for file)
    var typeIndicator: String {
        return isDirectory ? "d" : "f"
    }
}

