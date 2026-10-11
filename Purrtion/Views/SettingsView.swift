import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var goals: Goals
    @Environment(\.modelContext) private var ctx
    @AppStorage("catPalette") private var paletteID = CatPalette.ginger.id
    @AppStorage("appearance") private var appearance = Appearance.system
    @AppStorage(VisionProvider.storageKey) private var visionProvider = VisionProvider.apple.rawValue
    @AppStorage(HealthSync.enabledKey) private var healthSync = false
    @AppStorage(AutoClose.enabledKey) private var autoClose = false
    @State private var notificationsDenied = false
    @State private var showDeleteAll = false
    @State private var exportURLs: [URL] = []
    @State private var exportError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        ForEach(CatPalette.all) { p in
                            Button {
                                Haptics.tap()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { paletteID = p.id }
                            } label: {
                                VStack(spacing: 6) {
                                    PixelSpriteView(sprite: paletteID == p.id ? Sprites.happy : Sprites.sit, pixel: 3, palette: p)
                                        .scaleEffect(paletteID == p.id ? 1.12 : 1)
                                    Text(p.name).font(Theme.font(12, paletteID == p.id ? .bold : .regular))
                                        .foregroundStyle(paletteID == p.id ? Theme.accent : Theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                    Picker("Darstellung", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: { Text("Deine Katze & Look") }
                .listRowBackground(Theme.card)

                Section {
                    NavigationLink { GoalsEditor() } label: {
                        LabeledContent("Kalorien & Makros", value: "\(goals.kcal.kcalString) kcal")
                    }
                    NavigationLink { ProfileCalculator() } label: {
                        Label("Bedarf berechnen", systemImage: "function")
                    }
                } header: { Text("Ziele") }
                .listRowBackground(Theme.card)

                Section {
                    Toggle(isOn: $goals.waterEnabled.animation()) { Label("Wasser tracken", systemImage: "drop.fill") }
                    if goals.waterEnabled {
                        SliderField(title: "Wasserziel", value: Binding(get: { Double(goals.waterML) / 1000 },
                                                                         set: { goals.waterML = Int(($0 * 1000 / 50).rounded() * 50) }),
                                    range: 0.5...6, step: 0.25, unit: "l", decimals: 2, tint: Theme.water)
                        Picker("Glasgröße", selection: $goals.waterStep) {
                            ForEach([150, 200, 250, 330, 500], id: \.self) { Text("\($0) ml").tag($0) }
                        }
                    }
                    Toggle(isOn: $goals.healthScoreEnabled) { Label("Health Score", systemImage: "heart.text.square.fill") }
                    Toggle(isOn: $autoClose) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Vortag nachts analysieren")
                                if notificationsDenied {
                                    Text("Mitteilungen sind aus – in den iOS-Einstellungen erlauben.")
                                        .font(Theme.font(12)).foregroundStyle(Theme.danger)
                                }
                            }
                        } icon: {
                            Image(systemName: "moon.stars.fill")
                        }
                    }
                    .onChange(of: autoClose) { _, on in
                        AutoClose.schedule()
                        guard on else { notificationsDenied = false; return }
                        Task { notificationsDenied = !(await AutoClose.requestPermission()) }
                    }
                } header: { Text("Funktionen") } footer: {
                    Text("Der Health Score bewertet jeden Tag von 0–100 nach Empfehlungen von WHO und DGE. Bei der automatischen Analyse schließt die KI ab etwa 0:30 Uhr den Vortag ab (mit deinem Anbieter aus „Foto-Erkennung“) und du bekommst eine Mitteilung. iOS bestimmt den genauen Zeitpunkt, meist nachts beim Laden – sonst passiert es beim nächsten Öffnen der App.")
                }
                .listRowBackground(Theme.card)

                Section {
                    NavigationLink { MyFoodsView() } label: {
                        Label("Eigene Lebensmittel & Rezepte", systemImage: "fork.knife")
                    }
                }
                .listRowBackground(Theme.card)

                Section {
                    Toggle(isOn: $healthSync) { Label("Gewicht mit Apple Health", systemImage: "heart.fill") }
                        .onChange(of: healthSync) { _, on in
                            guard on else { return }
                            Task {
                                try? await HealthSync.requestAuthorization()
                                await HealthSync.importWeights(into: ctx)
                            }
                        }
                } footer: {
                    Text("Liest dein Gewicht aus Health und speichert neue Einträge aus Purrtion dort.")
                }
                .listRowBackground(Theme.card)

                BackupSection()

                Section {
                    sourceRow("leaf.fill", "Bundeslebensmittelschlüssel 4.0",
                              "7.140 Lebensmittel, bis zu 138 Nährstoffe, im Labor analysiert. Offline in der App.")
                    sourceRow("cart.fill", "Open Food Facts",
                              "Barcodes & Markenprodukte, deutsche Produkte bevorzugt. Unplausible Werte werden markiert.")
                    NavigationLink { VisionSettingsView() } label: {
                        HStack {
                            Label("Foto-Erkennung", systemImage: "camera.viewfinder")
                            Spacer()
                            Text(VisionProvider(rawValue: visionProvider)?.name ?? "").foregroundStyle(Theme.textSecondary)
                        }
                    }
                } header: { Text("Datenquellen") } footer: {
                    Text(BLSDatabase.attribution)
                }
                .listRowBackground(Theme.card)

                Section {
                    Button { export() } label: { Label("Alle Daten als CSV exportieren", systemImage: "tablecells") }
                    Button(role: .destructive) { showDeleteAll = true } label: { Label("Alle Einträge löschen", systemImage: "trash") }
                } header: { Text("Daten") } footer: {
                    if let exportError { Text(exportError).foregroundStyle(Theme.danger) }
                }
                .listRowBackground(Theme.card)

                Section {
                    VStack(spacing: 10) {
                        WalkingCatLoader(pixel: 2, width: 160)
                        PixelText(text: "PURRTION", pixel: 3, color: Theme.accent)
                        Text("Version 1.1 · mit 🧡 und Pixeln").font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Profil")
            .keyboardDoneButton()
            .sheet(isPresented: $showDeleteAll) { DeleteAllSheet() }
            .sheet(isPresented: Binding(get: { !exportURLs.isEmpty }, set: { if !$0 { exportURLs = [] } })) {
                ShareSheet(items: exportURLs)
            }
        }
    }

    private func export() {
        do { exportURLs = try CSVExport.files(ctx); exportError = nil } catch { exportError = error.localizedDescription }
    }

    func sourceRow(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.accent)
                .frame(width: 32, height: 32).background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.font(15, .semibold))
                Text(text).font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Backup

struct BackupSection: View {
    @Environment(\.modelContext) private var ctx
    @AppStorage(Backup.autoKey) private var auto = false
    @State private var pickFolder = false
    @State private var pickRestore = false
    @State private var status: String?
    @State private var restoreData: Data?
    @State private var refresh = 0

    var body: some View {
        Section {
            Button { pickFolder = true } label: {
                HStack {
                    Label("Sicherungsordner", systemImage: "icloud.fill")
                    Spacer()
                    Text(Backup.folderName ?? "Auswählen").foregroundStyle(Theme.textSecondary).lineLimit(1)
                }
            }
            .id(refresh)
            Toggle(isOn: $auto) { Label("Täglich automatisch sichern", systemImage: "clock.arrow.circlepath") }
                .disabled(Backup.folderName == nil)
            Button { backupNow() } label: { Label("Jetzt sichern", systemImage: "arrow.up.doc.fill") }
                .disabled(Backup.folderName == nil)
            Button { pickRestore = true } label: { Label("Aus Sicherung wiederherstellen", systemImage: "arrow.down.doc.fill") }
        } header: { Text("Sicherung") } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Wähle einen Ordner in iCloud Drive. Purrtion legt dort etwa einmal täglich „\(Backup.fileName)“ ab – mit Einträgen, Rezepten, eigenen Lebensmitteln, Gewicht und Einstellungen. Auf einem neuen Gerät einfach wiederherstellen.")
                if let last = Backup.lastBackup {
                    Text("Letzte Sicherung: \(last.formatted(date: .abbreviated, time: .shortened))")
                }
                if let status { Text(status).foregroundStyle(Theme.accent) }
            }
            .id(refresh)
        }
        .listRowBackground(Theme.card)
        .fileImporter(isPresented: $pickFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                do {
                    try Backup.setFolder(url)
                    auto = true
                    backupNow()
                } catch { status = "Ordner konnte nicht gespeichert werden." }
            }
        }
        .fileImporter(isPresented: $pickRestore, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let ok = url.startAccessingSecurityScopedResource()
            defer { if ok { url.stopAccessingSecurityScopedResource() } }
            restoreData = try? Data(contentsOf: url)
            if restoreData == nil { status = "Datei konnte nicht gelesen werden." }
        }
        .confirmationDialog("Sicherung wiederherstellen?", isPresented: Binding(get: { restoreData != nil }, set: { if !$0 { restoreData = nil } }),
                            titleVisibility: .visible) {
            Button("Ersetzen & wiederherstellen", role: .destructive) {
                guard let data = restoreData else { return }
                do {
                    let p = try Backup.restore(from: data, into: ctx)
                    status = "Wiederhergestellt: \(p.entries.count) Einträge, \(p.custom.count) eigene Lebensmittel/Rezepte."
                } catch { status = "Wiederherstellung fehlgeschlagen: \(error.localizedDescription)" }
                restoreData = nil
            }
        } message: {
            Text("Alle Daten auf diesem iPhone werden durch die Sicherung ersetzt.")
        }
    }

    private func backupNow() {
        do {
            try Backup.writeToFolder(ctx)
            status = "Gesichert ✓"
            Haptics.success()
        } catch { status = "Sicherung fehlgeschlagen: \(error.localizedDescription)" }
        refresh += 1
    }
}

// MARK: - Delete all (protected)

struct DeleteAllSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @State private var confirmText = ""
    @FocusState private var focused: Bool
    private let word = "LÖSCHEN"

    private var confirmed: Bool { confirmText.trimmingCharacters(in: .whitespaces).uppercased() == word }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                CatMascot(mood: .full, pixel: 6)
                Text("Wirklich alles löschen?").font(Theme.font(22, .bold)).foregroundStyle(Theme.textPrimary)
                Text("Alle Einträge, Wasser, Gewicht, Favoriten, eigene Lebensmittel und Rezepte werden von diesem iPhone entfernt. Das kann nicht rückgängig gemacht werden.")
                    .font(Theme.font(15)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tippe **\(word)** zur Bestätigung").font(Theme.font(14)).foregroundStyle(Theme.textSecondary)
                    TextField(word, text: $confirmText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($focused)
                        .font(Theme.font(18, .bold))
                        .padding(.horizontal, 14).frame(height: 50)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                }
                Spacer()
                HStack(spacing: 12) {
                    Button("Abbrechen") { dismiss() }.buttonStyle(PillButtonStyle(color: Theme.textSecondary, filled: false))
                    Button("Endgültig löschen") {
                        try? ctx.delete(model: FoodEntry.self)
                        try? ctx.delete(model: WaterLog.self)
                        try? ctx.delete(model: WeightLog.self)
                        try? ctx.delete(model: SavedFood.self)
                        try? ctx.delete(model: CustomFood.self)
                        try? ctx.save()
                        Haptics.warning()
                        dismiss()
                    }
                    .buttonStyle(PillButtonStyle(color: Theme.danger))
                    .disabled(!confirmed)
                    .opacity(confirmed ? 1 : 0.4)
                }
            }
            .padding(24)
            .background(Theme.background.ignoresSafeArea())
            .onAppear { focused = true }
        }
    }
}

// MARK: - Photo recognition provider

struct VisionSettingsView: View {
    @AppStorage(VisionProvider.storageKey) private var selected = VisionProvider.apple.rawValue

    var body: some View {
        Form {
            Section {
                ForEach(VisionProvider.allCases) { p in
                    Button {
                        Haptics.tap()
                        withAnimation(.snappy) { selected = p.rawValue }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: p.icon).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.accent)
                                .frame(width: 32, height: 32).background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 9))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(Theme.font(16, .semibold)).foregroundStyle(Theme.textPrimary)
                                Text(p.costNote).font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: selected == p.rawValue ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20)).foregroundStyle(selected == p.rawValue ? Theme.accent : Theme.line)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: { Text("Anbieter") } footer: {
                Text("Apple Intelligence läuft komplett auf deinem iPhone. Klappt das mal nicht, erkennt Apples Bilderkennung zumindest die Hauptbestandteile.")
            }
            .listRowBackground(Theme.card)

            if let provider = VisionProvider(rawValue: selected), provider.needsKey {
                ProviderKeySection(provider: provider).id(provider)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Foto-Erkennung")
    }
}

private struct ProviderKeySection: View {
    let provider: VisionProvider
    @State private var key: String
    @AppStorage private var model: String

    init(provider: VisionProvider) {
        self.provider = provider
        _key = State(initialValue: provider.apiKey)
        _model = AppStorage(wrappedValue: "", provider.modelStorageKey)
    }

    var body: some View {
        Section {
            SecureField("API-Schlüssel", text: $key)
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: key) { _, v in Keychain.set(provider.keychainKey, v.trimmingCharacters(in: .whitespacesAndNewlines)) }
            HStack {
                Text("Modell")
                TextField(provider.defaultModel, text: $model)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(Theme.textSecondary)
            }
            if let url = provider.keyURL {
                Link(destination: url) { Label("Schlüssel erstellen", systemImage: "arrow.up.right.square") }
            }
        } header: { Text(provider.name) } footer: {
            Text(key.isEmpty ? "Ohne Schlüssel kann \(provider.name) nicht genutzt werden." :
                    "Der Schlüssel liegt sicher in der Keychain dieses iPhones. Leeres Modellfeld = \(provider.defaultModel).")
        }
        .listRowBackground(Theme.card)
    }
}

// MARK: - Goals

struct GoalsEditor: View {
    @EnvironmentObject private var goals: Goals

    var body: some View {
        Form {
            Section {
                SliderField(title: "Kalorienziel", value: $goals.kcal, range: 1000...5000, step: 10, unit: "kcal")
                    .onChange(of: goals.kcal) { _, _ in goals.syncMacros() }
            } footer: {
                Text("Tipp: Zahl antippen und direkt eintippen.")
            }
            .listRowBackground(Theme.card)

            Section {
                Picker("Makros einstellen in", selection: $goals.macroMode) {
                    ForEach(Goals.MacroMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: goals.macroMode) { _, mode in
                    if mode == .percent { goals.syncPercentFromGrams(); goals.syncMacros() }
                }

                if goals.macroMode == .percent {
                    SliderField(title: "Protein", value: Binding(get: { goals.proteinPct }, set: {
                        goals.proteinPct = min($0, 100 - goals.fatPct - 5); goals.syncMacros()
                    }), range: 10...50, unit: "%", tint: Theme.protein)
                    SliderField(title: "Fett", value: Binding(get: { goals.fatPct }, set: {
                        goals.fatPct = min($0, 100 - goals.proteinPct - 5); goals.syncMacros()
                    }), range: 10...60, unit: "%", tint: Theme.fat)
                    HStack {
                        Text("Kohlenhydrate").font(Theme.font(16))
                        Spacer()
                        Text("\(Int(goals.carbsPct)) %").font(Theme.font(20, .bold)).foregroundStyle(Theme.carbs)
                    }
                    MacroSplitBar(p: goals.proteinPct, c: goals.carbsPct, f: goals.fatPct)
                } else {
                    SliderField(title: "Protein", value: $goals.protein, range: 20...300, step: 5, unit: "g", tint: Theme.protein)
                    SliderField(title: "Kohlenhydrate", value: $goals.carbs, range: 0...600, step: 5, unit: "g", tint: Theme.carbs)
                    SliderField(title: "Fett", value: $goals.fat, range: 10...250, step: 5, unit: "g", tint: Theme.fat)
                }
            } header: { Text("Makros") } footer: {
                if goals.macroMode == .percent {
                    Text("= \(goals.protein.clean) g Protein · \(goals.carbs.clean) g Kohlenhydrate · \(goals.fat.clean) g Fett. Kohlenhydrate füllen automatisch auf 100 % auf.")
                } else {
                    let k = goals.protein * 4 + goals.carbs * 4 + goals.fat * 9
                    Text("Makros ergeben \(k.kcalString) kcal\(abs(k - goals.kcal) > 50 ? " – weicht vom Kalorienziel ab." : ".")")
                }
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Ziele")
        .keyboardDoneButton()
        .onAppear { goals.syncMacros() }
    }
}

struct MacroSplitBar: View {
    let p: Double, c: Double, f: Double
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                Capsule().fill(Theme.protein).frame(width: max(4, geo.size.width * p / 100 - 3))
                Capsule().fill(Theme.carbs).frame(width: max(4, geo.size.width * c / 100 - 3))
                Capsule().fill(Theme.fat).frame(width: max(4, geo.size.width * f / 100 - 3))
            }
            .animation(.snappy, value: p + f)
        }
        .frame(height: 10)
        .padding(.vertical, 4)
    }
}

struct ProfileCalculator: View {
    @EnvironmentObject private var goals: Goals
    var onApply: (() -> Void)? = nil

    var body: some View {
        Form {
            Section {
                Picker("Geschlecht", selection: $goals.sex) {
                    ForEach(Goals.Sex.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                SliderField(title: "Alter", value: $goals.age.asDouble, range: 14...90, unit: "Jahre")
                SliderField(title: "Größe", value: $goals.heightCM, range: 140...210, unit: "cm")
                SliderField(title: "Gewicht", value: $goals.weightKG, range: 40...180, step: 0.5, unit: "kg", decimals: 1)
            } header: { Text("Über dich") } footer: { Text("Zahl antippen zum direkten Eintippen.") }
            .listRowBackground(Theme.card)

            Section {
                Picker("Aktivität", selection: $goals.activity) {
                    ForEach(Goals.Activity.allCases) { a in
                        VStack(alignment: .leading) {
                            Text(a.label)
                            Text(a.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        .tag(a)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: { Text("Aktivität") }
            .listRowBackground(Theme.card)

            Section {
                Picker("Ziel", selection: $goals.target) {
                    ForEach(Goals.Target.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
            } header: { Text("Ziel") }
            .listRowBackground(Theme.card)

            Section {
                LabeledContent("Grundumsatz", value: "\(goals.bmr.kcalString) kcal")
                LabeledContent("Gesamtbedarf", value: "\(goals.tdee.kcalString) kcal")
                LabeledContent("Empfohlenes Ziel", value: "\(goals.suggestedKcal.kcalString) kcal")
                    .fontWeight(.bold)
                Button {
                    goals.applySuggestion()
                    Haptics.success()
                    onApply?()
                } label: {
                    Text("Als Ziel übernehmen").frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle())
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } header: { Text("Ergebnis") }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Bedarf berechnen")
        .keyboardDoneButton()
    }
}

struct OnboardingView: View {
    @EnvironmentObject private var goals: Goals
    @State private var page = 0

    var body: some View {
        NavigationStack {
            Group {
                if page == 0 {
                    VStack(spacing: 24) {
                        Spacer()
                        CatMascot(mood: .happy, pixel: 9)
                        PixelText(text: "PURRTION", pixel: 6, color: Theme.accent)
                        Text("Kalorien zählen – schnell, einfach und mit einer Katze, die sich mit dir freut.")
                            .font(Theme.font(18, .medium)).foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 32)
                        VStack(alignment: .leading, spacing: 12) {
                            feature("magnifyingglass", "7.100 Lebensmittel + Millionen Produkte")
                            feature("barcode.viewfinder", "Barcode scannen")
                            feature("camera.fill", "Gerichte per Foto erkennen")
                            feature("heart.text.square.fill", "Health Score, Vitamine & Mineralstoffe")
                        }
                        .padding(.top, 8)
                        Spacer()
                        Button("Los geht's") { withAnimation { page = 1 } }
                            .buttonStyle(PillButtonStyle())
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity)
                    .background(Theme.background.ignoresSafeArea())
                } else {
                    ProfileCalculator { goals.onboarded = true }
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Überspringen") { goals.onboarded = true }
                            }
                        }
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36).background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 10))
            Text(text).font(Theme.font(16, .medium)).foregroundStyle(Theme.textPrimary)
        }
    }
}
