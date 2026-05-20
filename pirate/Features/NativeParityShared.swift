import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct SubmitCommunityOption: Identifiable {
    let id: String
    let displayName: String
    let routeSlug: String?
    let avatarRef: String?

    var routeLabel: String {
        communityPresentationLabel(
            communityId: id,
            displayName: displayName,
            routeSlug: routeSlug,
            routeSlugImpliesVerified: true
        )
    }

    var routeIsUnverified: Bool {
        !isCommunityRouteVerified(routeSlug: routeSlug, routeSlugImpliesVerified: true)
    }
}

struct ComposerPickedFile: Identifiable {
    let id = UUID()
    let name: String
    let mimeType: String
    let data: Data
    let sizeBytes: Int
}

func makeImage(from data: Data) -> Image? {
    #if os(iOS)
    guard let image = UIImage(data: data) else { return nil }
    return Image(uiImage: image)
    #elseif os(macOS)
    guard let image = NSImage(data: data) else { return nil }
    return Image(nsImage: image)
    #else
    return nil
    #endif
}

