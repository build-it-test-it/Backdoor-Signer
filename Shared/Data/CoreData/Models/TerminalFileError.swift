import Foundation

/// File operation errors specific to terminal file operations
enum TerminalFileError: Error {
    case invalidURL
    case noData
    case invalidResponse
    case apiError(String)
    case sessionError(String)
    case parseError(String)
    case fileNotFound(String)
    case unknownError(String)
    case failure(String)

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL for file operation"
        case .noData:
            return "No data received during file operation"
        case .invalidResponse:
            return "Invalid response format from file server"
        case let .apiError(message):
            return "API Error: \(message)"
        case let .sessionError(message):
            return "Session Error: \(message)"
        case let .parseError(message):
            return "Parse Error: \(message)"
        case let .fileNotFound(message):
            return "File not found: \(message)"
        case let .unknownError(message):
            return "Unknown error: \(message)"
        case let .failure(message):
            return "Operation failed: \(message)"
        }
    }
}
