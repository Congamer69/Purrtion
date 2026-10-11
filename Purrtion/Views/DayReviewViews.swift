import SwiftUI
import SwiftData

/// Compact verdict card on Today, shown once the day was closed.
struct DayReviewCard: View {
    let review: DayReview
    let outdated: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(review.color)
                .frame(width: 46, height: 46)
                .background(review.color.opacity(0.16), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Tagesfazit").font(Theme.font(13, .semibold)).foregroundStyle(Theme.textSecondary)
                    if outdated {
                        Text("veraltet").font(Theme.font(10, .bold)).foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.cardAlt, in: Capsule())
                    }
                }
                Text(review.rating).font(Theme.font(20, .heavy)).foregroundStyle(review.color).lineLimit(1)
                if let first = review.points.first {
                    Text(first).font(Theme.font(12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.textSecondary)
        }
        .card(padding: 14)
    }
}

/// "Tag abschließen" at the end of the list.
struct DayCloseRow: View {
    let hasReview: Bool
    let outdated: Bool
    let running: Bool
    let action: () -> Void

    var body: some View {
        if running {
            VStack(spacing: 6) {
                WalkingCatLoader(pixel: 2.4, width: 220, text: "Rechne den Tag nach …")
                Text("Mikronährstoffe ergänzen und Tag einordnen").font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        } else if hasReview && !outdated {
            Button(action: action) {
                Label("Tag abgeschlossen · neu bewerten", systemImage: "checkmark.seal.fill")
                    .font(Theme.font(13, .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(SquishButtonStyle())
        } else {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: outdated ? "arrow.triangle.2.circlepath" : "sparkles")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Theme.accent, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(outdated ? "Tag geändert – neu abschließen" : "Tag abschließen")
                            .font(Theme.font(16, .bold)).foregroundStyle(Theme.textPrimary)
                        Text("KI ergänzt fehlende Mikronährstoffe und ordnet deinen Tag ein")
                            .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.accent)
                }
                .padding(14)
                .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: Theme.radiusSmall + 4, style: .continuous))
            }
            .buttonStyle(SquishButtonStyle())
        }
    }
}

/// Details of the verdict, with the option to evaluate again.
struct DayReviewSheet: View {
    let review: DayReview
    @EnvironmentObject private var goals: Goals
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var running = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 8) {
                        CatMascot(mood: review.mood, pixel: 4)
                        Text(review.rating).font(Theme.font(28, .heavy)).foregroundStyle(review.color)
                            .multilineTextAlignment(.center)
                        Text(review.day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .card(padding: 20)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Einordnung").font(Theme.font(17, .bold)).foregroundStyle(Theme.textPrimary)
                        ForEach(Array(review.points.enumerated()), id: \.offset) { _, point in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Circle().fill(review.color).frame(width: 7, height: 7).offset(y: -2)
                                Text(point).font(Theme.font(15)).foregroundStyle(Theme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()

                    VStack(alignment: .leading, spacing: 8) {
                        if let score = review.score {
                            if let before = review.scoreBefore, before != score {
                                info("heart.text.square", "Health Score: \(before) → \(score) durch KI-ergänzte Mikronährstoffe")
                            } else {
                                info("heart.text.square", "Health Score beim Abschluss: \(score)/100")
                            }
                        }
                        info("leaf", review.enrichedCount == 0
                             ? "Alle Lebensmittel hatten bereits vollständige Mikronährstoffe."
                             : "\(review.enrichedCount) Lebensmittel um fehlende Mikronährstoffe ergänzt (KI-Schätzung).")
                        info(review.automatic ? "moon.stars" : "sparkles",
                             "\(review.automatic ? "Automatisch über Nacht bewertet" : "Bewertet") mit \(review.providerName) · \(review.createdAt.formatted(date: .abbreviated, time: .shortened)) Uhr")
                        Text("KI-Einschätzung, ersetzt keine Ernährungsberatung.")
                            .font(Theme.font(11)).foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()

                    if running {
                        WalkingCatLoader(pixel: 2.4, width: 220, text: "Bewerte neu …").padding(.top, 4)
                    } else {
                        Button { Task { await redo() } } label: {
                            Label("Neu bewerten", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(PillButtonStyle(filled: false))
                    }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Tagesfazit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .alert("Bewertung fehlgeschlagen", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(error ?? "") }
        }
        .presentationDetents([.medium, .large])
    }

    private func info(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon).font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
    }

    private func redo() async {
        running = true
        defer { running = false }
        do {
            _ = try await DayCloser.close(day: review.day, goals: goals, ctx: ctx)
            Haptics.success()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
