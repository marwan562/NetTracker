import Foundation
import ServiceManagement

@MainActor
final class LoginItemManager: ObservableObject {
    @Published var launchAtLogin: Bool = false

    func refresh() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        refresh()
    }
}
