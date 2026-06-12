import AppKit
import SwiftUI

struct DashboardView: View {
    private enum Metrics {
        static let width: CGFloat = 420
        static let height: CGFloat = 540
        static let cornerRadius: CGFloat = 26
        static let rowHeight: CGFloat = 66
        static let iconColumnWidth: CGFloat = 46
    }

    @ObservedObject var settings: AppSettings
    @ObservedObject var monitor: DeploymentMonitor

    let refresh: () -> Void
    let openSettings: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: 76)

            PanelDivider()

            content

            PanelDivider()

            footer
                .frame(height: 58)
        }
        .frame(width: Metrics.width, height: Metrics.height)
        .background(
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .fill(PanelTheme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                        .stroke(PanelTheme.border, lineWidth: 1.3)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 18) {
            Image(systemName: statusSymbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(nsColor: monitor.menuBarColor))
                .frame(width: Metrics.iconColumnWidth)

            VStack(alignment: .leading, spacing: 2) {
                Text("Vercel")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PanelTheme.primaryText)
                Text(headerSubtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PanelTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            PanelPillButton(systemName: "arrow.clockwise", help: "Refresh", action: refresh)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var content: some View {
        if !settings.snapshot().hasToken {
            VStack(spacing: 0) {
                PanelRowView(
                    systemName: "key.fill",
                    title: "Vercel Token",
                    subtitle: "Not configured",
                    actionSystemName: "gearshape",
                    actionTint: PanelTheme.accent,
                    action: openSettings
                )

                PanelDivider()
                    .padding(.leading, Metrics.iconColumnWidth + 20)

                PanelRowView(
                    systemName: "arrow.clockwise",
                    title: "Deployments",
                    subtitle: "Waiting for credentials",
                    actionSystemName: "pause.fill",
                    actionTint: PanelTheme.disabledControl,
                    action: nil
                )

                Spacer(minLength: 0)
            }
        } else if monitor.deployments.isEmpty {
            VStack(spacing: 0) {
                PanelRowView(
                    systemName: "shippingbox",
                    title: "Deployments",
                    subtitle: emptyDeploymentsSubtitle,
                    actionSystemName: "arrow.clockwise",
                    actionTint: PanelTheme.accent,
                    action: refresh
                )

                Spacer(minLength: 0)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(monitor.deployments) { deployment in
                        DeploymentRowView(deployment: deployment)

                        if deployment.id != monitor.deployments.last?.id {
                            PanelDivider()
                                .padding(.leading, Metrics.iconColumnWidth + 20)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            FooterIconButton(systemName: "gearshape", help: "Settings", action: openSettings)

            Spacer()

            Button(action: openSettings) {
                Text("Configure")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PanelTheme.primaryText)
                    .frame(width: 120, height: 30)
                    .background(
                        Capsule()
                            .fill(PanelTheme.footerButton)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            FooterIconButton(systemName: "power", help: "Quit", action: quit)
        }
        .padding(.horizontal, 20)
    }

    private var statusSymbolName: String {
        switch monitor.status {
        case .needsConfiguration:
            "key.fill"
        case .refreshing:
            "arrow.triangle.2.circlepath"
        case .failed:
            "exclamationmark.triangle.fill"
        case .idle:
            monitor.deployments.first?.state.symbolName ?? "shippingbox"
        }
    }

    private var emptyDeploymentsSubtitle: String {
        switch monitor.status {
        case let .failed(message):
            message
        case .refreshing:
            "Refreshing"
        default:
            "No active deployments"
        }
    }

    private var headerSubtitle: String {
        if let lastRefresh = monitor.lastRefresh {
            return "Updated \(relativeTime(for: lastRefresh))"
        }

        switch monitor.status {
        case .needsConfiguration:
            return "Not configured"
        case .refreshing:
            return "Refreshing"
        case let .failed(message):
            return message
        case .idle:
            return "Watching deployments"
        }
    }

    private func relativeTime(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct DeploymentRowView: View {
    let deployment: VercelDeployment

    var body: some View {
        PanelRowView(
            systemName: deployment.state.symbolName,
            title: deployment.name,
            subtitle: subtitle,
            actionSystemName: deployment.publicURL == nil ? "ellipsis" : "arrow.up.right",
            actionTint: actionTint,
            action: openAction
        )
    }

    private var subtitle: String {
        let scope = deployment.scopeName
        let target = deployment.target?.uppercased()
        let age = relativeTime(for: deployment.createdAt)
        let url = deployment.url ?? deployment.state.title

        return [scope, target, age, url]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var actionTint: Color {
        switch deployment.state {
        case .ready:
            PanelTheme.accent
        case .building, .initializing, .queued:
            Color(nsColor: .systemYellow)
        case .error:
            Color(nsColor: .systemRed)
        case .canceled, .unknown:
            PanelTheme.disabledControl
        }
    }

    private var openAction: (() -> Void)? {
        guard deployment.publicURL != nil else { return nil }
        return { openDeployment() }
    }

    private func openDeployment() {
        if let url = deployment.publicURL {
            NSWorkspace.shared.open(url)
        }
    }

    private func relativeTime(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct PanelRowView: View {
    let systemName: String
    let title: String
    let subtitle: String
    let actionSystemName: String
    let actionTint: Color
    let action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 18) {
                Image(systemName: systemName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PanelTheme.icon)
                    .frame(width: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(PanelTheme.primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PanelTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 10)

                PanelPillButton(
                    systemName: actionSystemName,
                    help: title,
                    tint: action == nil ? PanelTheme.disabledControl : actionTint,
                    action: action ?? {}
                )
                .allowsHitTesting(action != nil)
            }
            .frame(height: 66)
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PanelPillButton: View {
    let systemName: String
    let help: String
    var tint: Color = PanelTheme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 30)
                .background(
                    Capsule()
                        .fill(tint)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct FooterIconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PanelTheme.secondaryText)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct PanelDivider: View {
    var body: some View {
        Rectangle()
            .fill(PanelTheme.divider)
            .frame(height: 1)
    }
}

private enum PanelTheme {
    static let background = Color(red: 0.13, green: 0.12, blue: 0.15)
    static let border = Color.white.opacity(0.18)
    static let divider = Color.white.opacity(0.1)
    static let primaryText = Color.white.opacity(0.88)
    static let secondaryText = Color.white.opacity(0.56)
    static let icon = Color.white.opacity(0.82)
    static let accent = Color(red: 0.21, green: 0.48, blue: 0.94)
    static let disabledControl = Color.white.opacity(0.24)
    static let footerButton = Color.white.opacity(0.12)
}
