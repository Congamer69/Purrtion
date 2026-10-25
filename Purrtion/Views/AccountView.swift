import SwiftUI
import SwiftData

/// Einstellungen → Konto: the server, the Google login and the server backup in one place.
struct AccountView: View {
    @Environment(\.modelContext) private var ctx
    @ObservedObject private var account = ServerAccount.shared
    @AppStorage(FirebaseConfig.storageKey) private var serverCode = ""
    @AppStorage(ServerAccount.emailKey) private var email = ""
    @State private var confirmRestore = false
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var shareServer = false

    var body: some View {
        Form {
            if !FirebaseConfig.isAvailable {
                ServerConnectSection()
            } else {
                serverSection
                if account.isLinked { linkedSection } else { signInSection }
            }
            if let status = account.status {
                Section { Text(status).foregroundStyle(Theme.accentText) }.listRowBackground(Theme.card)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Konto")
        .navigationBarTitleDisplayMode(.inline)
        .task { await account.refreshRemote() }
        .sheet(isPresented: $shareServer) {
            ShareSheet(items: ["Mit diesem Code verbindest du Purrtion mit unserem Server (Einstellungen → Konto):\n\n\(FirebaseConfig.code ?? "")"])
        }
        .alert("Dieses Google-Konto gibt es schon", isPresented: Binding(get: { account.conflict != nil }, set: { _ in }), presenting: account.conflict) { c in
            if c.backup != nil {
                Button("Backup laden", role: .destructive) { Task { await account.resolve(c, load: true, ctx: ctx) } }
            } else {
                Button("Mit diesem Konto weitermachen", role: .destructive) { Task { await account.resolve(c, load: true, ctx: ctx) } }
            }
            Button("Abbrechen", role: .cancel) { Task { await account.resolve(c, load: false, ctx: ctx) } }
        } message: { c in
            if let b = c.backup {
                Text("Auf dem Server liegt ein Backup mit \(b.entries) Einträgen vom \(b.updated.formatted(date: .abbreviated, time: .shortened)). Wenn du es lädst, werden alle Daten auf diesem iPhone ersetzt\(c.hadFriends ? " und das Freunde-Profil von diesem iPhone durch das des Google-Kontos" : "").")
            } else {
                Text("Das Freunde-Profil von diesem iPhone wird durch das des Google-Kontos ersetzt. Deine Einträge bleiben.")
            }
        }
        .alert("Server-Backup überschreiben?", isPresented: Binding(get: { account.shrinkWarning != nil }, set: { if !$0 { account.shrinkWarning = nil } }), presenting: account.shrinkWarning) { _ in
            Button("Überschreiben", role: .destructive) { Task { await account.backupNow(ctx, force: true) } }
            Button("Abbrechen", role: .cancel) {}
        } message: { s in
            Text("Auf dem Server liegen \(s.remote) Einträge, auf diesem iPhone nur \(s.local). Wenn du überschreibst, ist das größere Backup weg. Meinst du eher „Backup laden“?")
        }
        .confirmationDialog("Backup laden?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Ersetzen und laden", role: .destructive) { Task { await account.restore(ctx) } }
        } message: { Text("Alle Daten auf diesem iPhone werden durch das Server-Backup ersetzt.") }
        .confirmationDialog("Abmelden?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Abmelden", role: .destructive) { account.signOut() }
        } message: { Text("Deine Daten bleiben auf diesem iPhone. Freunde und Server-Backup sind erst nach der nächsten Anmeldung mit Google wieder da.") }
        .confirmationDialog("Server-Backup löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) { Task { await account.deleteRemote() } }
        } message: { Text("Das Backup wird vom Server entfernt. Deine Daten auf diesem iPhone bleiben.") }
    }

    private var serverSection: some View {
        Section {
            LabeledContent("Server", value: FirebaseConfig.projectID ?? "")
            Button { shareServer = true } label: { Label("Server-Code teilen", systemImage: "square.and.arrow.up") }
        } header: { Text("Server") } footer: {
            Text("Freunde und das Server-Backup laufen über diesen Server. Trennen kannst du ihn unter Einstellungen → Freunde. Das lokale Backup funktioniert auch ohne Server.")
        }
        .listRowBackground(Theme.card)
    }

    private var signInSection: some View {
        Section {
            Button { Task { await account.signIn() } } label: {
                HStack {
                    Label("Mit Google anmelden", systemImage: "person.crop.circle.badge.checkmark")
                    Spacer()
                    if account.busy { ProgressView().tint(Theme.accent) }
                }
            }
            .disabled(account.busy)
        } header: { Text("Google-Konto") } footer: {
            Text("Mit deinem Google-Konto liegen Freunde und Backup auf dem Server. Auf einem neuen Gerät: Server-Code einfügen, mit Google anmelden, alles ist wieder da. Ohne Anmeldung bleibt alles wie bisher.")
        }
        .listRowBackground(Theme.card)
    }

    @ViewBuilder private var linkedSection: some View {
        Section {
            LabeledContent("Angemeldet als", value: email)
            Text("Dein Freunde-Konto gehört zu diesem Google-Konto.").font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
            Button("Abmelden", role: .destructive) { confirmSignOut = true }
        } header: { Text("Google-Konto") }
        .listRowBackground(Theme.card)

        Section {
            Toggle(isOn: Binding(get: { account.autoEnabled }, set: { account.autoEnabled = $0 })) {
                Label("Täglich automatisch sichern", systemImage: "clock.arrow.circlepath")
            }
            Button { Task { await account.backupNow(ctx) } } label: {
                HStack {
                    Label("Jetzt sichern", systemImage: "icloud.and.arrow.up.fill")
                    Spacer()
                    if account.busy { ProgressView().tint(Theme.accent) }
                }
            }
            .disabled(account.busy)
            Button { confirmRestore = true } label: { Label("Backup laden", systemImage: "icloud.and.arrow.down.fill") }
                .disabled(account.busy || account.remote == nil)
            if account.remote != nil {
                Button("Server-Backup löschen", role: .destructive) { confirmDelete = true }.disabled(account.busy)
            }
        } header: { Text("Server-Backup") } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if let r = account.remote {
                    Text("Auf dem Server: \(r.entries) Einträge vom \(r.updated.formatted(date: .abbreviated, time: .shortened)).")
                } else {
                    Text("Noch kein Backup auf dem Server.")
                }
                Text("Gesichert werden Einträge, Rezepte, eigene Lebensmittel, Gewicht und Einstellungen, genau wie im lokalen Backup. Nur dein Google-Konto kommt an die Daten.")
            }
        }
        .listRowBackground(Theme.card)
    }
}
