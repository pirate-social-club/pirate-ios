import SwiftUI
import UniformTypeIdentifiers

enum ComposerFileImportKind {
    case image
    case video
    case audio
    case songCover
    case liveCover

    var contentTypes: [UTType] {
        switch self {
        case .image, .songCover, .liveCover:
            return [.image]
        case .video:
            return [.movie]
        case .audio:
            return [.audio]
        }
    }

    var fallbackMimeType: String {
        switch self {
        case .image, .songCover, .liveCover:
            return "image/jpeg"
        case .video:
            return "video/mp4"
        case .audio:
            return "audio/mpeg"
        }
    }
}

enum ComposerPostType: String, CaseIterable, Identifiable {
    case text
    case link
    case image
    case video
    case song
    case live

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text: return "Text"
        case .link: return "Link"
        case .image: return "Image"
        case .video: return "Video"
        case .song: return "Music"
        case .live: return "Live"
        }
    }

    var icon: String {
        switch self {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .image: return "photo"
        case .video: return "video"
        case .song: return "music.note"
        case .live: return "antenna.radiowaves.left.and.right"
        }
    }

    var isNativeSubmitEnabled: Bool {
        self == .text || self == .link || self == .image
    }

    var hasDetailsStep: Bool {
        self == .video || self == .song
    }

    var bodyLabel: String {
        switch self {
        case .link:
            return "Comment"
        case .image, .video, .song:
            return "Caption"
        case .live:
            return "Description"
        case .text:
            return "Body"
        }
    }

    var bodyPlaceholder: String {
        switch self {
        case .text:
            return "Body text (optional)"
        case .link:
            return "Add context (optional)"
        case .image, .video, .song:
            return "Caption (optional)"
        case .live:
            return "Describe the live room"
        }
    }

    var titlePlaceholder: String {
        switch self {
        case .link:
            return "Title (optional)"
        case .song:
            return "Post title"
        case .live:
            return "Live room title"
        default:
            return "Title"
        }
    }

    var fileImportKind: ComposerFileImportKind? {
        switch self {
        case .image:
            return .image
        case .video:
            return .video
        case .song:
            return .audio
        case .text, .link, .live:
            return nil
        }
    }

    var fileButtonLabel: String {
        switch self {
        case .image:
            return "Choose image"
        case .video:
            return "Choose video"
        case .song:
            return "Choose audio"
        default:
            return "Choose file"
        }
    }
}

enum PostComposerStep: Int, CaseIterable {
    case write
    case details
    case settings
    case preview

    func next(for postType: ComposerPostType) -> PostComposerStep {
        switch self {
        case .write:
            return postType.hasDetailsStep ? .details : .settings
        case .details:
            return .settings
        case .settings:
            return .preview
        case .preview:
            return .preview
        }
    }

    func previous(for postType: ComposerPostType) -> PostComposerStep? {
        switch self {
        case .write:
            return nil
        case .details:
            return .write
        case .settings:
            return postType.hasDetailsStep ? .details : .write
        case .preview:
            return .settings
        }
    }

    var title: String {
        switch self {
        case .write:
            return "Create post"
        case .details:
            return "Post details"
        case .settings:
            return "Post settings"
        case .preview:
            return "Preview post"
        }
    }
}

func isPrivilegedCommunityStatus(_ status: String?) -> Bool {
    status == "owner" || status == "admin" || status == "moderator"
}

func hasCommunityPostingAccess(preview: CommunityPreview, eligibility: JoinEligibility?) -> Bool {
    if eligibility?.status == "already_joined" { return true }
    let status = preview.viewerMembershipStatus
    return status == "member" || isPrivilegedCommunityStatus(status)
}

func hasCommunityMembership(preview: CommunityPreview?, eligibility: JoinEligibility?) -> Bool {
    guard let preview else { return false }
    return hasCommunityPostingAccess(preview: preview, eligibility: eligibility)
}

func containsAltchaGate(_ summaries: [MembershipGateSummary]?) -> Bool {
    (summaries ?? []).contains { $0.gateType == "altcha_pow" }
}

struct PublishedPostDestination: Identifiable, Hashable {
    let id: String
}

