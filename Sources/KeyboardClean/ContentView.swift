import SwiftUI
import Combine
import AppKit

struct ContentView: View {

    @ObservedObject var cleaner: KeyboardCleaner

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let didBecomeActive = NotificationCenter.default.publisher(
        for: NSApplication.didBecomeActiveNotification
    )

    private var isCleaning: Binding<Bool> {
        Binding(
            get: { cleaner.isEnabled },
            set: { cleaner.toggle($0) }
        )
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "keyboard")
                .font(.system(size: 54))
                .foregroundStyle(cleaner.isEnabled ? Color.green : Color.accentColor)

            VStack(spacing: 6) {
                Text("键盘清理")
                    .font(.largeTitle.bold())
                Text("关闭键盘输入，安心擦拭清洁")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Toggle(isOn: isCleaning) {
                Text(cleaner.isEnabled ? "键盘已禁用" : "清理模式")
                    .font(.title3.weight(.semibold))
            }
            .toggleStyle(.switch)
            .controlSize(.large)

            statusView

            Spacer(minLength: 0)

            Text("关闭开关或退出应用即可立即恢复键盘输入")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(32)
        .frame(width: 470, height: 500)
        .onAppear { cleaner.refreshTrust() }
        .onReceive(timer) { _ in cleaner.refreshTrust() }
        .onReceive(didBecomeActive) { _ in cleaner.refreshTrust() }
    }

    @ViewBuilder
    private var statusView: some View {
        if cleaner.isEnabled {
            enabledBanner
        } else if !cleaner.isTrusted {
            permissionView
        } else if let error = cleaner.lastError {
            errorBanner(error)
        } else {
            normalBanner
        }
    }

    private var enabledBanner: some View {
        Label("键盘输入已关闭，可以开始清洁", systemImage: "checkmark.shield.fill")
            .font(.callout)
            .foregroundStyle(.green)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private var permissionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("需要「辅助功能」权限", systemImage: "exclamationmark.triangle.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.orange)

            Text("要禁用键盘输入，请在系统设置中授权本应用的「辅助功能」权限。\n\n如果列表里已勾选本应用、但仍提示需要权限，说明那条授权对应的是旧版本（应用重新构建后系统记录的签名会变化）。请：\n① 在「辅助功能」列表选中旧条目，点下方「-」号删除；\n② 回到本应用打开开关，按系统提示重新勾选；\n③ 仍不识别就点「重新启动应用」。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button("前往系统设置授权") {
                    cleaner.requestPermission()
                    cleaner.openAccessibilitySettings()
                }
                Button("重新检查") {
                    cleaner.refreshTrust()
                }
                Button("重新启动应用") {
                    cleaner.relaunch()
                }
            }
            .controlSize(.large)

            Text("Bundle ID：\(cleaner.bundleIdentifier)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "xmark.octagon.fill")
            .font(.callout)
            .foregroundStyle(.red)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private var normalBanner: some View {
        Label("键盘输入正常", systemImage: "checkmark.circle")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
