import Foundation

/// Watch display names: full names ("Alexander Montgomery") break the
/// fixed watch layout, so the wrist shows the first name only ("Alexander").
/// Pure logic — unit-tested headlessly. Pickers/lists keep full names so
/// "Alexander Montgomery" stays distinguishable from "Alexander Smith".
func watchDisplayName(_ fullName: String) -> String {
    let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let space = trimmed.firstIndex(of: " ") else { return trimmed }
    let first = String(trimmed[..<space])
    return first.isEmpty ? trimmed : first
}
