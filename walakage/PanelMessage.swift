enum PanelMessage: String, CaseIterable {
    case timeUp = "Time up."
    case batteryLow = "Battery low."
    case powerDisconnected = "Power disconnected."
    case unableToKeepAwake = "Unable to keep awake."
    case administratorApprovalFailed = "Administrator approval failed."
    case unableToLaunchAtLogin = "Unable to launch at login."

    var isBlocking: Bool {
        self == .batteryLow || self == .powerDisconnected
    }
}
