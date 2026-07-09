import SwiftUI

/// Sheet view for selecting sound mode and which sounds to use.
struct SoundPickerView: View {
    @ObservedObject var soundManager: SoundManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                // Mode picker
                Section("Playback Mode") {
                    Picker("Mode", selection: $soundManager.mode) {
                        ForEach(SoundMode.allCases) { mode in
                            VStack(alignment: .leading) {
                                Text(mode.displayName)
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                // Sound selection
                Section("Sounds") {
                    if soundManager.availableSounds.isEmpty {
                        Text("No sounds found. Add .mp3 or .wav files to the app bundle.")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(soundManager.availableSounds) { sound in
                            HStack {
                                // Checkbox for active set
                                Image(systemName: soundManager.selectedSounds.contains(sound.id)
                                      ? "checkmark.circle.fill"
                                      : "circle")
                                    .foregroundColor(soundManager.selectedSounds.contains(sound.id)
                                                     ? .green : .gray)
                                    .onTapGesture {
                                        toggleSound(sound.id)
                                    }

                                Text(sound.name)

                                Spacer()

                                // Star for primary (single mode)
                                if soundManager.mode == .single {
                                    Image(systemName: soundManager.primarySound == sound.id
                                          ? "star.fill"
                                          : "star")
                                        .foregroundColor(.orange)
                                        .onTapGesture {
                                            soundManager.primarySound = sound.id
                                        }
                                }

                                // Preview button
                                Button {
                                    previewSound(sound)
                                } label: {
                                    Image(systemName: "play.circle")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sounds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func toggleSound(_ id: String) {
        if soundManager.selectedSounds.contains(id) {
            soundManager.selectedSounds.remove(id)
        } else {
            soundManager.selectedSounds.insert(id)
        }
    }

    private func previewSound(_ sound: SoundManager.SoundFile) {
        // Temporarily play this sound for preview
        if let player = try? AVAudioPlayer(contentsOf: sound.url) {
            player.play()
        }
    }
}

import AVFoundation
