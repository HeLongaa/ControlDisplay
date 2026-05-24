import AppKit

/// 启动时静默检查 GitHub 最新 Release，有新版本则弹提示。
final class Updater {

    static let currentVersion = "1.0.1"
    private static let apiURL = URL(string: "https://api.github.com/repos/HeLongaa/ControlDisplay/releases/latest")!
    private static let releasesURL = URL(string: "https://github.com/HeLongaa/ControlDisplay/releases/latest")!

    /// 静默检查，有新版本才弹窗。
    static func checkInBackground() {
        URLSession.shared.dataTask(with: apiURL) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else { return }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            guard isNewer(latest, than: currentVersion) else { return }
            DispatchQueue.main.async { showUpdateAlert(latestVersion: latest) }
        }.resume()
    }

    /// 手动检查，无论是否有新版本都给反馈。
    static func checkManually() {
        URLSession.shared.dataTask(with: apiURL) { data, _, error in
            DispatchQueue.main.async {
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String else {
                    let a = NSAlert()
                    a.messageText = "检查更新失败"
                    a.informativeText = error?.localizedDescription ?? "无法连接到服务器"
                    a.runModal()
                    return
                }
                let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                if isNewer(latest, than: currentVersion) {
                    showUpdateAlert(latestVersion: latest)
                } else {
                    let a = NSAlert()
                    a.messageText = "已是最新版本"
                    a.informativeText = "当前版本 \(currentVersion) 已是最新。"
                    a.runModal()
                }
            }
        }.resume()
    }

    private static func showUpdateAlert(latestVersion: String) {
        let alert = NSAlert()
        alert.messageText = "发现新版本 \(latestVersion)"
        alert.informativeText = "当前版本：\(currentVersion)\n是否前往下载？"
        alert.addButton(withTitle: "前往下载")
        alert.addButton(withTitle: "稍后再说")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(releasesURL)
        }
    }

    private static func isNewer(_ latest: String, than current: String) -> Bool {
        latest.compare(current, options: .numeric) == .orderedDescending
    }
}
