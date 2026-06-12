import Foundation

struct VercelConfiguration: Equatable, Sendable {
    let token: String
    let teamID: String
    let projectID: String
    let pollIntervalSeconds: TimeInterval

    var hasToken: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let teamID = "teamID"
        static let projectID = "projectID"
        static let pollIntervalSeconds = "pollIntervalSeconds"
    }

    private let defaults = UserDefaults.standard

    var onPollingPreferencesChanged: (() -> Void)?

    @Published var token: String {
        didSet {
            guard token != oldValue else { return }
            KeychainStore.saveToken(token)
            onPollingPreferencesChanged?()
        }
    }

    @Published var teamID: String {
        didSet {
            guard teamID != oldValue else { return }
            defaults.set(teamID.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.teamID)
            onPollingPreferencesChanged?()
        }
    }

    @Published var projectID: String {
        didSet {
            guard projectID != oldValue else { return }
            defaults.set(projectID.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.projectID)
            onPollingPreferencesChanged?()
        }
    }

    @Published var pollIntervalSeconds: Double {
        didSet {
            guard pollIntervalSeconds != oldValue else { return }
            defaults.set(pollIntervalSeconds, forKey: Keys.pollIntervalSeconds)
            onPollingPreferencesChanged?()
        }
    }

    init() {
        token = KeychainStore.loadToken()
        teamID = defaults.string(forKey: Keys.teamID) ?? ""
        projectID = defaults.string(forKey: Keys.projectID) ?? ""

        let storedInterval = defaults.double(forKey: Keys.pollIntervalSeconds)
        pollIntervalSeconds = storedInterval > 0 ? storedInterval : 30
    }

    var normalizedPollInterval: TimeInterval {
        max(15, min(600, pollIntervalSeconds))
    }

    func snapshot() -> VercelConfiguration {
        VercelConfiguration(
            token: token.trimmingCharacters(in: .whitespacesAndNewlines),
            teamID: teamID.trimmingCharacters(in: .whitespacesAndNewlines),
            projectID: projectID.trimmingCharacters(in: .whitespacesAndNewlines),
            pollIntervalSeconds: normalizedPollInterval
        )
    }
}

