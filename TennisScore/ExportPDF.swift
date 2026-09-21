import SwiftUI
import UIKit

// MARK: - PDF Rendering (UIKit, Letter page, single-pass text layout)

extension ExportManager {
    /// Renders the export data map as a professional single/multi-page PDF.
    /// Pure CPU work — call from a background task.
    nonisolated static func pdfData(_ s: MatchExportSnapshot) -> Data {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 56
            let left: CGFloat = 48
            let width = page.width - 96
            let bottomLimit = page.height - 64
            
            func draw(_ string: String, font: UIFont, color: UIColor = .black, gap: CGFloat = 6) {
                if y > bottomLimit {
                    context.beginPage()
                    y = 56
                }
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let text = string as NSString
                let height = text.boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes, context: nil
                ).height
                text.draw(
                    with: CGRect(x: left, y: y, width: width, height: height),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes, context: nil
                )
                y += height + gap
            }
            
            let title = UIFont.boldSystemFont(ofSize: 20)
            let heading = UIFont.boldSystemFont(ofSize: 13)
            let body = UIFont.systemFont(ofSize: 11)
            let gray = UIColor(white: 0.35, alpha: 1.0)
            
            draw("TENNIS MATCH SUMMARY", font: title, gap: 10)
            draw("Date: \(s.dateLine)", font: body, color: gray, gap: 2)
            draw("Location: \(s.location)", font: body, color: gray, gap: 2)
            draw("Winner: \(s.winnerName.isEmpty ? "TBD" : s.winnerName)", font: heading, gap: 2)
            draw("FINAL SCORE: \(s.setScores.isEmpty ? "—" : s.setScores) (\(s.setsLine))", font: heading, gap: 10)
            
            draw("STATISTICS", font: heading, gap: 4)
            for row in [s.p1, s.p2] {
                draw("\(row.name): Aces \(row.aces), Winners \(row.winners), Unforced Errors \(row.unforcedErrors), Forced Errors \(row.forcedErrors)", font: body, gap: 2)
            }
            
            draw("NOTES", font: heading, gap: 4)
            if s.notes.isEmpty {
                draw("No notes recorded", font: body, color: gray)
            } else {
                for note in s.notes {
                    draw("• \(note.player): \(note.text)", font: body, gap: 3)
                }
            }
            
            draw("Shared from Vantage", font: body, color: gray, gap: 0)
        }
    }
    
    /// Full pipeline: snapshot on the caller (MainActor), render + write +
    /// verify off-main. Returns only a verified-nonempty file URL.
    @MainActor
    static func prepareShare(for match: Match) async throws -> URL {
        let snapshot = MatchExportSnapshot(match)
        return try await Task.detached(priority: .userInitiated) {
            let data = ExportManager.pdfData(snapshot)
            return try ExportManager.writeVerifiedPDF(data: data, id: snapshot.id)
        }.value
    }
}

// MARK: - Shared PDF share button (verify-before-share in one place)

/// Shows a progress state while rendering, then opens the share sheet ONLY
/// with a verified-nonempty PDF. Failures reset silently (sheet never opens).
struct PDFShareButton<Label: View>: View {
    let match: Match
    let label: () -> Label
    
    @State private var shareURL: URL?
    @State private var isPreparing = false
    @State private var showingShare = false
    
    var body: some View {
        Button(action: prepare) {
            if isPreparing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Preparing PDF…")
                        .font(DesignSystem.Typography.labelLarge)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
            } else {
                label()
            }
        }
        .disabled(isPreparing)
        .sheet(isPresented: $showingShare) {
            if let shareURL {
                ShareSheet(activityItems: [shareURL])
            }
        }
    }
    
    private func prepare() {
        guard !isPreparing else { return }
        isPreparing = true
        Task {
            do {
                let url = try await ExportManager.prepareShare(for: match)
                await MainActor.run {
                    self.shareURL = url
                    self.isPreparing = false
                    self.showingShare = true
                }
            } catch {
                await MainActor.run { self.isPreparing = false }
                print("PDF export failed: \(error.localizedDescription)")
            }
        }
    }
}
