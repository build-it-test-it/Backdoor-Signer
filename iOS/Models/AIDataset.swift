import Foundation

/// Model representing an AI dataset file
class AIDataset: Equatable {
    let id: String
    var name: String
    let fileName: String
    let format: String
    let size: Int
    let dateAdded: Date
    let recordCount: Int
    let url: URL

    init(
        id: String,
        name: String,
        fileName: String,
        format: String,
        size: Int,
        dateAdded: Date,
        recordCount: Int,
        url: URL
    ) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.format = format
        self.size = size
        self.dateAdded = dateAdded
        self.recordCount = recordCount
        self.url = url
    }

    /// Formatted size string
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    /// Formatted date string
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dateAdded)
    }

    static func == (lhs: AIDataset, rhs: AIDataset) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Model representing dataset information from online sources
struct AIDatasetInfo {
    let name: String
    let description: String
    let url: URL
    let size: Int
    let category: String

    /// Formatted size string
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

/// Errors that can occur during dataset operations
enum AIDatasetError: Error, LocalizedError {
    case invalidFormat(String)
    case invalidData(String)
    case downloadFailed(String)
    case trainingFailed(String)

    var errorDescription: String? {
        switch self {
        case let .invalidFormat(message):
            return "Invalid format: \(message)"
        case let .invalidData(message):
            return "Invalid data: \(message)"
        case let .downloadFailed(message):
            return "Download failed: \(message)"
        case let .trainingFailed(message):
            return "Training failed: \(message)"
        }
    }
}
