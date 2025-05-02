extension UINavigationController {
    func shouldPresentFullScreen() {
        if UIDevice.current.userInterfaceIdiom == .pad {
            modalPresentationStyle = .formSheet
        } else {
            modalPresentationStyle = .fullScreen
        }
    }
}
