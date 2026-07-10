import SwiftUI

struct PanelView: View {
    @ObservedObject var session: AwakeSessionController
    let setKeepAwake: (Bool) -> Void
    let quit: () -> Void

    @State private var customHoursText: String
    @State private var customMinutesText: String
    @State private var batteryThresholdText: String
    @State private var customTimerDirty = false
    @State private var batteryThresholdDirty = false
    @State private var isPanelOpen = false
    @State private var lastFocusedField: Field?
    @FocusState private var focusedField: Field?

    init(
        session: AwakeSessionController,
        setKeepAwake: @escaping (Bool) -> Void,
        quit: @escaping () -> Void
    ) {
        self.session = session
        self.setKeepAwake = setKeepAwake
        self.quit = quit
        _customHoursText = State(initialValue: String(session.customTimerHours))
        _customMinutesText = State(initialValue: String(session.customTimerMinutes))
        _batteryThresholdText = State(initialValue: String(session.batteryProtectionThreshold))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Keep Awake", isOn: Binding(
                get: { session.isAwake },
                set: setKeepAwake
            ))
            .font(.headline)
            .accessibilityLabel("Keep Awake")

            if let message = session.message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Status")
                    .accessibilityValue(message)
            }

            timerControls

            Toggle("Keep Display Awake", isOn: Binding(
                get: { session.keepDisplayAwake },
                set: session.setKeepDisplayAwake
            ))
            .accessibilityLabel("Keep Display Awake")

            if session.isBatteryMac {
                batteryControls
            }

            Toggle("Launch at Login", isOn: Binding(
                get: { session.launchAtLogin },
                set: session.setLaunchAtLogin
            ))
            .accessibilityLabel("Launch at Login")

            Divider()

            Button("Quit Walakage", action: quit)
                .buttonStyle(.plain)
                .accessibilityLabel("Quit Walakage")
        }
        .toggleStyle(.switch)
        .padding(16)
        .frame(width: 320)
        .onAppear {
            syncDrafts()
            isPanelOpen = true
        }
        .onDisappear {
            commitFocusedDraft()
            isPanelOpen = false
        }
        .onChange(of: focusedField) { newField in
            if lastFocusedField != newField {
                commit(field: lastFocusedField)
            }
            lastFocusedField = newField
        }
    }

    private var timerControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timer")
                .font(.subheadline.weight(.medium))

            Picker("Timer", selection: Binding(
                get: { session.timerSelection },
                set: session.setTimer
            )) {
                ForEach(SessionTimerSelection.allCases) { choice in
                    Text(choice.title).tag(choice)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .accessibilityLabel("Timer")

            HStack(spacing: 8) {
                Text("Custom")
                    .foregroundStyle(.secondary)

                TextField("Hours", text: Binding(
                    get: { customHoursText },
                    set: {
                        customHoursText = $0
                        customTimerDirty = true
                    }
                ))
                .frame(width: 48)
                .focused($focusedField, equals: .customHours)
                .onSubmit(commitCustomTimer)
                .accessibilityLabel("Hours")

                Text("h")
                    .foregroundStyle(.secondary)

                TextField("Minutes", text: Binding(
                    get: { customMinutesText },
                    set: {
                        customMinutesText = $0
                        customTimerDirty = true
                    }
                ))
                .frame(width: 48)
                .focused($focusedField, equals: .customMinutes)
                .onSubmit(commitCustomTimer)
                .accessibilityLabel("Minutes")

                Text("m")
                    .foregroundStyle(.secondary)
            }
            .textFieldStyle(.roundedBorder)

            if isPanelOpen {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    if let countdown = session.countdown(at: context.date) {
                        Text(countdown)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(countdown)
                    }
                }
            }
        }
    }

    private var batteryControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Only While Charging", isOn: Binding(
                get: { session.onlyWhileCharging },
                set: session.setOnlyWhileCharging
            ))
            .accessibilityLabel("Only While Charging")

            HStack {
                Text("Battery Protection Threshold")
                Spacer()
                TextField("Percent", text: Binding(
                    get: { batteryThresholdText },
                    set: {
                        batteryThresholdText = $0
                        batteryThresholdDirty = true
                    }
                ))
                .frame(width: 48)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .batteryThreshold)
                .onSubmit(commitBatteryThreshold)
                .accessibilityLabel("Battery Protection Threshold")
                Text("%")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func commit(field: Field?) {
        switch field {
        case .customHours, .customMinutes:
            commitCustomTimer()
        case .batteryThreshold:
            commitBatteryThreshold()
        case nil:
            break
        }
    }

    private func commitFocusedDraft() {
        commit(field: focusedField)
    }

    private func commitCustomTimer() {
        guard customTimerDirty else { return }
        let custom = session.setCustomTimer(
            hours: Int(customHoursText) ?? 0,
            minutes: Int(customMinutesText) ?? 0
        )
        customHoursText = String(custom.hours)
        customMinutesText = String(custom.minutes)
        customTimerDirty = false
    }

    private func commitBatteryThreshold() {
        guard batteryThresholdDirty else { return }
        batteryThresholdText = String(session.setBatteryProtectionThreshold(
            Int(batteryThresholdText) ?? 5
        ))
        batteryThresholdDirty = false
    }

    private func syncDrafts() {
        customHoursText = String(session.customTimerHours)
        customMinutesText = String(session.customTimerMinutes)
        batteryThresholdText = String(session.batteryProtectionThreshold)
        customTimerDirty = false
        batteryThresholdDirty = false
    }

    private enum Field: Hashable {
        case customHours
        case customMinutes
        case batteryThreshold
    }
}
