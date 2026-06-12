import Foundation

enum VercelAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimited
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid Vercel API URL."
        case .invalidResponse:
            "Vercel returned an invalid response."
        case .unauthorized:
            "Vercel rejected the access token."
        case .rateLimited:
            "Vercel API rate limit reached."
        case let .serverMessage(message):
            message
        }
    }
}

struct VercelAPIClient {
    func listDeploymentsForConfiguredScopes(configuration: VercelConfiguration) async throws -> [VercelDeployment] {
        if !configuration.teamID.isEmpty {
            return try await listDeployments(
                configuration: configuration,
                teamID: configuration.teamID,
                scopeName: nil
            )
        }

        var deployments = try await listDeployments(
            configuration: configuration,
            teamID: nil,
            scopeName: "Personal"
        )
        let teams = try await listTeams(configuration: configuration)

        for team in teams {
            let teamDeployments = try await listDeployments(
                configuration: configuration,
                teamID: team.id,
                scopeName: team.displayName
            )
            deployments.append(contentsOf: teamDeployments)
        }

        return deployments
    }

    func listTeams(configuration: VercelConfiguration) async throws -> [VercelTeam] {
        var teams: [VercelTeam] = []
        var nextCursor: String?

        repeat {
            var components = URLComponents(string: "https://api.vercel.com/v2/teams")
            var queryItems = [
                URLQueryItem(name: "limit", value: "100")
            ]

            if let nextCursor {
                queryItems.append(URLQueryItem(name: "next", value: nextCursor))
            }

            components?.queryItems = queryItems

            guard let url = components?.url else {
                throw VercelAPIError.invalidURL
            }

            let response: ListTeamsResponse = try await send(
                url: url,
                token: configuration.token
            )
            teams.append(contentsOf: response.teams.compactMap(\.team))
            nextCursor = response.pagination?.next
        } while nextCursor != nil

        return teams
    }

    func listDeployments(
        configuration: VercelConfiguration,
        teamID: String? = nil,
        scopeName: String? = nil
    ) async throws -> [VercelDeployment] {
        var components = URLComponents(string: "https://api.vercel.com/v6/deployments")
        var queryItems = [
            URLQueryItem(name: "limit", value: "20")
        ]

        if let teamID, !teamID.isEmpty {
            queryItems.append(URLQueryItem(name: "teamId", value: teamID))
        }

        if !configuration.projectID.isEmpty {
            queryItems.append(URLQueryItem(name: "projectId", value: configuration.projectID))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw VercelAPIError.invalidURL
        }

        let response: ListDeploymentsResponse = try await send(
            url: url,
            token: configuration.token
        )
        return response.deployments.map { $0.deployment.scoped(to: scopeName) }
    }

    private func send<Response: Decodable>(url: URL, token: String) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VercelAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return try JSONDecoder().decode(Response.self, from: data)
        case 401, 403:
            throw VercelAPIError.unauthorized
        case 429:
            throw VercelAPIError.rateLimited
        default:
            if let apiError = try? JSONDecoder().decode(VercelErrorResponse.self, from: data),
               let message = apiError.error.message {
                throw VercelAPIError.serverMessage(message)
            }
            throw VercelAPIError.invalidResponse
        }
    }
}

private struct ListDeploymentsResponse: Decodable {
    let deployments: [DeploymentDTO]
}

private struct ListTeamsResponse: Decodable {
    let teams: [TeamDTO]
    let pagination: PaginationDTO?
}

private struct PaginationDTO: Decodable {
    let next: String?

    enum CodingKeys: String, CodingKey {
        case next
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let stringValue = try? container.decodeIfPresent(String.self, forKey: .next) {
            next = stringValue
        } else if let intValue = try? container.decodeIfPresent(Int.self, forKey: .next) {
            next = String(intValue)
        } else {
            next = nil
        }
    }
}

private struct VercelErrorResponse: Decodable {
    let error: ErrorDTO

    struct ErrorDTO: Decodable {
        let message: String?
    }
}

private struct DeploymentDTO: Decodable {
    let uid: String
    let name: String?
    let url: String?
    let state: String?
    let target: String?
    let created: Int64?
    let createdAt: Int64?
    let creator: CreatorDTO?
    let projectId: String?

    var deployment: VercelDeployment {
        VercelDeployment(
            id: uid,
            name: name ?? "Unnamed deployment",
            url: url,
            state: DeploymentState(apiValue: state),
            target: target,
            createdAt: date(from: createdAt ?? created),
            creator: creator?.displayName,
            projectID: projectId,
            scopeName: nil
        )
    }

    private func date(from rawTimestamp: Int64?) -> Date {
        guard let rawTimestamp else { return Date() }

        if rawTimestamp > 9_999_999_999 {
            return Date(timeIntervalSince1970: TimeInterval(rawTimestamp) / 1000)
        }

        return Date(timeIntervalSince1970: TimeInterval(rawTimestamp))
    }
}

private struct TeamDTO: Decodable {
    let id: String?
    let teamId: String?
    let name: String?
    let slug: String?

    var team: VercelTeam? {
        guard let id = id ?? teamId else {
            return nil
        }

        return VercelTeam(id: id, name: name, slug: slug)
    }
}

private struct CreatorDTO: Decodable {
    let username: String?
    let email: String?
    let name: String?

    var displayName: String? {
        username ?? name ?? email
    }
}
