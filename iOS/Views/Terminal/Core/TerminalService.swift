import Foundation
import UIKit

enum TerminalError: Error {
    case invalidURL
    case networkError(String)
    case responseError(String)
    case sessionError(String)
    case parseError(String)
    case executionError(String)
    case localError(String)
}

typealias TerminalResult<T> = Result<T, TerminalError>

/// TerminalService - Provides terminal functionality
/// This is an updated version that uses a local implementation instead of a web server
class TerminalService {
    static let shared = TerminalService()
    
    private var sessionId: String?
    private let logger = Debug.shared
    
    // Local service for on-device execution
    private let localService = LocalTerminalService.shared
    
    // Output handlers
    private var outputHandlers: [String: (String) -> Void] = [:]
    
    // Settings/status
    private let useLocalImplementation = true
    private var isLocalSessionActive = false
    
    // Public accessor for active status
    var isWebSocketActive: Bool {
        return isLocalSessionActive
    }
    
    // Get the current session ID if available
    var currentSessionId: String? {
        return sessionId
    }
    
    private init() {
        logger.log(message: "TerminalService initialized with local implementation", type: .info)
    }
    
    // MARK: - Session Management
    
    /// Creates a new terminal session
    func createSession(completion: @escaping (TerminalResult<String>) -> Void) {
        logger.log(message: "Creating new terminal session", type: .info)
        
        localService.createSession { result in
            switch result {
            case .success(let newSessionId):
                self.sessionId = newSessionId
                self.isLocalSessionActive = true
                self.logger.log(message: "Local terminal session created: \(newSessionId)", type: .info)
                completion(.success(newSessionId))
                
            case .failure(let error):
                self.logger.log(message: "Failed to create local terminal session: \(error.localizedDescription)", type: .error)
                completion(.failure(TerminalError.localError(error.localizedDescription)))
            }
        }
    }
    
    /// Executes a command in the current session
    func executeCommand(
        _ command: String,
        outputHandler: @escaping (String) -> Void,
        completion: @escaping (TerminalResult<Void>) -> Void
    ) {
        // Make sure we have a session
        if sessionId == nil {
            createSession { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let newSessionId):
                    self.sessionId = newSessionId
                    self.executeCommandInSession(command, outputHandler: outputHandler, completion: completion)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            executeCommandInSession(command, outputHandler: outputHandler, completion: completion)
        }
    }
    
    /// Executes a command in a specific session
    private func executeCommandInSession(
        _ command: String,
        outputHandler: @escaping (String) -> Void,
        completion: @escaping (TerminalResult<Void>) -> Void
    ) {
        guard let sessionId = sessionId else {
            completion(.failure(TerminalError.sessionError("No active session")))
            return
        }
        
        // Register output handler for this session
        outputHandlers[sessionId] = outputHandler
        
        // Handle the clear command specially
        if command.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "clear" {
            // We'll let the terminal view handle clearing itself
            completion(.success(()))
            return
        }
        
        // Execute with the local service
        localService.executeCommand(
            command,
            sessionId: sessionId,
            outputHandler: outputHandler
        ) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                self.logger.log(message: "Command execution error: \(error.localizedDescription)", type: .error)
                completion(.failure(TerminalError.executionError(error.localizedDescription)))
            }
        }
    }
    
    /// Sends input to a running process
    func sendInput(
        _ input: String,
        completion: @escaping (TerminalResult<Void>) -> Void
    ) {
        guard let sessionId = sessionId else {
            completion(.failure(TerminalError.sessionError("No active session")))
            return
        }
        
        localService.sendInput(input, sessionId: sessionId) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                self.logger.log(message: "Failed to send input: \(error.localizedDescription)", type: .error)
                completion(.failure(TerminalError.executionError(error.localizedDescription)))
            }
        }
    }
    
    /// Terminates the current session
    func terminateSession(completion: @escaping (TerminalResult<Void>) -> Void) {
        guard let sessionId = sessionId else {
            // No session to terminate
            completion(.success(()))
            return
        }
        
        localService.terminateSession(sessionId) { result in
            switch result {
            case .success:
                self.sessionId = nil
                self.outputHandlers.removeValue(forKey: sessionId)
                self.isLocalSessionActive = false
                completion(.success(()))
                
            case .failure(let error):
                self.logger.log(message: "Failed to terminate session: \(error.localizedDescription)", type: .error)
                completion(.failure(TerminalError.executionError(error.localizedDescription)))
            }
        }
    }
    
    /// Resizes the terminal session (placeholder for compatibility)
    /// Local implementation doesn't need resizing but we keep the method for API compatibility
    func resizeSession(cols: Int, rows: Int, completion: @escaping (TerminalResult<Void>) -> Void) {
        // Local implementation doesn't need explicit resizing
        completion(.success(()))
    }
    
    /// Alias for terminateSession to maintain backward compatibility
    func endSession(completion: @escaping (TerminalResult<Void>) -> Void) {
        terminateSession(completion: completion)
    }
}

// Legacy wrapper class for compatibility
class ProcessUtility {
    static let shared = ProcessUtility()
    private let logger = Debug.shared
    
    private init() {}
    
    /// Executes a shell command and returns the output.
    /// - Parameters:
    ///   - command: The shell command to be executed.
    ///   - completion: A closure to be called with the command's output or an error message.
    func executeShellCommand(_ command: String, completion: @escaping (String?) -> Void) {
        var output = ""
        
        logger.log(message: "ProcessUtility executing command: \(command)", type: .info)
        
        TerminalService.shared.executeCommand(command, outputHandler: { newOutput in
            output += newOutput
        }) { result in
            switch result {
            case .success:
                completion(output)
            case .failure(let error):
                completion("Error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Executes a shell command with real-time output streaming.
    /// - Parameters:
    ///   - command: The shell command to be executed.
    ///   - outputHandler: Real-time handler for command output chunks.
    ///   - completion: A closure to be called when the command completes.
    func executeShellCommandWithStreaming(
        _ command: String,
        outputHandler: @escaping (String) -> Void,
        completion: @escaping (String?) -> Void
    ) {
        var fullOutput = ""
        
        logger.log(message: "ProcessUtility executing streaming command: \(command)", type: .info)
        
        TerminalService.shared.executeCommand(command, outputHandler: { newOutput in
            // Send chunk to handler
            outputHandler(newOutput)
            
            // Accumulate for final output
            fullOutput += newOutput
        }) { result in
            switch result {
            case .success:
                completion(fullOutput)
            case .failure(let error):
                completion("Error: \(error.localizedDescription)")
            }
        }
    }
}
