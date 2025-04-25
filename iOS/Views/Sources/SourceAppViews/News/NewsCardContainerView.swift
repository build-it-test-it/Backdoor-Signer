import SwiftUI

// MARK: - NewsCardContainerView

struct NewsCardContainerView: View {
    // MARK: - Properties

    @Binding var isSheetPresented: Bool
    var news: NewsData
    @Namespace private var namespace

    let uuid = UUID().uuidString

    // MARK: - Body

    var body: some View {
        Button(action: {
            isSheetPresented = true
        }) {
            NewsCardView(news: news)
                .fullScreenCover(
                    isPresented: $isSheetPresented
                ) {
                    CardContextMenuView(news: news)
                        .compatNavigationTransition(
                            id: uuid,
                            ns: namespace
                        )
                }
                .compatMatchedTransitionSource(
                    id: uuid,
                    ns: namespace
                )
                .compactContentMenuPreview(news: news)
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Adds a context menu preview specifically for news items
    /// with URL opening capabilities when available
    func compactContentMenuPreview(news: NewsData) -> some View {
        if #available(iOS 16.0, *) {
            return self.contextMenu {
                if let newsURL = news.url {
                    Button(action: {
                        UIApplication.shared.open(newsURL)
                    }) {
                        Label("Open URL", systemImage: "arrow.up.right")
                    }
                }
            }
        } else {
            return self
        }
    }
}
