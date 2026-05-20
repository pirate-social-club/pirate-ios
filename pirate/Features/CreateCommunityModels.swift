import SwiftUI

enum CreateCommunityStep: Int, CaseIterable {
    case basics = 1
    case access = 2
    case review = 3

    var title: String {
        switch self {
        case .basics: return "Create community"
        case .access: return "Community settings"
        case .review: return "Preview"
        }
    }

    var next: CreateCommunityStep? {
        switch self {
        case .basics: return .access
        case .access: return .review
        case .review: return nil
        }
    }

    var previous: CreateCommunityStep? {
        switch self {
        case .basics: return nil
        case .access: return .basics
        case .review: return .access
        }
    }
}

enum CreateCommunityMembershipMode: String, CaseIterable, Identifiable {
    case gated
    case request

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gated: return "Automatic after passing gates"
        case .request: return "Approval required"
        }
    }

    var detail: String {
        switch self {
        case .gated:
            return "People can join immediately after passing at least one wallet, identity, or ownership gate."
        case .request:
            return "People request access and moderators approve them."
        }
    }

    var reviewLabel: String {
        switch self {
        case .gated: return "Automatic after passing gates"
        case .request: return "Approval required"
        }
    }
}

enum CreateCommunityGateMatchMode: String, CaseIterable, Identifiable {
    case all
    case any

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All selected gates"
        case .any: return "Any selected gate"
        }
    }

    var detail: String {
        switch self {
        case .all: return "Members must pass every selected gate."
        case .any: return "Members can pass any one selected gate."
        }
    }
}

enum CreateCommunityDatabaseRegion: String, CaseIterable, Identifiable {
    case usEast = "aws-us-east-1"
    case usCentral = "aws-us-east-2"
    case usWest = "aws-us-west-2"
    case europe = "aws-eu-west-1"
    case india = "aws-ap-south-1"
    case japan = "aws-ap-northeast-1"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .usEast: return "🇺🇸 US East"
        case .usCentral: return "🇺🇸 US Central"
        case .usWest: return "🇺🇸 US West"
        case .europe: return "🇮🇪 Ireland (EU)"
        case .india: return "🇮🇳 India"
        case .japan: return "🇯🇵 Japan"
        }
    }
}

enum CreateCommunityAgeGatePolicy: String, CaseIterable, Identifiable {
    case none
    case eighteenPlus = "18_plus"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "All ages"
        case .eighteenPlus: return "18+"
        }
    }
}

enum CreateCommunityAnonymousScope: String, CaseIterable, Identifiable {
    case communityStable = "community_stable"
    case threadStable = "thread_stable"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .communityStable: return "Community-stable"
        case .threadStable: return "Thread-stable"
        }
    }

    var detail: String {
        switch self {
        case .communityStable:
            return "One persistent anonymous label per user across the entire community."
        case .threadStable:
            return "One persistent anonymous label per user per thread."
        }
    }
}

enum CreateCommunityGateType: String, CaseIterable, Identifiable {
    case altchaPow = "altcha_pow"
    case uniqueHuman = "unique_human"
    case nationality
    case minimumAge = "minimum_age"
    case gender
    case walletScore = "wallet_score"
    case erc721Holding = "erc721_holding"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .altchaPow: return "Proof-of-work check"
        case .uniqueHuman: return "Palm scan (Very)"
        case .nationality: return "Nationality verification (Self.xyz)"
        case .minimumAge: return "Minimum age (Self.xyz)"
        case .gender: return "Document sex marker (verified ID)"
        case .walletScore: return "Passport score threshold"
        case .erc721Holding: return "Ethereum NFT collection (ERC-721)"
        }
    }

    var section: String {
        switch self {
        case .altchaPow, .uniqueHuman, .nationality, .minimumAge, .gender:
            return "Identity gates"
        case .walletScore, .erc721Holding:
            return "Wallet gates"
        }
    }

    static let reviewOrder: [CreateCommunityGateType] = [
        .altchaPow,
        .uniqueHuman,
        .nationality,
        .minimumAge,
        .gender,
        .walletScore,
        .erc721Holding
    ]

    static let powExclusiveTypes: Set<CreateCommunityGateType> = [
        .uniqueHuman,
        .nationality,
        .minimumAge,
        .gender,
        .walletScore
    ]
}

enum CreateCommunityGenderMarker: String, CaseIterable, Identifiable {
    case female = "F"
    case male = "M"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .female: return "F marker"
        case .male: return "M marker"
        }
    }
}

enum CreateCommunityMediaTarget {
    case avatar
    case banner

    var uploadKind: String {
        switch self {
        case .avatar: return "avatar"
        case .banner: return "banner"
        }
    }
}

