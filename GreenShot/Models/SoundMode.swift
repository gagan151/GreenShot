import Foundation

enum SoundMode: String, CaseIterable, Identifiable {
    case single
    case cycle
    case random

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .single: return "Single"
        case .cycle: return "Cycle"
        case .random: return "Random"
        }
    }

    var description: String {
        switch self {
        case .single: return "Play the same sound every time"
        case .cycle: return "Cycle through selected sounds in order"
        case .random: return "Pick a random sound each time"
        }
    }
}
