import AppKit
import ServiceManagement

// "Open at login", using the app's own login item (System Settings > General > Login Items).
// Offered once, right after AirPods setup finishes (or on the next launch for a setup finished earlier),
// and switchable any time in Settings.
enum LoginItem {
    static let askedKey="loginItemAsked"
    static var isEnabled:Bool{SMAppService.mainApp.status == .enabled}
    static var needsApproval:Bool{SMAppService.mainApp.status == .requiresApproval}

    @discardableResult static func set(_ on:Bool)->Bool{
        do{
            if on{try SMAppService.mainApp.register()}else{try SMAppService.mainApp.unregister()}
            return true
        }catch{
            NSLog("AirPointer login item change failed: \(error.localizedDescription)")
            return false
        }
    }

    // Asks once. Does nothing if it was asked before or is already on.
    static func offerIfNeeded(){
        let defaults=UserDefaults.standard
        guard defaults.bool(forKey:"setupComplete"),!defaults.bool(forKey:askedKey) else{return}
        defaults.set(true,forKey:askedKey)
        guard !isEnabled else{return}
        let alert=NSAlert()
        alert.messageText="Open AirPointer when you log in?"
        alert.informativeText="AirPointer will start in the menu bar each time you log in, ready for fn ⌃. You can change this any time in Settings."
        alert.addButton(withTitle:"Open at Login")
        alert.addButton(withTitle:"Not Now")
        NSApp.activate(ignoringOtherApps:true)
        if alert.runModal() == .alertFirstButtonReturn{set(true)}
    }
}
