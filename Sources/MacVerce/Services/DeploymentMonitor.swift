import AppKit
import Foundation

enum MonitorStatus: Equatable {
    case needsConfiguration
    case idle
    case refreshing
    case failed(String)
}

@MainActor
final class DeploymentMonitor: ObservableObject {
    @Published private(set) var deployments: [VercelDeployment] = []
    @Published private(set) var status: MonitorStatus = .needsConfiguration
    @Published private(set) var lastRefresh: Date?

    var onDeploymentSucceeded: ((VercelDeployment) -> Void)?
    var onStateChanged: (() -> Void)?

    private let settings: AppSettings
    private let apiClient = VercelAPIClient()
    private var timer: Timer?
    private var refreshTask: Task<Void, Never>?
    private var knownStatesByDeploymentID: [String: DeploymentState] = [:]
    private var completedInitialLoad = false

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        restartPolling()
    }

    func restartPolling() {
        timer?.invalidate()

        let interval = settings.normalizedPollInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshNow()
            }
        }

        refreshNow()
    }

    func refreshNow() {
        refreshTask?.cancel()

        let configuration = settings.snapshot()
        guard configuration.hasToken else {
            status = .needsConfiguration
            deployments = []
            knownStatesByDeploymentID = [:]
            completedInitialLoad = false
            lastRefresh = nil
            onStateChanged?()
            return
        }

        status = .refreshing
        onStateChanged?()

        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let fetchedDeployments = try await apiClient.listDeploymentsForConfiguredScopes(configuration: configuration)
                guard !Task.isCancelled else { return }
                handleSuccessfulRefresh(fetchedDeployments)
            } catch {
                guard !Task.isCancelled else { return }
                status = .failed(error.localizedDescription)
                onStateChanged?()
            }
        }
    }

    var menuBarColor: NSColor {
        switch status {
        case .needsConfiguration:
            return .secondaryLabelColor
        case .refreshing where deployments.isEmpty:
            return .labelColor
        case .failed:
            return .systemRed
        case .idle, .refreshing:
            break
        }

        if deployments.contains(where: { $0.state == .building || $0.state == .initializing || $0.state == .queued }) {
            return .systemYellow
        }

        guard let latest = deployments.first else {
            return .secondaryLabelColor
        }

        return latest.state.color
    }

    var menuBarToolTip: String {
        switch status {
        case .needsConfiguration:
            "Vibe Check: add a Vercel access token"
        case .refreshing:
            "Vibe Check: refreshing deployments"
        case let .failed(message):
            "Vibe Check: \(message)"
        case .idle:
            if let latest = deployments.first {
                "Vibe Check: \(latest.name) is \(latest.state.title.lowercased())"
            } else {
                "Vibe Check: no deployments"
            }
        }
    }

    var hasActiveDeployment: Bool {
        deployments.contains { deployment in
            deployment.state == .queued ||
            deployment.state == .initializing ||
            deployment.state == .building
        }
    }

    private func handleSuccessfulRefresh(_ fetchedDeployments: [VercelDeployment]) {
        let sortedDeployments = fetchedDeployments
            .filter { $0.state != .canceled }
            .sorted { $0.createdAt > $1.createdAt }
        let newlyReadyDeployments = sortedDeployments.filter { deployment in
            deployment.state == .ready &&
            completedInitialLoad &&
            knownStatesByDeploymentID[deployment.id] != .ready
        }

        deployments = sortedDeployments
        status = .idle
        lastRefresh = Date()

        for deployment in sortedDeployments {
            knownStatesByDeploymentID[deployment.id] = deployment.state
        }

        if !completedInitialLoad {
            completedInitialLoad = true
        }

        onStateChanged?()

        for deployment in newlyReadyDeployments.sorted(by: { $0.createdAt < $1.createdAt }) {
            onDeploymentSucceeded?(deployment)
        }
    }
}
