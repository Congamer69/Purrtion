import SwiftUI

/// Profil → Darstellung. Its own view so it re-renders as soon as a look-and-feel setting changes.
struct AppearanceSettingsView: View {
    @AppStorage("catPalette") private var paletteID = CatPalette.ginger.id
    @AppStorage("appearance") private var appearance = Appearance.system
    @AppStorage("profile.name") private var profileName = ""
    @AppStorage(ThemeSetting.accentKey) private var accent = ThemeAccent.orange
    @AppStorage(ThemeSetting.customKey) private var customColorHex = ""
    @AppStorage(ThemeSetting.cornersKey) private var corners = ThemeCorners.normal
    @AppStorage(ThemeSetting.cardsKey) private var cardStyle = ThemeCards.shadow
    @AppStorage(ThemeSetting.backgroundKey) private var backgroundTone = ThemeBackground.warm
    @AppStorage(ThemeSetting.fontKey) private var fontStyle = ThemeFont.rounded
    @Environment(\.colorScheme) private var scheme
    @AppStorage("startTab") private var startTab = 0
    @AppStorage(Haptics.enabledKey) private var haptics = true

    var body: some View {
        Form { appearanceSection }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Darstellung")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .animation(Motion.smooth, value: corners)
            .animation(Motion.smooth, value: cardStyle)
            .animation(Motion.smooth, value: backgroundTone)
            .animation(Motion.smooth, value: accent)
    }

    /// The last swatch: a rainbow circle (the picked colour once chosen) that opens the system colour wheel.
    private var customSwatch: some View {
        let on = accent == .custom
        let binding = Binding<Color>(
            get: { Color(hex: ThemeSetting.customHex) },
            set: { color in
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
                customColorHex = String(format: "%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
                accent = .custom
            })
        return Circle()
            .fill(on ? AnyShapeStyle(Color(hex: ThemeSetting.customHex)) : AnyShapeStyle(AngularGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red], center: .center)))
            .frame(height: 40)
            .overlay { if on { Image(systemName: "checkmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white) } }
            .overlay(Circle().stroke(Theme.textPrimary.opacity(on ? 0.9 : 0), lineWidth: 2).padding(-4))
            // The system colour picker sits invisibly on top, so a tap anywhere on the circle opens the wheel.
            .overlay { ColorPicker("Eigene Farbe", selection: binding, supportsOpacity: false).labelsHidden().scaleEffect(1.7).opacity(0.02) }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Eigene Farbe")
    }

    /// A small Today screen built from the real card styles, so every choice below is visible right here.
    private var themePreview: some View {
        VStack(spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle().stroke(Theme.accentSoft, lineWidth: 10)
                        Circle().trim(from: 0, to: 0.72).stroke(Theme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
                        CatMascot(mood: .happy, pixel: 2.4)
                    }
                    .frame(width: 84, height: 84)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profileName.isEmpty ? "Heute" : "Hallo, \(profileName)").font(Theme.font(14)).foregroundStyle(Theme.textSecondary)
                        Text("601").font(Theme.font(38, .heavy)).foregroundStyle(Theme.textPrimary)
                        Text("kcal übrig").font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 8) {
                    Label("12", systemImage: "flame.fill").font(Theme.font(12, .bold)).foregroundStyle(Theme.accentText)
                        .padding(.horizontal, 10).padding(.vertical, 6).background(Theme.accentSoft, in: Capsule())
                    Spacer(minLength: 0)
                    Text("Suchen").font(Theme.font(14, .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 8).background(Theme.accent, in: Capsule())
                }
            }
            .card(padding: 18)

            HStack(spacing: Theme.Space.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Skyr mit Beeren").font(Theme.font(16, .bold)).foregroundStyle(Theme.textPrimary)
                    Text("250 g · 12:40").font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                Text("210").font(Theme.font(18, .bold)).foregroundStyle(Theme.textPrimary)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radiusSmall + 4, style: .continuous))
            .overlay {
                if cardStyle == .outline {
                    RoundedRectangle(cornerRadius: Theme.radiusSmall + 4, style: .continuous).stroke(Theme.line, lineWidth: 1.5)
                }
            }
            .shadow(color: Theme.cardShadow, radius: 10, y: 4)
        }
        .padding(Theme.Space.m)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: Theme.radius + 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius + 6, style: .continuous).stroke(Theme.textSecondary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
    }

    @ViewBuilder private var appearanceSection: some View {
        Section { themePreview.padding(.horizontal, Theme.Space.l).padding(.vertical, Theme.Space.s) }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

        Section {
            TextField("Dein Name (optional)", text: $profileName).textContentType(.givenName)
        } header: { Text("Du") } footer: { Text("Erscheint in der Begrüßung auf „Heute“ und im Profil.") }
        .listRowBackground(Theme.card)

        Section {
            HStack(spacing: 12) {
                ForEach(ThemeAccent.allCases) { a in
                    if a == .custom {
                        customSwatch
                    } else {
                        Button {
                            Haptics.tap()
                            withAnimation(Motion.playful) { accent = a }
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
            }
            .padding(.vertical, 6)
        } header: { Text("Akzentfarbe") } footer: { Text("Der letzte Kreis öffnet ein Farbrad für eine eigene Farbe.") }
        .listRowBackground(Theme.card)

                Section {
                    HStack(spacing: 16) {
                        // The dog is a secret and never listed; while it is active no cat is selected.
                        ForEach(CatPalette.all) { p in
                            Button {
                                Haptics.tap()
                                withAnimation(Motion.playful) { paletteID = p.id }
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
                } header: { Text(paletteID == CatPalette.dog.id ? "Dein Hund & Look" : "Deine Katze & Look") }
                .listRowBackground(Theme.card)

        Section {
            Picker("Ecken", selection: $corners) { ForEach(ThemeCorners.allCases) { Text($0.name).tag($0) } }
            Picker("Karten", selection: $cardStyle) { ForEach(ThemeCards.allCases) { Text($0.name).tag($0) } }
            Picker("Hintergrund", selection: $backgroundTone) {
                ForEach(ThemeBackground.allCases) { Text($0 == .black ? (scheme == .dark ? "Schwarz" : "Weiß") : $0.name).tag($0) }
            }
            Picker("Schrift", selection: $fontStyle) { ForEach(ThemeFont.allCases) { Text($0.name).tag($0) } }
            Button("Auf Standard zurücksetzen") {
                accent = .orange; customColorHex = ""; corners = .normal; cardStyle = .shadow; backgroundTone = .warm; fontStyle = .rounded
            }
        } header: { Text("Stil") }
        .listRowBackground(Theme.card)

        Section {
            Picker("Startseite", selection: $startTab) {
                Text("Heute").tag(0)
                Text("Verlauf").tag(1)
            }
            Toggle("Haptisches Feedback", isOn: $haptics)
        } header: { Text("Verhalten") } footer: {
            Text("Die Startseite gilt beim nächsten Öffnen der App.")
        }
        .listRowBackground(Theme.card)
    }
}
