import Foundation

struct UpdateRelease: Equatable {
    let tagName: String
    let version: String
    let pageURL: URL
    let assetURL: URL?
}

enum UpdateCheckResult: Equatable {
    case available(UpdateRelease)
    case upToDate(version: String)
    case failed(String)
}

@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var isChecking = false
    @Published private(set) var lastResult: UpdateCheckResult?

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    func checkForUpdates() async -> UpdateCheckResult {
        guard !isChecking else {
            return lastResult ?? .upToDate(version: currentVersion)
        }

        isChecking = true
        defer { isChecking = false }

        do {
            let latestRelease = try await fetchLatestRelease()
            let result: UpdateCheckResult

            if Self.compareVersions(latestRelease.version, currentVersion) == .orderedDescending {
                result = .available(latestRelease)
            } else {
                result = .upToDate(version: currentVersion)
            }

            lastResult = result
            return result
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            let result = UpdateCheckResult.failed(message)
            lastResult = result
            return result
        }
    }

    private func fetchLatestRelease() async throws -> UpdateRelease {
        guard let url = URL(string: "https://api.github.com/repos/\(AppConstants.githubOwner)/\(AppConstants.githubRepository)/releases/latest") else {
            throw UpdateCheckError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("MacVerce/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateCheckError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw UpdateCheckError.githubStatus(httpResponse.statusCode)
        }

        let dto = try JSONDecoder().decode(GitHubReleaseDTO.self, from: data)

        guard let pageURL = URL(string: dto.htmlURL) else {
            throw UpdateCheckError.invalidResponse
        }

        let assetURL = dto.assets
            .first { $0.name.hasSuffix(".zip") }
            .flatMap { URL(string: $0.browserDownloadURL) }

        return UpdateRelease(
            tagName: dto.tagName,
            version: Self.normalizedVersionString(dto.tagName),
            pageURL: pageURL,
            assetURL: assetURL
        )
    }

    private static func normalizedVersionString(_ rawVersion: String) -> String {
        rawVersion.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = versionComponents(lhs)
        let right = versionComponents(rhs)
        let count = max(left.count, right.count)

        for index in 0..<count {
            let leftValue = index < left.count ? left[index] : 0
            let rightValue = index < right.count ? right[index] : 0

            if leftValue > rightValue {
                return .orderedDescending
            }

            if leftValue < rightValue {
                return .orderedAscending
            }
        }

        return .orderedSame
    }

    private static func versionComponents(_ version: String) -> [Int] {
        normalizedVersionString(version)
            .split { !$0.isNumber }
            .map { Int($0) ?? 0 }
    }
}

private enum UpdateCheckError: LocalizedError {
    case invalidURL
    case invalidResponse
    case githubStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The update URL is invalid."
        case .invalidResponse:
            "GitHub returned an invalid update response."
        case let .githubStatus(statusCode):
            "GitHub update check failed with status \(statusCode)."
        }
    }
}

private struct GitHubReleaseDTO: Decodable {
    let tagName: String
    let htmlURL: String
    let assets: [ReleaseAssetDTO]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}

private struct ReleaseAssetDTO: Decodable {
    let name: String
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}
