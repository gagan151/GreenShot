import AVFoundation
import Foundation

/// Manages sound effect playback with three modes: single, cycle, random.
/// Audio session is set to `.playback` so sounds route to Bluetooth speakers
/// and play even when the phone is on silent mode.
final class SoundManager: ObservableObject {

    @Published var mode: SoundMode = .single
    @Published var availableSounds: [SoundFile] = []
    @Published var selectedSounds: Set<String> = [] // IDs of sounds in the active set
    @Published var primarySound: String? = nil       // ID for single mode

    private var players: [String: AVAudioPlayer] = [:]
    private var cycleIndex = 0

    struct SoundFile: Identifiable, Hashable {
        let id: String    // filename without extension
        let url: URL
        let name: String  // display name
    }

    init() {
        configureAudioSession()
        loadBundledSounds()
    }

    // MARK: - Public

    /// Play the next sound based on the current mode.
    func playShot() {
        let activeSounds = availableSounds.filter { selectedSounds.contains($0.id) }

        guard !activeSounds.isEmpty else {
            // Fallback: play any available sound
            if let first = availableSounds.first {
                play(first)
            }
            return
        }

        switch mode {
        case .single:
            if let primary = primarySound,
               let sound = activeSounds.first(where: { $0.id == primary }) {
                play(sound)
            } else if let first = activeSounds.first {
                play(first)
            }

        case .cycle:
            let index = cycleIndex % activeSounds.count
            play(activeSounds[index])
            cycleIndex += 1

        case .random:
            if let sound = activeSounds.randomElement() {
                play(sound)
            }
        }
    }

    // MARK: - Private

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .playback routes to Bluetooth and plays on silent mode
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("[SoundManager] Failed to configure audio session: \(error)")
        }
    }

    private func loadBundledSounds() {
        // Look for sound files in the Sounds directory of the bundle
        let extensions = ["mp3", "wav", "m4a", "aif", "caf"]
        var sounds: [SoundFile] = []

        for ext in extensions {
            if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: "Sounds") {
                for url in urls {
                    let id = url.deletingPathExtension().lastPathComponent
                    let name = id.replacingOccurrences(of: "_", with: " ").capitalized
                    sounds.append(SoundFile(id: id, url: url, name: name))
                }
            }

            // Also check root bundle (sounds not in subdirectory)
            if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                for url in urls {
                    let id = url.deletingPathExtension().lastPathComponent
                    // Skip if already added from Sounds subdirectory
                    guard !sounds.contains(where: { $0.id == id }) else { continue }
                    let name = id.replacingOccurrences(of: "_", with: " ").capitalized
                    sounds.append(SoundFile(id: id, url: url, name: name))
                }
            }
        }

        availableSounds = sounds.sorted { $0.name < $1.name }

        // Auto-select all sounds and set the first as primary
        selectedSounds = Set(sounds.map { $0.id })
        primarySound = sounds.first?.id

        print("[SoundManager] Loaded \(sounds.count) sound(s)")
    }

    private func play(_ sound: SoundFile) {
        // Reuse or create player
        if let existing = players[sound.id] {
            existing.currentTime = 0
            existing.play()
        } else {
            do {
                let player = try AVAudioPlayer(contentsOf: sound.url)
                player.prepareToPlay()
                player.play()
                players[sound.id] = player
            } catch {
                print("[SoundManager] Failed to play \(sound.name): \(error)")
            }
        }
    }
}
