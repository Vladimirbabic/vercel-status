import AppKit
import Foundation

enum DeploymentState: String, CaseIterable, Sendable {
    case queued
    case building
    case initializing
    case ready
    case error
    case canceled
    case unknown

    init(apiValue: String?) {
        switch apiValue?.uppercased() {
        case "QUEUED":
            self = .queued
        case "BUILDING":
            self = .building
        case "INITIALIZING":
            self = .initializing
        case "READY":
            self = .ready
        case "ERROR":
            self = .error
        case "CANCELED", "CANCELLED":
            self = .canceled
        default:
            self = .unknown
        }
    }

    var title: String {
        switch self {
        case .queued:
            "Queued"
        case .building:
            "Building"
        case .initializing:
            "Initializing"
        case .ready:
            "Ready"
        case .error:
            "Error"
        case .canceled:
            "Canceled"
        case .unknown:
            "Unknown"
        }
    }

    var symbolName: String {
        switch self {
        case .queued:
            "clock"
        case .building, .initializing:
            "hammer.fill"
        case .ready:
            "checkmark.circle.fill"
        case .error:
            "xmark.octagon.fill"
        case .canceled:
            "minus.circle.fill"
        case .unknown:
            "questionmark.circle.fill"
        }
    }

    var color: NSColor {
        switch self {
        case .queued:
            .systemOrange
        case .building, .initializing:
            .systemYellow
        case .ready:
            .systemGreen
        case .error:
            .systemRed
        case .canceled:
            .systemGray
        case .unknown:
            .secondaryLabelColor
        }
    }
}

struct VercelDeployment: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let url: String?
    let state: DeploymentState
    let target: String?
    let createdAt: Date
    let creator: String?
    let projectID: String?
    let scopeName: String?

    var displayURL: String {
        url ?? "Deployment URL pending"
    }

    var publicURL: URL? {
        guard let url, !url.isEmpty else { return nil }
        return URL(string: "https://\(url)")
    }

    func scoped(to scopeName: String?) -> VercelDeployment {
        VercelDeployment(
            id: id,
            name: name,
            url: url,
            state: state,
            target: target,
            createdAt: createdAt,
            creator: creator,
            projectID: projectID,
            scopeName: scopeName
        )
    }
}

struct VercelTeam: Identifiable, Equatable, Sendable {
    let id: String
    let name: String?
    let slug: String?

    var displayName: String {
        name ?? slug ?? id
    }
}
