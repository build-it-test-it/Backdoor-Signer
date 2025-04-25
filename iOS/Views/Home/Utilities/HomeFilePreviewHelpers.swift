import QuickLook
import UIKit

// Important helper functions for file previews
extension HomeViewController {
    /// Present a preview for a file
    /// - Parameter file: The file to preview
    func presentFilePreview(for file: File) {
        // Check if the file exists
        guard FileManager.default.fileExists(atPath: file.url.path) else {
            utilities.handleError(
                in: self,
                error: FileAppError.fileNotFound(file.name),
                withTitle: "File Not Found"
            )
            return
        }

        // Use the preview controller
        let previewController = FilePreviewController(fileURL: file.url)
        navigationController?.pushViewController(previewController, animated: true)
    }

    /// Present an image preview
    /// - Parameter file: The image file to preview
    func presentImagePreview(for file: File) {
        presentFilePreview(for: file)
    }
}
