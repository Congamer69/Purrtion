import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var goals: Goals
    @Environment(\.modelContext) private var ctx
    @AppStorage("catPalette") private var paletteID = CatPalette.ginger.id
    @AppStorage("appearance") private var appearance = Appearance.system
    @AppStorage("profile.name") private var profileName = ""
    @AppStorage(ThemeSetting.accentKey) private var accent = ThemeAccent.orange
    @AppStorage(ThemeSetting.cornersKey) private var corners = ThemeCorners.normal
    @AppStorage(ThemeSetting.cardsKey) private var cardStyle = ThemeCards.shadow
    @AppStorage(ThemeSetting.backgroundKey) private var backgroundTone = ThemeBackground.warm
    @AppStorage(ThemeSetting.fontKey) private var fontStyle = ThemeFont.rounded
    @AppStorage(VisionProvider.storageKey) private var visionProvider = VisionProvider.apple.rawValue
    @AppStorage(AITask.day.providerKey) private var dayProvider = ""

    /// "Gemini" or "Gemini · Claude" when photo and day analysis differ.
    private var aiSummary: String {
        _ = visionProvider; _ = dayProvider   // re-render on change
        let photo = AITask.photo.provider, day = AITask.day.provider
        return photo == day ? photo.shortName : "\(photo.shortName) · \(day.shortName)"
    }
    @AppStorage(HealthSync.enabledKey) private var healthSync = false
    @AppStorage(NutritionSync.enabledKey) private var nutritionSync = false
    @AppStorage(AutoClose.enabledKey) private var autoClose = false
    @State private var notificationsDenied = false
    @State private var rewritingHealth = false
    @State private var healthRewritten = false
    @State private var showDeleteAll = false
    @State private var exportURLs: [URL] = []
    @State private var exportError: String?

    private func page<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        Form { content() }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink { ProfileCalculator() } label: {
                        HStack(spacing: 12) {
                            CatMascot(mood: .happy, pixel: 2.4).frame(width: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profileName.isEmpty ? "Dein Profil" : profileName).font(Theme.font(16, .semibold))
                                Text("\(goals.sex.label) · \(goals.age) Jahre · \(Int(goals.heightCM)) cm · \(goals.weightKG.formatted(.number.precision(.fractionLength(0...1)))) kg")
                                    .font(Theme.font(13)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } footer: {
                    Text("Geschlecht, Alter, Größe, Gewicht und Aktivität. Grundlage für Bedarf, echten Verbrauch und Promille.")
                }
                .listRowBackground(Theme.card)

                Section {
                    NavigationLink { GoalsEditor() } label: {
                        LabeledContent("Kalorien & Makros", value: "\(goals.kcal.kcalString) kcal")
                    }
                } header: { Text("Ziele") }
                .listRowBackground(Theme.card)

                Section {
                    NavigationLink { page("Darstellung") { appearanceSection } } label: {
                        HStack {
                            Label("Darstellung", systemImage: "paintpalette.fill")
                        }
                    }
                    NavigationLink { page("Funktionen") { featuresSection } } label: {
                        HStack {
                            Label("Funktionen", systemImage: "slider.horizontal.3")
                        }
                    }
                    NavigationLink { page("Apple Health") { healthSection } } label: {
                        HStack {
                            Label("Apple Health", systemImage: "heart.fill")
                        }
                    }
                    NavigationLink { MyFoodsView() } label: {
                        HStack {
                            Label("Eigene Lebensmittel & Rezepte", systemImage: "fork.knife")
                        }
                    }
                }
                .listRowBackground(Theme.card)

                Section {
                    NavigationLink { page("Freunde") { FriendsSettingsSection() } } label: {
                        HStack {
                            Label("Freunde", systemImage: "person.2.fill")
                        }
                    }
                    NavigationLink { dataPage } label: {
                        HStack {
                            Label("Daten & Backup", systemImage: "externaldrive.fill")
                        }
                    }
                    NavigationLink { page("Datenquellen") { sourcesSection } } label: {
                        HStack {
                            Label("Datenquellen & KI", systemImage: "sparkles")
                            Spacer()
                            Text(aiSummary).font(Theme.font(13)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                        }
                    }
                }
                .listRowBackground(Theme.card)

                Section {
                    VStack(spacing: 10) {
                        WalkingCatLoader(pixel: 2, width: 160)
                        PixelText(text: "PURRTION", pixel: 3, color: Theme.accent)
                        Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · mit 🧡 und Pixeln").font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
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
        }
    }

    private var themePreview: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack(spacing: 16) {
                CatMascot(mood: .happy, pixel: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profileName.isEmpty ? "Vorschau" : profileName).font(Theme.font(14)).foregroundStyle(Theme.textSecondary)
                    Text("601").font(Theme.font(38, .heavy)).foregroundStyle(Theme.textPrimary)
                    Text("kcal übrig").font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                Capsule().fill(Theme.accent).frame(height: 8)
                Capsule().fill(Theme.track(Theme.accent)).frame(width: 60, height: 8)
            }
            HStack(spacing: 8) {
                Label("Serie 12", systemImage: "flame.fill").font(Theme.font(12, .bold)).foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10).padding(.vertical, 6).background(Theme.accentSoft, in: Capsule())
                Text("Suchen").font(Theme.font(14, .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8).background(Theme.accent, in: Capsule())
            }
        }
        .card(padding: 18)
    }

    @ViewBuilder private var appearanceSection: some View {
        Section { themePreview }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

        Section {
            TextField("Dein Name (optional)", text: $profileName).textContentType(.givenName)
        } header: { Text("Du") } footer: { Text("Erscheint in der Begrüßung auf „Heute“ und im Profil.") }
        .listRowBackground(Theme.card)

        Section {
            HStack(spacing: 12) {
                ForEach(ThemeAccent.allCases) { a in
                    Button {
                        Haptics.tap()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { accent = a }
                    } label: {
                        Circle().fill(Color(hex: a.hex)).frame(height: 40)
                            .overlay { if accent == a { Image(systemName: "checkmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white) } }
                            .overlay(Circle().stroke(Theme.textPrimary.opacity(accent == a ? 0.9 : 0), lineWidth: 2).padding(-4))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(a.name)
                    .accessibilityAddTraits(accent == a ? .isSelected : [])
                }
            }
            .padding(.vertical, 6)
        } header: { Text("Akzentfarbe") }
        .listRowBackground(Theme.card)

        Section {
            Picker("Ecken", selection: $corners) { ForEach(ThemeCorners.allCases) { Text($0.name).tag($0) } }
            Picker("Karten", selection: $cardStyle) { ForEach(ThemeCards.allCases) { Text($0.name).tag($0) } }
            Picker("Hintergrund", selection: $backgroundTone) { ForEach(ThemeBackground.allCases) { Text($0.name).tag($0) } }
            Picker("Schrift", selection: $fontStyle) { ForEach(ThemeFont.allCases) { Text($0.name).tag($0) } }
            Button("Auf Standard zurücksetzen") {
                accent = .orange; corners = .normal; cardStyle = .shadow; backgroundTone = .warm; fontStyle = .rounded
            }
        } header: { Text("Stil") }
        .listRowBackground(Theme.card)

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
    }

    @ViewBuilder private var featuresSection: some View {
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
                    Text("Der Health Score bewertet jeden Tag von 0–100 nach Empfehlungen von WHO und DGE. Bei der automatischen Analyse schließt die KI ab etwa 0:30 Uhr den Vortag ab (Anbieter unter „KI-Modelle“ → Tagesanalyse) und du bekommst eine Mitteilung. iOS bestimmt den genauen Zeitpunkt, meist nachts beim Laden – sonst passiert es beim nächsten Öffnen der App.")
                }
                .listRowBackground(Theme.card)
    }

    @ViewBuilder private var healthSection: some View {
                Section {
                    Toggle(isOn: $healthSync) { Label("Gewicht mit Apple Health", systemImage: "heart.fill") }
                        .onChange(of: healthSync) { _, on in
                            guard on else { return }
                            Task {
                                try? await HealthSync.requestAuthorization()
                                await HealthSync.importWeights(into: ctx)
                            }
                        }
                    Toggle(isOn: $nutritionSync) { Label("Ernährung in Apple Health", systemImage: "fork.knife.circle.fill") }
                        .onChange(of: nutritionSync) { _, on in
                            guard on else { return }
                            Task {
                                try? await NutritionSync.requestAuthorization()
                                await NutritionSync.syncRecent(days: 30, container: PurrtionApp.container)
                            }
                        }
                    if nutritionSync {
                        Button {
                            rewritingHealth = true
                            Task {
                                await NutritionSync.repair(container: PurrtionApp.container)
                                rewritingHealth = false
                                healthRewritten = true
                                Haptics.success()
                            }
                        } label: {
                            HStack {
                                Label(healthRewritten ? "Neu geschrieben" : "Ernährungsdaten in Health neu schreiben",
                                      systemImage: healthRewritten ? "checkmark" : "arrow.triangle.2.circlepath")
                                Spacer()
                                if rewritingHealth { ProgressView() }
                            }
                        }
                        .disabled(rewritingHealth)
                    }
                } footer: {
                    Text("Liest dein Gewicht aus Health und speichert neue Einträge aus Purrtion dort. „Ernährung“ schreibt jeden Eintrag mit kcal, Makros und Mikronährstoffen sowie dein Wasser ins Ernährungsprotokoll von Health. Änderungen und Löschungen werden übernommen. „Neu schreiben“ löscht alles, was Purrtion in Health eingetragen hat, und schreibt jeden Tag einmal sauber neu. Daten anderer Apps bleiben unberührt.")
                }
                .listRowBackground(Theme.card)
    }

    @ViewBuilder private var sourcesSection: some View {
                Section {
                    ForEach(SearchSource.allCases) { SourceToggle(source: $0) }
                    DatabaseUpdateRow()
                    NavigationLink { VisionSettingsView() } label: {
                        HStack {
                            Label("KI-Modelle", systemImage: "sparkles")
                            Spacer()
                            Text(aiSummary).foregroundStyle(Theme.textSecondary).lineLimit(1)
                        }
                    }
                } header: { Text("Datenquellen") } footer: {
                    Text("Ausgeschaltete Quellen erscheinen nicht mehr in der Suche. Barcodes nutzen immer Open Food Facts (immer live). Neue Versionen von BLS und Schweizer Datenbank werden über GitHub verteilt und bleiben danach offline nutzbar.\n\n\(BLSDatabase.attribution)\n\n\(SwissDatabase.attribution)\n\n\(RestaurantDatabase.attribution)")
                }
                .listRowBackground(Theme.card)
    }

    private var dataPage: some View {
        page("Daten & Backup") {
                BackupSection()
                Section {
                    Button { export() } label: { Label("Alle Daten als CSV exportieren", systemImage: "tablecells") }
                    Button(role: .destructive) { showDeleteAll = true } label: { Label("Alle Einträge löschen", systemImage: "trash") }
                } header: { Text("Daten") } footer: {
                    if let exportError { Text(exportError).foregroundStyle(Theme.danger) }
                }
                .listRowBackground(Theme.card)
        }
        .sheet(isPresented: $showDeleteAll) { DeleteAllSheet() }
        .sheet(isPresented: Binding(get: { !exportURLs.isEmpty }, set: { if !$0 { exportURLs = [] } })) {
            ShareSheet(items: exportURLs)
        }
    }


    private func export() {
        do { exportURLs = try CSVExport.files(ctx); exportError = nil } catch { exportError = error.localizedDescription }
    }
}

/// Versions of the offline databases + manual / automatic update.
private struct DatabaseUpdateRow: View {
    @ObservedObject private var updater = DatabaseUpdater.shared
    @AppStorage(DatabaseUpdater.autoKey) private var auto = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.accent)
                    .frame(width: 32, height: 32).background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Datenbanken aktualisieren").font(Theme.font(15, .semibold))
                    Text("BLS \(updater.version(.bls)) · Schweiz \(updater.version(.swiss)) · Ketten \(updater.version(.restaurants))\(updater.lastCheck.map { " · geprüft \($0.formatted(.relative(presentation: .named)))" } ?? "")")
                        .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                    if let status = updater.status {
                        Text(status).font(Theme.font(12, .semibold)).foregroundStyle(Theme.accent)
                    }
                }
                Spacer(minLength: 0)
                if updater.isChecking {
                    ProgressView()
                } else {
                    Button("Prüfen") { Task { await updater.update() } }
                        .font(Theme.font(14, .bold))
                        .buttonStyle(.borderless)
                }
            }
            Toggle("Automatisch (wöchentlich)", isOn: $auto)
                .font(Theme.font(14))
        }
        .padding(.vertical, 2)
    }
}

private struct SourceToggle: View {
    let source: SearchSource
    @AppStorage private var on: Bool

    init(source: SearchSource) {
        self.source = source
        _on = AppStorage(wrappedValue: true, source.storageKey)
    }

    var body: some View {
        Toggle(isOn: $on) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: source.icon).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.accent)
                    .frame(width: 32, height: 32).background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.title).font(Theme.font(15, .semibold))
                    Text(source.detail).font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.vertical, 2)
        }
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
    @AppStorage(AITask.photo.providerKey) private var photoProvider = VisionProvider.apple.rawValue
    @AppStorage(AITask.day.providerKey) private var dayProvider = ""

    /// Providers that are in use and need a key.
    private var keyProviders: [VisionProvider] {
        let used = [AITask.photo.provider, AITask.day.provider]
        return VisionProvider.allCases.filter { p in p.needsKey && used.contains(p) }
    }

    var body: some View {
        Form {
            TaskSection(task: .photo, selection: $photoProvider)
            TaskSection(task: .day, selection: $dayProvider)

            ForEach(keyProviders) { p in
                ProviderKeySection(provider: p).id(p)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("KI-Modelle")
    }
}

/// Provider + model choice for one task.
private struct TaskSection: View {
    let task: AITask
    @Binding var selection: String

    private var current: VisionProvider { VisionProvider(rawValue: selection) ?? task.provider }
    private var follows: Bool { task == .day && VisionProvider(rawValue: selection) == nil }

    var body: some View {
        Section {
            if task == .day {
                row(icon: "link", title: "Wie Foto-Erkennung", note: "\(AITask.photo.provider.name) · \(modelLabel(AITask.photo.provider, .photo))", selected: follows) {
                    selection = ""
                }
            }
            ForEach(VisionProvider.allCases) { p in
                row(icon: p.icon, title: p.name, note: p.costNote, selected: !follows && current == p) {
                    selection = p.rawValue
                }
            }
            if !follows, current != .apple {
                ModelPicker(task: task, provider: current).id("\(task.rawValue)-\(current.rawValue)")
            }
        } header: { Text(task.title) } footer: {
            Text(task == .photo
                 ? "Erkennt Gerichte auf Fotos und schätzt Mengen und Nährwerte. Apple Intelligence läuft komplett auf deinem iPhone; klappt das mal nicht, erkennt Apples Bilderkennung zumindest die Hauptbestandteile."
                 : "Ergänzt beim Abschließen eines Tages fehlende Mikronährstoffe und schreibt das Tagesfazit – auch bei der nächtlichen Analyse. Text ohne Bild, daher meist günstiger als die Foto-Erkennung.")
        }
        .listRowBackground(Theme.card)
    }

    private func modelLabel(_ p: VisionProvider, _ t: AITask) -> String {
        p == .apple ? "auf dem iPhone" : t.model(for: p)
    }

    private func row(icon: String, title: String, note: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.snappy) { action() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.accent)
                    .frame(width: 32, height: 32).background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.font(16, .semibold)).foregroundStyle(Theme.textPrimary)
                    Text(note).font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20)).foregroundStyle(selected ? Theme.accent : Theme.line)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Model for one task and provider: menu with common models + free text.
private struct ModelPicker: View {
    let task: AITask
    let provider: VisionProvider
    @AppStorage private var model: String

    init(task: AITask, provider: VisionProvider) {
        self.task = task
        self.provider = provider
        _model = AppStorage(wrappedValue: "", task.modelKey(provider))
    }

    private var placeholder: String {
        task == .day ? AITask.photo.model(for: provider) : provider.defaultModel
    }

    var body: some View {
        HStack {
            Text("Modell")
            TextField(placeholder, text: $model)
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .foregroundStyle(Theme.textSecondary)
            if !provider.suggestedModels.isEmpty {
                Menu {
                    ForEach(provider.suggestedModels, id: \.self) { m in
                        Button { model = m } label: {
                            if task.model(for: provider) == m { Label(m, systemImage: "checkmark") } else { Text(m) }
                        }
                    }
                    if !model.isEmpty {
                        Divider()
                        Button("Standard (\(placeholder))") { model = "" }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 13, weight: .semibold))
                }
            }
        }
    }
}

private struct ProviderKeySection: View {
    let provider: VisionProvider
    @State private var key: String

    init(provider: VisionProvider) {
        self.provider = provider
        _key = State(initialValue: provider.apiKey)
    }

    var body: some View {
        Section {
            SecureField("API-Schlüssel", text: $key)
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: key) { _, v in Keychain.set(provider.keychainKey, v.trimmingCharacters(in: .whitespacesAndNewlines)) }
            if let url = provider.keyURL {
                Link(destination: url) { Label("Schlüssel erstellen", systemImage: "arrow.up.right.square") }
            }
        } header: { Text("Schlüssel · \(provider.name)") } footer: {
            Text(key.isEmpty ? "Ohne Schlüssel kann \(provider.name) nicht genutzt werden." :
                    "Der Schlüssel liegt sicher in der Keychain dieses iPhones und gilt für alle Aufgaben mit \(provider.name).")
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
                SliderField(title: goals.weekdayEnabled ? "Standard-Kalorienziel" : "Kalorienziel", value: $goals.kcal, range: 1000...5000, step: 10, unit: "kcal")
                    .onChange(of: goals.kcal) { _, _ in goals.syncMacros() }
            } footer: {
                Text("Änderungen gelten ab heute – vergangene Tage behalten das Ziel, das damals galt. Tipp: Zahl antippen und direkt eintippen.")
            }
            .listRowBackground(Theme.card)

            WeekdayGoalsSection()

            ActivityGoalSection()

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

/// Own calorie goal per weekday (e.g. more on training days or at the weekend).
private struct WeekdayGoalsSection: View {
    @EnvironmentObject private var goals: Goals
    /// Monday first.
    private let weekdays = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: { goals.weekdayEnabled }, set: { on in
                if on {
                    var dict = goals.weekdayKcal
                    for wd in weekdays where dict[wd] == nil { dict[wd] = goals.kcal }
                    goals.weekdayKcal = dict
                }
                withAnimation(.snappy) { goals.weekdayEnabled = on }
            })) { Label("Ziel pro Wochentag", systemImage: "calendar.badge.clock") }
            if goals.weekdayEnabled {
                ForEach(weekdays, id: \.self) { wd in
                    SliderField(title: Calendar.current.weekdaySymbols[wd - 1],
                                value: Binding(get: { goals.kcal(forWeekday: wd) }, set: { goals.setKcal($0, forWeekday: wd) }),
                                range: 1000...5000, step: 10, unit: "kcal")
                }
                Button("Alle auf \(goals.kcal.kcalString) kcal zurücksetzen") {
                    goals.weekdayKcal = Dictionary(uniqueKeysWithValues: weekdays.map { ($0, goals.kcal) })
                }
                .font(Theme.font(14, .semibold))
            }
        } footer: {
            Text(goals.weekdayEnabled
                 ? "Protein bleibt an jedem Tag gleich, Kohlenhydrate und Fett gleichen den Unterschied aus."
                 : "Zum Beispiel mehr an Trainingstagen oder am Wochenende.")
        }
        .listRowBackground(Theme.card)
    }
}

/// Active energy from Apple Health – shown on Today and optionally added to the goal.
private struct ActivityGoalSection: View {
    @EnvironmentObject private var goals: Goals
    @Environment(\.modelContext) private var ctx
    @State private var todayActive: Double = ActivityStore.kcal(for: .now)
    @State private var failed = false

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: { goals.activityEnabled }, set: { on in
                withAnimation(.snappy) { goals.activityEnabled = on }
                guard on else { return }
                Task {
                    do { try await ActivityStore.requestAuthorization() } catch { failed = true }
                    await ActivityStore.refresh()
                    todayActive = ActivityStore.kcal(for: .now)
                    goals.activityUpdated()
                    WidgetBridge.update(ctx, goals: goals)
                }
            })) { Label("Aktivitätskalorien", systemImage: "flame.fill") }
            if goals.activityEnabled {
                LabeledContent("Heute laut Apple Health", value: "\(todayActive.kcalString) kcal")
                SliderField(title: "Aufs Ziel anrechnen", value: $goals.activityPercent, range: 0...100, step: 5, unit: "%")
                if goals.activityPercent > 0 {
                    LabeledContent("Heute dazu", value: "+\((todayActive * goals.activityPercent / 100).kcalString) kcal")
                        .foregroundStyle(Theme.accent)
                }
                if failed {
                    Text("Kein Zugriff auf Apple Health – in der Health-App unter Teilen → Apps → Purrtion erlauben.")
                        .font(Theme.font(12)).foregroundStyle(Theme.danger)
                }
            }
        } header: { Text("Aktivität (Apple Health)") } footer: {
            Text(goals.activityEnabled
                 ? "0 % zeigt die Kalorien nur an. Sonst steigt dein Tagesziel um diesen Anteil deiner aktiven Kalorien (Fitness-Ringe). Uhren überschätzen den Verbrauch oft – 50–75 % ist ein guter Kompromiss. Dein Grundumsatz ist im Kalorienziel schon enthalten. Manuell eingetragene Aktivität (Heute → oberste Karte antippen) zählt mit demselben Anteil."
                 : "Zeigt deine aktiven Kalorien aus Apple Health (z. B. Apple Watch) auf der Heute-Seite – auf Wunsch werden sie aufs Ziel angerechnet.")
        }
        .listRowBackground(Theme.card)
        .task {
            guard goals.activityEnabled else { return }
            await ActivityStore.refresh()
            todayActive = ActivityStore.kcal(for: .now)
            goals.activityUpdated()
        }
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
    // Edited as a draft – nothing changes until "Profil speichern" or "Als Ziel übernehmen".
    @State private var sex: Goals.Sex = .female
    @State private var age: Double = 28
    @State private var height: Double = 170
    @State private var weight: Double = 68
    @State private var activity: Goals.Activity = .light
    @State private var target: Goals.Target = .maintain
    @State private var loaded = false
    @State private var saved = false

    private var bmr: Double { 10 * weight + 6.25 * height - 5 * age + (sex == .male ? 5 : -161) }
    private var tdee: Double { bmr * activity.factor }
    private var suggested: Double { (max(1200, tdee + target.delta) / 10).rounded() * 10 }
    private var changed: Bool {
        sex != goals.sex || Int(age) != goals.age || height != goals.heightCM || weight != goals.weightKG
            || activity != goals.activity || target != goals.target
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    CatMascot(mood: .happy, pixel: 3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Profil anlegen").font(Theme.font(18, .bold)).foregroundStyle(Theme.textPrimary)
                        Text("Hier legst du deine Körperdaten an. Daraus berechnet Purrtion deinen Bedarf – das Kalorienziel änderst du nur, wenn du es übernimmst.")
                            .font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Theme.card)

            Section {
                Picker("Geschlecht", selection: $sex) {
                    ForEach(Goals.Sex.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                SliderField(title: "Alter", value: $age, range: 14...90, unit: "Jahre")
                SliderField(title: "Größe", value: $height, range: 140...210, unit: "cm")
                SliderField(title: "Gewicht", value: $weight, range: 40...180, step: 0.5, unit: "kg", decimals: 1, stepper: true)
            } header: { Text("Über dich") } footer: {
                Text("Wird für Grundumsatz, echten Verbrauch und Promille-Schätzung genutzt. Zahl antippen zum direkten Eintippen.")
            }
            .listRowBackground(Theme.card)

            Section {
                Picker("Aktivität", selection: $activity) {
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
                Picker("Ziel", selection: $target) {
                    ForEach(Goals.Target.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
            } header: { Text("Ziel") }
            .listRowBackground(Theme.card)

            Section {
                LabeledContent("Grundumsatz", value: "\(bmr.kcalString) kcal")
                LabeledContent("Gesamtbedarf", value: "\(tdee.kcalString) kcal")
                LabeledContent("Empfohlenes Ziel", value: "\(suggested.kcalString) kcal")
                    .fontWeight(.bold)
                LabeledContent("Dein aktuelles Ziel", value: "\(goals.kcal.kcalString) kcal")
                Button {
                    store()
                    goals.applySuggestion()
                    Haptics.success()
                    saved = true
                    onApply?()
                } label: {
                    Text("Als Ziel übernehmen").frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle())
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 4, trailing: 12))
                if onApply == nil {
                    Button {
                        store()
                        Haptics.success()
                        withAnimation(.snappy) { saved = true }
                    } label: {
                        Label(saved && !changed ? "Profil gespeichert" : "Nur Profil speichern",
                              systemImage: saved && !changed ? "checkmark" : "person.crop.circle.badge.checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PillButtonStyle(filled: false))
                    .disabled(!changed)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 8, trailing: 12))
                }
            } header: { Text("Bedarf") } footer: {
                if onApply == nil {
                    Text("„Nur Profil speichern“ übernimmt deine Angaben, ohne das Kalorienziel zu ändern.")
                }
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Dein Profil")
        .keyboardDoneButton()
        .onAppear {
            guard !loaded else { return }
            loaded = true
            sex = goals.sex; age = Double(goals.age); height = goals.heightCM; weight = goals.weightKG
            activity = goals.activity; target = goals.target
        }
    }

    private func store() {
        goals.sex = sex
        goals.age = Int(age.rounded())
        goals.heightCM = height
        goals.weightKG = weight
        goals.activity = activity
        goals.target = target
    }
}

struct OnboardingView: View {
    @EnvironmentObject private var goals: Goals
    #if DEBUG
    @State private var page = UserDefaults.standard.string(forKey: "debugStep") == nil ? 0 : 1
    #else
    @State private var page = 0
    #endif

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
                    OnboardingSetup { goals.onboarded = true }
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
