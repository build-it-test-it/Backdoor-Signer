import Foundation
import UIKit

/// LocalTerminalService - An on-device implementation of terminal functionality
/// This replaces the previous web-based terminal implementation with a fully local solution
class LocalTerminalService {
    static let shared = LocalTerminalService()
    
    // Process handling
    private var activeProcesses: [String: Process] = [:]
    private var outputPipes: [String: Pipe] = [:]
    private var inputPipes: [String: Pipe] = [:]
    
    // Output handlers
    private var outputHandlers: [String: (String) -> Void] = [:]
    
    // Terminal working directories
    private var workingDirectories: [String: URL] = [:]
    
    private let logger = Debug.shared
    
    // Environment setup
    private var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color" // Standard terminal type
        return env
    }
    
    private init() {
        logger.log(message: "LocalTerminalService initialized", type: .info)
    }
    
    // MARK: - Session Management
    
    /// Creates a new terminal session
    func createSession(completion: @escaping (Result<String, Error>) -> Void) {
        let sessionId = UUID().uuidString
        
        // Set default working directory to Documents
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        workingDirectories[sessionId] = documentsDirectory
        
        logger.log(message: "Created new local terminal session: \(sessionId)", type: .info)
        completion(.success(sessionId))
    }
    
    /// Terminates a terminal session
    func terminateSession(_ sessionId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        if let process = activeProcesses[sessionId] {
            // Terminate any running process
            process.terminate()
            activeProcesses.removeValue(forKey: sessionId)
            outputPipes.removeValue(forKey: sessionId)
            inputPipes.removeValue(forKey: sessionId)
        }
        
        // Clean up resources
        outputHandlers.removeValue(forKey: sessionId)
        workingDirectories.removeValue(forKey: sessionId)
        
        logger.log(message: "Terminated local terminal session: \(sessionId)", type: .info)
        completion(.success(()))
    }
    
    // MARK: - Command Execution
    
    /// Executes a command in the specified session
    func executeCommand(
        _ command: String,
        sessionId: String,
        outputHandler: @escaping (String) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Register output handler for this session
        outputHandlers[sessionId] = outputHandler
        
        // Parse command to check for special handling
        if handleSpecialCommand(command, sessionId: sessionId, outputHandler: outputHandler, completion: completion) {
            return
        }
        
        // Check for custom language syntax
        if command.hasPrefix("#!") || command.contains("swift:") || command.contains("python:") {
            executeCustomLanguageCommand(command, sessionId: sessionId, outputHandler: outputHandler, completion: completion)
            return
        }
        
        // Get working directory for this session
        let currentDirectory = workingDirectories[sessionId] ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Create process
        let process = Process()
        let outputPipe = Pipe()
        let inputPipe = Pipe()
        let errorPipe = Pipe()
        
        // Set up process
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = currentDirectory
        process.standardOutput = outputPipe
        process.standardInput = inputPipe
        process.standardError = errorPipe
        process.environment = self.environment
        
        // Store process and pipes
        activeProcesses[sessionId] = process
        outputPipes[sessionId] = outputPipe
        inputPipes[sessionId] = inputPipe
        
        // Handle standard output
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            guard let self = self, let handler = self.outputHandlers[sessionId] else { return }
            
            let data = fileHandle.availableData
            if data.count > 0, let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    handler(output)
                }
            }
        }
        
        // Handle standard error (treat as standard output for terminal display)
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            guard let self = self, let handler = self.outputHandlers[sessionId] else { return }
            
            let data = fileHandle.availableData
            if data.count > 0, let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    handler(output)
                }
            }
        }
        
        // Run process
        do {
            try process.run()
            
            logger.log(message: "Executing command: \(command) in session: \(sessionId)", type: .info)
            
            // For non-background commands, wait for completion
            if !command.hasSuffix(" &") {
                process.waitUntilExit()
                
                // Clean up
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
                // Check for CD command to update working directory
                if command.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("cd ") {
                    updateWorkingDirectory(command, sessionId: sessionId, outputHandler: outputHandler)
                }
                
                activeProcesses.removeValue(forKey: sessionId)
                
                completion(.success(()))
            } else {
                // For background processes, just return
                completion(.success(()))
            }
        } catch {
            logger.log(message: "Failed to execute command: \(error.localizedDescription)", type: .error)
            outputHandler("Error: \(error.localizedDescription)\n")
            completion(.failure(error))
        }
    }
    
    /// Sends input to a running process
    func sendInput(_ input: String, sessionId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let inputPipe = inputPipes[sessionId] else {
            let error = NSError(domain: "LocalTerminalService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No active process found"])
            completion(.failure(error))
            return
        }
        
        do {
            if let data = input.data(using: .utf8) {
                try inputPipe.fileHandleForWriting.write(contentsOf: data)
                completion(.success(()))
            } else {
                throw NSError(domain: "LocalTerminalService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode input"])
            }
        } catch {
            logger.log(message: "Failed to send input: \(error.localizedDescription)", type: .error)
            completion(.failure(error))
        }
    }
    
    /// Handles special built-in commands
    private func handleSpecialCommand(
        _ command: String, 
        sessionId: String,
        outputHandler: @escaping (String) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) -> Bool {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle special commands
        switch trimmedCommand.lowercased() {
        case "clear", "cls":
            // Just return success - the terminal view will handle clearing
            completion(.success(()))
            return true
            
        case "pwd":
            // Print working directory
            let currentDirectory = workingDirectories[sessionId]?.path ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
            outputHandler("\(currentDirectory)\n")
            completion(.success(()))
            return true
            
        case "help":
            // Show custom help
            showHelp(outputHandler: outputHandler)
            completion(.success(()))
            return true
            
        case "language", "lang":
            // Show custom language help
            showLanguageHelp(outputHandler: outputHandler)
            completion(.success(()))
            return true
            
        default:
            break
        }
        
        return false
    }
    
    /// Updates the working directory after a 'cd' command
    private func updateWorkingDirectory(
        _ command: String, 
        sessionId: String,
        outputHandler: @escaping (String) -> Void
    ) {
        // Extract path from cd command
        let components = command.split(separator: " ", maxSplits: 1)
        guard components.count > 1 else { return }
        
        let pathComponent = String(components[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        let currentDirectory = workingDirectories[sessionId] ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        if pathComponent == "~" {
            // Navigate to home directory (Documents)
            workingDirectories[sessionId] = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            return
        }
        
        if pathComponent.hasPrefix("/") {
            // Absolute path
            let url = URL(fileURLWithPath: pathComponent)
            var isDir: ObjCBool = false
            
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                workingDirectories[sessionId] = url
            } else {
                outputHandler("cd: \(pathComponent): No such directory\n")
            }
        } else {
            // Relative path
            let url = currentDirectory.appendingPathComponent(pathComponent)
            var isDir: ObjCBool = false
            
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                workingDirectories[sessionId] = url
            } else {
                outputHandler("cd: \(pathComponent): No such directory\n")
            }
        }
    }
    
    // MARK: - Custom Language Support
    
    /// Executes a command in our custom programming language
    private func executeCustomLanguageCommand(
        _ command: String, 
        sessionId: String,
        outputHandler: @escaping (String) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Delay execution to background thread
        DispatchQueue.global(qos: .userInitiated).async {
            // Parse the command to identify language mode
            let parser = CustomLanguageParser()
            let result = parser.parse(command)
            
            switch result {
            case .success(let parsedCommand):
                // Execute based on language mode
                switch parsedCommand.mode {
                case .swift:
                    self.executeSwiftCode(parsedCommand.code, sessionId: sessionId, outputHandler: outputHandler, completion: completion)
                    
                case .python:
                    self.executePythonCode(parsedCommand.code, sessionId: sessionId, outputHandler: outputHandler, completion: completion)
                    
                case .mixed:
                    self.executeMixedCode(parsedCommand.code, sessionId: sessionId, outputHandler: outputHandler, completion: completion)
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    outputHandler("Error parsing command: \(error.localizedDescription)\n")
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Executes Swift code
    private func executeSwiftCode(
        _ code: String, 
        sessionId: String,
        outputHandler: @escaping (String) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Create a temporary Swift file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("temp_script_\(UUID().uuidString).swift")
        
        do {
            try code.write(to: fileURL, atomically: true, encoding: .utf8)
            
            // Execute Swift code
            let currentDirectory = workingDirectories[sessionId] ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["swift", fileURL.path]
            process.currentDirectoryURL = currentDirectory
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            // Handle output
            outputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        outputHandler(output)
                    }
                }
            }
            
            // Handle errors
            errorPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        outputHandler(output)
                    }
                }
            }
            
            // Run process
            try process.run()
            process.waitUntilExit()
            
            // Clean up
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            
            // Delete the temporary file
            try FileManager.default.removeItem(at: fileURL)
            
            // Return success
            DispatchQueue.main.async {
                completion(.success(()))
            }
        } catch {
            logger.log(message: "Failed to execute Swift code: \(error.localizedDescription)", type: .error)
            DispatchQueue.main.async {
                outputHandler("Error executing Swift code: \(error.localizedDescription)\n")
                completion(.failure(error))
            }
        }
    }
    
    /// Executes Python code
    private func executePythonCode(
        _ code: String, 
        sessionId: String,
        outputHandler: @escaping (String) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Create a temporary Python file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("temp_script_\(UUID().uuidString).py")
        
        do {
            try code.write(to: fileURL, atomically: true, encoding: .utf8)
            
            // Execute Python code
            let currentDirectory = workingDirectories[sessionId] ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["python3", fileURL.path]
            process.currentDirectoryURL = currentDirectory
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            // Handle output
            outputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        outputHandler(output)
                    }
                }
            }
            
            // Handle errors
            errorPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        outputHandler(output)
                    }
                }
            }
            
            // Run process
            try process.run()
            process.waitUntilExit()
            
            // Clean up
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            
            // Delete the temporary file
            try FileManager.default.removeItem(at: fileURL)
            
            // Return success
            DispatchQueue.main.async {
                completion(.success(()))
            }
        } catch {
            logger.log(message: "Failed to execute Python code: \(error.localizedDescription)", type: .error)
            DispatchQueue.main.async {
                outputHandler("Error executing Python code: \(error.localizedDescription)\n")
                completion(.failure(error))
            }
        }
    }
    
    /// Executes mixed code that contains both Python and Swift
    private func executeMixedCode(
        _ code: String, 
        sessionId: String,
        outputHandler: @escaping (String) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Create a temporary directory for the code
        let tempDir = FileManager.default.temporaryDirectory
        let workDir = tempDir.appendingPathComponent("mixed_code_\(UUID().uuidString)")
        
        do {
            try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true, attributes: nil)
            
            // Parse the code to separate Swift and Python parts
            let interpreter = BackdoorInterpreter()
            let executionPlan = try interpreter.prepareMixedCode(code, workingDirectory: workDir)
            
            // Execute the code blocks in sequence
            DispatchQueue.global(qos: .userInitiated).async {
                var overallSuccess = true
                var lastError: Error? = nil
                
                for block in executionPlan.executionBlocks {
                    do {
                        // Execute each block and wait for completion
                        try interpreter.executeBlock(block, outputHandler: { output in
                            DispatchQueue.main.async {
                                outputHandler(output)
                            }
                        })
                    } catch {
                        overallSuccess = false
                        lastError = error
                        DispatchQueue.main.async {
                            outputHandler("Error executing block: \(error.localizedDescription)\n")
                        }
                        break
                    }
                }
                
                // Clean up
                try? FileManager.default.removeItem(at: workDir)
                
                // Return final result
                DispatchQueue.main.async {
                    if overallSuccess {
                        completion(.success(()))
                    } else {
                        completion(.failure(lastError ?? NSError(domain: "LocalTerminalService", code: 100, userInfo: [NSLocalizedDescriptionKey: "Unknown error in mixed code execution"])))
                    }
                }
            }
        } catch {
            logger.log(message: "Failed to set up mixed code execution: \(error.localizedDescription)", type: .error)
            DispatchQueue.main.async {
                outputHandler("Error setting up mixed code execution: \(error.localizedDescription)\n")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Terminal Help
    
    /// Shows help information
    private func showHelp(outputHandler: @escaping (String) -> Void) {
        let helpText = """
        Backdoor Terminal Help
        ======================
        
        Basic Commands:
          clear, cls     Clear the terminal screen
          pwd            Print working directory
          cd <path>      Change directory
          ls             List files in current directory
          help           Show this help information
          language       Show custom programming language help
          
        Custom Language Commands:
          swift: <code>   Execute Swift code
          python: <code>  Execute Python code
          #!/bin/backdoor Execute mixed code with Swift and Python
          
        Example:
          swift: print("Hello from Swift!")
          python: print("Hello from Python!")
          
        For more information on the custom programming language, type 'language'
        
        """
        
        outputHandler(helpText)
    }
    
    /// Shows help information about the custom programming language
    private func showLanguageHelp(outputHandler: @escaping (String) -> Void) {
        let helpText = """
        Backdoor Custom Programming Language
        ===================================
        
        The custom language supports both Swift and Python execution with 
        seamless interoperability between them.
        
        Single Language Execution:
        --------------------------
        
        1. Swift Execution:
          swift: print("Hello from Swift!")
          
        2. Python Execution:
          python: print("Hello from Python")
          
        Mixed Language Execution:
        ------------------------
        
        Use the shebang directive to start mixed code:
        
        #!/bin/backdoor
        
        # Swift code block
        swift: {
            let message = "Hello from Swift!"
            print(message)
            // Export variables for Python
            export message
        }
        
        # Python code block
        python: {
            # Import variables from Swift
            from swift import message
            print(f"Swift said: {message}")
            
            # Export variables for Swift
            response = "Hello from Python!"
            export response
        }
        
        # Back to Swift
        swift: {
            // Import variables from Python
            import python.response
            print("Python said: \\(response)")
        }
        
        Data Passing:
        ------------
        
        Use 'export' keyword to make variables available to the other language.
        Use 'import' to access variables from the other language.
        
        Example:
        
        swift: {
            let data = [1, 2, 3, 4, 5]
            export data
        }
        
        python: {
            from swift import data
            sum_value = sum(data)
            print(f"Sum: {sum_value}")
            export sum_value
        }
        
        swift: {
            import python.sum_value
            print("Sum calculated in Python: \\(sum_value)")
        }
        
        """
        
        outputHandler(helpText)
    }
}

// MARK: - Custom Language Structures

/// Custom language parser for the Backdoor programming language
class CustomLanguageParser {
    enum LanguageMode {
        case swift
        case python
        case mixed
    }
    
    struct ParsedCommand {
        let mode: LanguageMode
        let code: String
    }
    
    /// Parse a command to determine its language mode and extract the code
    func parse(_ command: String) -> Result<ParsedCommand, Error> {
        // Check for shebang
        if command.hasPrefix("#!/bin/backdoor") {
            return .success(ParsedCommand(mode: .mixed, code: command))
        }
        
        // Check for swift: prefix
        if command.hasPrefix("swift:") {
            let codeStartIndex = command.index(command.startIndex, offsetBy: 6)
            let swiftCode = String(command[codeStartIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(ParsedCommand(mode: .swift, code: swiftCode))
        }
        
        // Check for python: prefix
        if command.hasPrefix("python:") {
            let codeStartIndex = command.index(command.startIndex, offsetBy: 7)
            let pythonCode = String(command[codeStartIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(ParsedCommand(mode: .python, code: pythonCode))
        }
        
        // Default to treating as shell command which is handled elsewhere
        return .failure(NSError(domain: "CustomLanguageParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not a custom language command"]))
    }
}

/// BackdoorInterpreter - Executes code in the custom programming language
class BackdoorInterpreter {
    enum BlockType {
        case swift
        case python
    }
    
    struct CodeBlock {
        let type: BlockType
        let code: String
        let outputFile: URL
        let importVariables: [String]
    }
    
    struct ExecutionPlan {
        let executionBlocks: [CodeBlock]
        let dataPassingFiles: [URL]
    }
    
    /// Prepare mixed code for execution by parsing and creating execution blocks
    func prepareMixedCode(_ code: String, workingDirectory: URL) throws -> ExecutionPlan {
        // Split code into language blocks
        var executionBlocks: [CodeBlock] = []
        var dataPassingFiles: [URL] = []
        
        // Create a regular expression to match language blocks
        let blockPattern = try NSRegularExpression(pattern: "(swift|python):\\s*\\{([\\s\\S]*?)\\}", options: [])
        let matches = blockPattern.matches(in: code, options: [], range: NSRange(code.startIndex..., in: code))
        
        for match in matches {
            guard let typeRange = Range(match.range(at: 1), in: code),
                  let codeRange = Range(match.range(at: 2), in: code) else {
                continue
            }
            
            let blockType = String(code[typeRange])
            let blockCode = String(code[codeRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Determine block type
            let type: BlockType = blockType == "swift" ? .swift : .python
            
            // Extract import statements
            var importVariables: [String] = []
            let importPattern: NSRegularExpression
            
            if type == .swift {
                importPattern = try NSRegularExpression(pattern: "import\\s+python\\.(\\w+)", options: [])
            } else {
                importPattern = try NSRegularExpression(pattern: "from\\s+swift\\s+import\\s+(\\w+)", options: [])
            }
            
            let importMatches = importPattern.matches(in: blockCode, options: [], range: NSRange(blockCode.startIndex..., in: blockCode))
            
            for importMatch in importMatches {
                if let variableRange = Range(importMatch.range(at: 1), in: blockCode) {
                    let variable = String(blockCode[variableRange])
                    importVariables.append(variable)
                }
            }
            
            // Create output file
            let outputFile = workingDirectory.appendingPathComponent("output_\(UUID().uuidString).json")
            dataPassingFiles.append(outputFile)
            
            // Create code block
            let codeBlock = CodeBlock(
                type: type,
                code: blockCode,
                outputFile: outputFile,
                importVariables: importVariables
            )
            
            executionBlocks.append(codeBlock)
        }
        
        return ExecutionPlan(executionBlocks: executionBlocks, dataPassingFiles: dataPassingFiles)
    }
    
    /// Execute a single code block and handle data passing
    func executeBlock(_ block: CodeBlock, outputHandler: @escaping (String) -> Void) throws {
        // Create modified code with data passing logic
        let modifiedCode = try createExecutableCode(for: block)
        
        // Create a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let fileExtension = block.type == .swift ? "swift" : "py"
        let fileURL = tempDir.appendingPathComponent("temp_\(UUID().uuidString).\(fileExtension)")
        
        try modifiedCode.write(to: fileURL, atomically: true, encoding: .utf8)
        
        // Execute the code
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        
        if block.type == .swift {
            process.arguments = ["swift", fileURL.path]
        } else {
            process.arguments = ["python3", fileURL.path]
        }
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Handle output
        outputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                outputHandler(output)
            }
        }
        
        // Handle errors
        errorPipe.fileHandleForReading.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                outputHandler(output)
            }
        }
        
        // Run process
        try process.run()
        process.waitUntilExit()
        
        // Clean up
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        
        // Check exit status
        if process.terminationStatus != 0 {
            throw NSError(
                domain: "BackdoorInterpreter",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Process exited with non-zero status: \(process.terminationStatus)"]
            )
        }
        
        // Delete the temporary file
        try FileManager.default.removeItem(at: fileURL)
    }
    
    /// Create executable code for a block, including data passing logic
    private func createExecutableCode(for block: CodeBlock) throws -> String {
        var code = ""
        
        if block.type == .swift {
            // Add Swift imports and setup
            code += """
            import Foundation
            
            // Data passing setup
            struct ExportedData: Codable {
                var variables: [String: String] = [:]
            }
            
            var exportedData = ExportedData()
            
            // Export function
            func export(_ name: String, _ value: Any) {
                let jsonString = String(describing: value)
                exportedData.variables[name] = jsonString
            }
            
            """
            
            // Add import logic for variables from Python
            for variable in block.importVariables {
                code += """
                
                // Import \(variable) from Python
                let python_\(variable): Any
                do {
                    let importData = try Data(contentsOf: URL(fileURLWithPath: "\(block.outputFile.path)"))
                    let importJSON = try JSONSerialization.jsonObject(with: importData) as? [String: Any]
                    python_\(variable) = importJSON?["\(variable)"] ?? ""
                } catch {
                    print("Error importing \(variable) from Python: \\(error)")
                    let python_\(variable) = ""
                }
                
                """
            }
            
            // Add user code
            code += """
            
            // User code
            \(block.code)
            
            // Save exported data
            if !exportedData.variables.isEmpty {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: exportedData.variables)
                    try jsonData.write(to: URL(fileURLWithPath: "\(block.outputFile.path)"))
                } catch {
                    print("Error exporting data: \\(error)")
                }
            }
            """
            
        } else {
            // Add Python imports and setup
            code += """
            import json
            import os
            
            # Data passing setup
            exported_data = {}
            
            # Export function
            def export(name, value):
                exported_data[name] = value
            
            """
            
            // Add import logic for variables from Swift
            for variable in block.importVariables {
                code += """
                
                # Import \(variable) from Swift
                try:
                    with open("\(block.outputFile.path)", "r") as f:
                        import_data = json.load(f)
                        \(variable) = import_data.get("\(variable)", "")
                except Exception as e:
                    print(f"Error importing \(variable) from Swift: {e}")
                    \(variable) = ""
                
                """
            }
            
            // Add user code
            code += """
            
            # User code
            \(block.code)
            
            # Save exported data
            if exported_data:
                try:
                    with open("\(block.outputFile.path)", "w") as f:
                        json.dump(exported_data, f)
                except Exception as e:
                    print(f"Error exporting data: {e}")
            """
        }
        
        return code
    }
}
