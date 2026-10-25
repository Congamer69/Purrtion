import SwiftUI
import SwiftData

/// Profil → Funktionen → Extras: each 2.6 extra has its own switch.
struct ExtrasSection: View {
    @Environment(\.modelContext) private var ctx
    @EnvironmentObject private var goals: Goals
    @AppStorage(Extras.weekBudgetKey) private var budget = false
    @AppStorage(Extras.weekBudgetPctKey) private var budgetPct = 15.0
    @AppStorage(Extras.timeSuggestKey) private var timeSuggest = true
    @AppStorage(Extras.multiScanKey) private var multiScan = true
    @AppStorage(Extras.forecastKey) private var forecast = true
    @AppStorage(Extras.goalWeightKey) private var goalWeight = 0.0
    @AppStorage(Extras.reminderKey) private var reminder = false
    @AppStorage(Extras.reminderMinutesKey) private var reminderMinutes = 12 * 60 + 30
    @AppStorage(Extras.shopKey) private var shop = true
    @State private var denied = false
    @State private var goalText = ""
    @FocusState private var goalFocused: Bool

    private var reminderTime: Binding<Date> {
        Binding(get: { Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: .now) ?? .now },
                set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0); reminderMinutes = (c.hour ?? 12) * 60 + (c.minute ?? 0) })
    }

    var body: some View {
        Section {
            Toggle(isOn: $budget.animation()) { Label("Wochenbudget", systemImage: "calendar.badge.clock") }
                .onChange(of: budget) { _, _ in refresh() }
            if budget {
                SliderField(title: "Ausgleich pro Tag", value: $budgetPct, range: 5...30, step: 5, unit: "%")
                    .onChange(of: budgetPct) { _, _ in refresh() }
            }
            Toggle(isOn: $timeSuggest) { Label("Vorschläge zur Uhrzeit", systemImage: "clock.badge.checkmark") }
            Toggle(isOn: $multiScan) { Label("Mehrfach-Scan", systemImage: "barcode.viewfinder") }
            Toggle(isOn: $forecast.animation()) { Label("Gewichts-Prognose", systemImage: "chart.line.uptrend.xyaxis") }
            if forecast {
                HStack {
                    Text("Zielgewicht").font(Theme.font(16))
                    Spacer()
                    TextField("nicht gesetzt", text: $goalText)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        .font(Theme.font(17, .bold)).frame(maxWidth: 120)
                        .focused($goalFocused)
                        .onChange(of: goalText) { _, text in
                            let value = Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
                            goalWeight = value >= 30 && value <= 250 ? value : 0
                        }
                    Text("kg").foregroundStyle(Theme.textSecondary)
                }
            }
            Toggle(isOn: $reminder.animation()) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sanfte Erinnerung")
                        if denied { Text("Mitteilungen sind aus. Erlaube sie in den iOS-Einstellungen.").font(Theme.font(12)).foregroundStyle(Theme.danger) }
                    }
                } icon: { Image(systemName: "bell.badge.fill") }
            }
            .onChange(of: reminder) { _, on in
                Task {
                    if on { denied = !(await GentleReminder.requestPermission()) } else { denied = false }
                    await GentleReminder.reschedule(ctx: ctx)
                }
            }
            if reminder {
                DatePicker("Erinnern um", selection: reminderTime, displayedComponents: .hourAndMinute)
                    .onChange(of: reminderMinutes) { _, _ in Task { await GentleReminder.reschedule(ctx: ctx) } }
            }
            Toggle(isOn: $shop) { Label("Shop und Outfits", systemImage: "bag.fill") }
        } header: { Text("Extras") } footer: {
            Text("Wochenbudget: Ein Tag über oder unter dem Ziel verteilt sich auf die übrigen Tage der Woche, höchstens um den eingestellten Anteil pro Tag. Vergangene Tage behalten ihr damaliges Ziel. Vorschläge: zeigt beim Hinzufügen, was du um diese Zeit meistens isst. Mehrfach-Scan: beim Barcode die Taste „Weiteres scannen“. Prognose: aus deinem Gewichtstrend der letzten sechs Wochen. Erinnerung: nur solange heute noch nichts eingetragen ist. Shop: Punkte aus deiner Serie für Fellfarben, Hüte, Brillen und Schals (Serie → Shop).")
        }
        .listRowBackground(Theme.card)
        .onAppear { if goalWeight > 0 { goalText = goalWeight.formatted(.number.precision(.fractionLength(0...1)).grouping(.never)) } }
    }

    private func refresh() {
        goals.activityUpdated()
        WidgetBridge.update(ctx, goals: goals)
    }
}
