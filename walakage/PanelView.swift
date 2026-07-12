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
            toggleRow("Keep Awake", isOn: Binding(
                get: { session.isAwake || session.isStarting },
                set: setKeepAwake
            ))
            .font(.headline)
            .disabled(session.isStarting)

            if let message = session.message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Status")
                    .accessibilityValue(message)
            }

            timerControls

            toggleRow(
                "Keep Display Awake",
                help: "Also prevents the display from sleeping during an Awake Session.",
                isOn: Binding(
                    get: { session.keepDisplayAwake },
                    set: { keepDisplayAwake in
                        Task {
                            await session.setKeepDisplayAwake(keepDisplayAwake)
                        }
                    }
                )
            )
            .disabled(session.isStarting)

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
            HStack {
                Text("Timer")
                    .font(.subheadline.weight(.medium))

                Spacer()

                if isPanelOpen,
                   let deadline = session.timerDeadline,
                   let duration = SessionTimer.duration(
                       for: session.timerSelection,
                       customHours: session.customTimerHours,
                       customMinutes: session.customTimerMinutes
                   ) {
                    TimelineView(.periodic(
                        from: deadline.addingTimeInterval(-duration),
                        by: 1
                    )) { context in
                        if let countdown = session.countdown(at: context.date) {
                            HStack(spacing: 5) {
                                CountdownTimerIcon(progress: SessionTimer.progress(
                                    deadline: deadline,
                                    duration: duration,
                                    now: context.date
                                ))
                                .accessibilityHidden(true)

                                Text(countdown)
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(countdown)
                        }
                    }
                }
            }

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
        }
    }

    private var batteryControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            toggleRow(
                "Only While Charging",
                help: "Requires external power and ends the Awake Session if power is disconnected.",
                isOn: Binding(
                    get: { session.onlyWhileCharging },
                    set: session.setOnlyWhileCharging
                )
            )

            HStack {
                optionLabel(
                    "Battery Protection Threshold",
                    help: "Ends the Awake Session at or below this battery level while the Mac is discharging. Choose 5% to 80%."
                )
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

    private func toggleRow(
        _ title: String,
        help: String? = nil,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            optionLabel(title, help: help)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private func optionLabel(_ title: String, help: String?) -> some View {
        HStack(spacing: 4) {
            Text(title)
            if let help {
                OptionHelpButton(title: title, explanation: help)
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

private struct CountdownTimerIcon: View {
    let progress: Double

    private var color: Color {
        if progress <= 0.25 { return .yellow }
        if progress <= 0.5 { return .mint }
        return .green
    }

    var body: some View {
        Image(systemName: "chart.pie.fill", variableValue: progress)
            .foregroundStyle(color)
            .frame(width: 16, height: 16)
    }
}

private struct OptionHelpButton: View {
    let title: String
    let explanation: String

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .imageScale(.small)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(explanation)
        .accessibilityLabel("Help for \(title)")
        .accessibilityHint("Shows an explanation")
        .popover(isPresented: $isPresented, arrowEdge: .trailing) {
            Text(explanation)
                .frame(width: 220, alignment: .leading)
                .padding(12)
        }
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
