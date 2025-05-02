import Foundation

extension Installer {
    var pongEndpoint: URL {
        var comps = URLComponents()
        comps.scheme = Preferences.userSelectedServer ? "http" : "https"
        comps.host = Self.sni
        comps.path = "/ping"
        comps.port = port
        guard let url = comps.url else {
            Debug.shared.log(message: "Failed to create pongEndpoint URL", type: .error)
            // Return a fallback URL to prevent crashes
            return URL(string: "https://localhost/ping") ?? URL(fileURLWithPath: "/")
        }
        return url
    }

    var plistEndpoint: URL {
        var comps = URLComponents()
        comps.scheme = Preferences.userSelectedServer ? "http" : "https"
        comps.host = Self.sni
        comps.path = "/\(id).plist"
        comps.port = port
        guard let url = comps.url else {
            Debug.shared.log(message: "Failed to create plistEndpoint URL", type: .error)
            // Return a fallback URL to prevent crashes
            return URL(string: "https://localhost/fallback.plist") ?? URL(fileURLWithPath: "/")
        }
        return url
    }

    var payloadEndpoint: URL {
        var comps = URLComponents()
        comps.scheme = Preferences.userSelectedServer ? "http" : "https"
        comps.host = Self.sni
        comps.path = "/\(id).ipa"
        comps.port = port
        guard let url = comps.url else {
            Debug.shared.log(message: "Failed to create payloadEndpoint URL", type: .error)
            // Return a fallback URL to prevent crashes
            return URL(string: "https://localhost/fallback.ipa") ?? URL(fileURLWithPath: "/")
        }
        return url
    }

    var pageEndpoint: URL {
        var comps = URLComponents()
        comps.scheme = Preferences.userSelectedServer ? "http" : "https"
        comps.host = Self.sni
        comps.path = "/i"
        comps.port = port
        guard let url = comps.url else {
            Debug.shared.log(message: "Failed to create pageEndpoint URL", type: .error)
            // Return a fallback URL to prevent crashes
            return URL(string: "https://localhost/i") ?? URL(fileURLWithPath: "/")
        }
        return url
    }

    var iTunesLink: URL {
        var comps = URLComponents()
        comps.scheme = "itms-services"
        comps.path = "/"
        comps.queryItems = [
            URLQueryItem(name: "action", value: "download-manifest"),
            URLQueryItem(name: "url", value: plistEndpoint.absoluteString),
        ]
        comps.port = port
        guard let url = comps.url else {
            Debug.shared.log(message: "Failed to create iTunesLink URL", type: .error)
            // Return a fallback URL to prevent crashes
            return URL(string: "itms-services://?action=download-manifest&url=https://localhost/fallback.plist") ?? URL(fileURLWithPath: "/")
        }
        return url
    }

    var displayImageSmallEndpoint: URL {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = Self.sni
        comps.path = "/app57x57.png"
        comps.port = port
        guard let url = comps.url else {
            Debug.shared.log(message: "Failed to create displayImageSmallEndpoint URL", type: .error)
            // Return a fallback URL to prevent crashes
            return URL(string: "https://localhost/app57x57.png") ?? URL(fileURLWithPath: "/")
        }
        return url
    }

    var displayImageSmallData: Data {
        createWhite(57)
    }

    var displayImageLargeEndpoint: URL {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = Self.sni
        comps.path = "/app512x512.png"
        comps.port = port
        guard let url = comps.url else {
            Debug.shared.log(message: "Failed to create displayImageLargeEndpoint URL", type: .error)
            // Return a fallback URL to prevent crashes
            return URL(string: "https://localhost/app512x512.png") ?? URL(fileURLWithPath: "/")
        }
        return url
    }

    var displayImageLargeData: Data {
        createWhite(512)
    }

    func createWhite(_ r: CGFloat) -> Data {
        let renderer = UIGraphicsImageRenderer(size: .init(width: r, height: r))
        let image = renderer.image { ctx in
            Preferences.appTintColor.uiColor.setFill()
            ctx.fill(.init(x: 0, y: 0, width: r, height: r))
        }
        guard let pngData = image.pngData() else {
            Debug.shared.log(message: "Failed to create PNG data for image", type: .error)
            // Return empty data to prevent crashes
            return Data()
        }
        return pngData
    }

    var indexHtml: String {
        """
        <html> <head> <meta http-equiv="refresh" content="0;url=\(iTunesLink.absoluteString)"> </head> </html>
        """
    }

    var installManifest: [String: Any] {
        [
            "items": [
                [
                    "assets": [
                        [
                            "kind": "software-package",
                            "url": payloadEndpoint.absoluteString,
                        ],
                        [
                            "kind": "display-image",
                            "url": displayImageSmallEndpoint.absoluteString,
                        ],
                        [
                            "kind": "full-size-image",
                            "url": displayImageLargeEndpoint.absoluteString,
                        ],
                    ],
                    "metadata": [
                        "bundle-identifier": metadata.id,
                        "bundle-version": metadata.version,
                        "kind": "software",
                        "title": metadata.name,
                    ],
                ],
            ],
        ]
    }

    var installManifestData: Data {
        (try? PropertyListSerialization.data(
            fromPropertyList: installManifest,
            format: .xml,
            options: .zero
        )) ?? .init()
    }
}
