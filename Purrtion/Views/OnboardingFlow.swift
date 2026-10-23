import SwiftUI

/// Guided first-run setup: goal, body data, activity, Apple Health. Ends with a suggested daily target.
struct OnboardingSetup: View {
    @EnvironmentObject private var goals: Goals
    @Environment(\.modelContext) private var ctx
    var onDone: () -> Void
    #if DEBUG
    @State private var step = UserDefaults.standard.string(forKey: "debugStep").flatMap(Int.init) ?? 0
    #else
    @State private var step = 0
    #endif
    @AppStorage(HealthSync.enabledKey) private var healthSync = false
    private let steps = 4

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            HStack(spacing: 6) {
                ForEach(0..<steps, id: \.self) { i in
                    Capsule().fill(i <= step ? Theme.accent : Theme.cardAlt).frame(height: 4)
                }
            }
            .padding(.horizontal, Theme.Space.l)

            Group {
                switch step {
                case 0: goalStep
                case 1: bodyStep
                case 2: activityStep
                default: healthStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            .id(step)

            HStack(spacing: Theme.Space.m) {
                if step > 0 {
                    Button { go(-1) } label: {
                        Image(systemName: "chevron.left").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.textPrimary)
                            .frame(width: 54, height: 54).background(Theme.cardAlt, in: Circle())
                    }
                    .accessibilityLabel("Zurück")
                }
                Button(step == steps - 1 ? "Fertig" : "Weiter") { next() }
                    .buttonStyle(PillButtonStyle())
            }
            .buttonStyle(SquishButtonStyle())
            .padding(.horizontal, Theme.Space.l)
            .padding(.bottom, Theme.Space.s)
        }
        .padding(.top, Theme.Space.s)
        .background(Theme.background.ignoresSafeArea())
    }

    private func go(_ d: Int) { Haptics.tap(); withAnimation(Motion.quick) { step += d } }

    private func next() {
        if step < steps - 1 { go(1); return }
        Task {
            if healthSync {
                try? await HealthSync.requestAuthorization()
                await HealthSync.importWeights(into: ctx)
            }
            goals.applySuggestion()
            Haptics.success()
            onDone()
        }
    }

    private func header(_ mood: CatMood, _ title: String, _ text: String) -> some View {
        VStack(spacing: Theme.Space.s) {
            CatMascot(mood: mood, pixel: 5)
            Text(title).font(Theme.font(22, .bold)).foregroundStyle(Theme.textPrimary).multilineTextAlignment(.center)
            Text(text).font(Theme.font(14)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
        }
        .padding(.horizontal, Theme.Space.xl)
    }

    // MARK: Steps

    private var goalStep: some View {
        VStack(spacing: Theme.Space.xl) {
            header(.happy, "Was möchtest du erreichen?", "Daraus berechnet Purrtion dein Kalorienziel. Du kannst alles später ändern.")
            VStack(spacing: Theme.Space.s) {
                ForEach(Goals.Target.allCases) { t in
                    choice(t.label, detail: t.delta == 0 ? "Gleich viel wie du verbrauchst" : "\(t.delta > 0 ? "+" : "−")\(Int(abs(t.delta))) kcal pro Tag", selected: goals.target == t) {
                        goals.target = t
                    }
                }
            }
            .padding(.horizontal, Theme.Space.l)
        }
    }

    private var bodyStep: some View {
        VStack(spacing: Theme.Space.l) {
            header(.idle, "Ein paar Eckdaten", "Für Grundumsatz und Promille-Schätzung. Die Daten bleiben auf deinem Gerät.")
            Picker("Geschlecht", selection: $goals.sex) {
                ForEach(Goals.Sex.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Space.l)
            HStack(spacing: 0) {
                wheel("Alter", "Jahre", Binding(get: { goals.age }, set: { goals.age = $0 }), 14...90)
                wheel("Größe", "cm", Binding(get: { Int(goals.heightCM) }, set: { goals.heightCM = Double($0) }), 140...210)
                wheel("Gewicht", "kg", Binding(get: { Int(goals.weightKG.rounded()) }, set: { goals.weightKG = Double($0) }), 40...180)
            }
            .padding(.horizontal, Theme.Space.s)
        }
    }

    private func wheel(_ title: String, _ unit: String, _ value: Binding<Int>, _ range: ClosedRange<Int>) -> some View {
        VStack(spacing: 0) {
            Text("\(title) · \(unit)").font(Theme.font(12, .bold)).foregroundStyle(Theme.textSecondary)
            Picker(title, selection: value) {
                ForEach(range, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
        }
        .frame(maxWidth: .infinity)
    }

    private var activityStep: some View {
        VStack(spacing: Theme.Space.xl) {
            header(.proud, "Wie aktiv bist du?", "Ohne Sport, den du extra einträgst.")
            VStack(spacing: Theme.Space.s) {
                ForEach(Goals.Activity.allCases) { a in
                    choice(a.label, detail: a.detail, selected: goals.activity == a) { goals.activity = a }
                }
            }
            .padding(.horizontal, Theme.Space.l)
        }
    }

    private var healthStep: some View {
        VStack(spacing: Theme.Space.xl) {
            header(.eating, "Dein Tagesziel", "Startwert aus deinen Angaben. Du kannst ihn jederzeit unter Profil anpassen.")
            VStack(spacing: 2) {
                Text(goals.suggestedKcal.kcalString).font(Theme.font(44, .heavy)).foregroundStyle(Theme.accentText)
                Text("kcal pro Tag").font(Theme.font(14)).foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, Theme.Space.l)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .padding(.horizontal, Theme.Space.l)
            Toggle(isOn: $healthSync) {
                Label("Gewicht aus Apple Health übernehmen", systemImage: "heart.fill")
                    .font(Theme.font(14, .bold)).foregroundStyle(Theme.textPrimary)
            }
            .tint(Theme.accent)
            .padding(Theme.Space.l)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .padding(.horizontal, Theme.Space.l)
        }
    }

    private func choice(_ title: String, detail: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); withAnimation(Motion.quick) { action() } } label: {
            HStack(spacing: Theme.Space.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
                    Text(detail).font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22)).foregroundStyle(selected ? Theme.accent : Theme.textSecondary.opacity(0.5))
            }
            .padding(Theme.Space.l)
            .background(selected ? Theme.accentSoft : Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius - 4, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius - 4, style: .continuous).stroke(selected ? Theme.accent : .clear, lineWidth: 2))
        }
        .buttonStyle(SquishButtonStyle())
    }
}
