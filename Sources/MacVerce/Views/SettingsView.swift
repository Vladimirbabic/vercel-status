import AppKit
import Combine
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var monitor: DeploymentMonitor

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchAtLoginRequiresApproval = LaunchAtLogin.requiresApproval
    @State private var launchAtLoginError: String?

    private let loginStatusRefresh = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings")
                        .font(.system(size: 22, weight: .semibold))
                    Text(settings.snapshot().hasToken ? "Connected" : "Not configured")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Circle()
                    .fill(Color(nsColor: monitor.menuBarColor))
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 12) {
                SettingsRow(label: "Launch at login") {
                    Toggle("", isOn: launchAtLoginBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                if launchAtLoginRequiresApproval {
                    HStack(alignment: .center, spacing: 12) {
                        Spacer()
                            .frame(width: 110)

                        Text("Approval is pending in Login Items.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button("Open Settings") {
                            LaunchAtLogin.openLoginItemsSettings()
                        }
                    }
                }

                if let launchAtLoginError {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Spacer()
                            .frame(width: 110)

                        Text(launchAtLoginError)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Divider()

                SettingsRow(label: "Vercel token") {
                    SecureField("Token", text: $settings.token)
                        .textFieldStyle(.roundedBorder)
                }

                SettingsRow(label: "Team ID") {
                    TextField("Blank = all teams", text: $settings.teamID)
                        .textFieldStyle(.roundedBorder)
                }

                SettingsRow(label: "Project ID") {
                    TextField("Optional", text: $settings.projectID)
                        .textFieldStyle(.roundedBorder)
                }

                SettingsRow(label: "Poll interval") {
                    HStack(spacing: 12) {
                        Slider(value: $settings.pollIntervalSeconds, in: 15...300, step: 15)
                        Text("\(Int(settings.normalizedPollInterval))s")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .frame(width: 42, alignment: .trailing)
                    }
                }
            }

            Spacer()

            HStack {
                Button {
                    if let url = URL(string: "https://vercel.com/account/tokens") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Tokens", systemImage: "key")
                }

                Spacer()

                Button {
                    monitor.refreshNow()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r")
            }
        }
        .padding(22)
        .frame(width: 520, height: 430)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: refreshLoginItemStatus)
        .onReceive(loginStatusRefresh) { _ in
            refreshLoginItemStatus()
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { newValue in
                do {
                    try LaunchAtLogin.setEnabled(newValue)
                    launchAtLoginError = nil
                } catch {
                    let action = newValue ? "enable" : "disable"
                    launchAtLoginError = "Could not \(action) launch at login: \(error.localizedDescription)"
                }
                refreshLoginItemStatus()
            }
        )
    }

    private func refreshLoginItemStatus() {
        launchAtLogin = LaunchAtLogin.isEnabled
        launchAtLoginRequiresApproval = LaunchAtLogin.requiresApproval
    }
}

private struct SettingsRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .trailing)

            content
                .frame(maxWidth: .infinity)
        }
    }
}
