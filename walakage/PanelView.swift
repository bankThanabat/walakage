import AppKit
import SwiftUI

struct PanelView: View {
    @ObservedObject var session: AwakeSessionController
    let setKeepAwake: (Bool) -> Void
    let quit: () -> Void

    @State private var customHoursDraft: IntegerFieldDraft
    @State private var customMinutesDraft: IntegerFieldDraft
    @State private var batteryThresholdDraft: IntegerFieldDraft
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
        _customHoursDraft = State(initialValue: IntegerFieldDraft(value: session.customTimerHours))
        _customMinutesDraft = State(initialValue: IntegerFieldDraft(value: session.customTimerMinutes))
        _batteryThresholdDraft = State(initialValue: IntegerFieldDraft(value: session.batteryProtectionThreshold))
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

            TimerSegmentedControl(
                selection: session.timerSelection,
                onSelect: selectTimer
            )
            .frame(height: 24)

            HStack(spacing: 8) {
                Text("Custom")
                    .foregroundStyle(.secondary)

                TextField("Hours", text: Binding(
                    get: { customHoursDraft.text },
                    set: { customHoursDraft.edit($0) }
                ))
                .frame(width: 48)
                .focused($focusedField, equals: .customHours)
                .onSubmit(commitCustomTimer)
                .accessibilityLabel("Hours")

                Text("h")
                    .foregroundStyle(.secondary)

                TextField("Minutes", text: Binding(
                    get: { customMinutesDraft.text },
                    set: { customMinutesDraft.edit($0) }
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
                    get: { batteryThresholdDraft.text },
                    set: { batteryThresholdDraft.edit($0) }
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
        guard customHoursDraft.isDirty || customMinutesDraft.isDirty else { return }
        let custom = session.setCustomTimer(
            hours: customHoursDraft.parsedValue ?? 0,
            minutes: customMinutesDraft.parsedValue ?? 0
        )
        customHoursDraft.commit(custom.hours)
        customMinutesDraft.commit(custom.minutes)
    }

    private func selectTimer(_ selection: SessionTimerSelection) {
        customHoursDraft.discardEdits()
        customMinutesDraft.discardEdits()
        session.setTimer(selection)
    }

    private func commitBatteryThreshold() {
        guard batteryThresholdDraft.isDirty else { return }
        batteryThresholdDraft.commit(session.setBatteryProtectionThreshold(
            batteryThresholdDraft.parsedValue ?? 5
        ))
    }

    private func syncDrafts() {
        customHoursDraft.commit(session.customTimerHours)
        customMinutesDraft.commit(session.customTimerMinutes)
        batteryThresholdDraft.commit(session.batteryProtectionThreshold)
    }

    private enum Field: Hashable {
        case customHours
        case customMinutes
        case batteryThreshold
    }
}

private struct TimerSegmentedControl: NSViewRepresentable {
    let selection: SessionTimerSelection
    let onSelect: (SessionTimerSelection) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: SessionTimerSelection.quickChoices.map(\.title),
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.didSelect(_:))
        )
        control.segmentStyle = .automatic
        control.setAccessibilityLabel("Timer")
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.onSelect = onSelect
        control.selectedSegment = SessionTimerSelection.quickChoices.firstIndex(of: selection) ?? -1
    }

    final class Coordinator: NSObject {
        var onSelect: (SessionTimerSelection) -> Void

        init(onSelect: @escaping (SessionTimerSelection) -> Void) {
            self.onSelect = onSelect
        }

        @objc func didSelect(_ sender: NSSegmentedControl) {
            guard SessionTimerSelection.quickChoices.indices.contains(sender.selectedSegment) else { return }
            onSelect(SessionTimerSelection.quickChoices[sender.selectedSegment])
        }
    }
}
