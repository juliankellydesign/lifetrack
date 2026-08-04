import AVFoundation

final class AppSoundPlayer {
  enum Effect: String, CaseIterable {
    case increment = "ns_button_1"
    case decrement = "ns_button_2"
    case button = "ns_button_3"
    case lighthouseLanding = "tonehigh"
    case lighthouseSpin = "ns_button_5"
    case layoutSelection = "tonelow"
    case commanderTransition = "short"
    case editTransition = "long"
  }

  static let shared = AppSoundPlayer()
  static let modeEntryPitchShift: Float = 200

  private struct Voice {
    var player = AVAudioPlayerNode()
    var pitchControl = AVAudioUnitTimePitch()
  }

  private struct LoadedSound {
    var buffer: AVAudioPCMBuffer
    var voices: [Voice]
    var nextVoiceIndex = 0
  }

  private static let voiceCount = 4

  private let engine = AVAudioEngine()
  private var sounds: [Effect: LoadedSound] = [:]

  private init() {
    configureAudioSession()
    loadSounds()
    engine.prepare()
    try? engine.start()
  }

  func prepare() {}

  func play(_ effect: Effect, pitch: Float = 0) {
    guard var sound = sounds[effect], !sound.voices.isEmpty else { return }
    if !engine.isRunning {
      try? engine.start()
    }

    let voice = sound.voices[sound.nextVoiceIndex]
    voice.player.stop()
    voice.pitchControl.pitch = min(2_400, max(-2_400, pitch))
    voice.player.scheduleBuffer(sound.buffer)
    voice.player.play()

    sound.nextVoiceIndex = (sound.nextVoiceIndex + 1) % sound.voices.count
    sounds[effect] = sound
  }

  func stop(_ effect: Effect) {
    sounds[effect]?.voices.forEach { $0.player.stop() }
  }

  private func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
    try? session.setActive(true)
  }

  private func loadSounds() {
    for effect in Effect.allCases {
      guard
        let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav"),
        let file = try? AVAudioFile(forReading: url),
        let buffer = AVAudioPCMBuffer(
          pcmFormat: file.processingFormat,
          frameCapacity: AVAudioFrameCount(file.length)
        )
      else { continue }

      do {
        try file.read(into: buffer)
      } catch {
        continue
      }

      let voices = (0..<Self.voiceCount).map { _ in
        let voice = Voice()
        engine.attach(voice.player)
        engine.attach(voice.pitchControl)
        engine.connect(voice.player, to: voice.pitchControl, format: buffer.format)
        engine.connect(voice.pitchControl, to: engine.mainMixerNode, format: buffer.format)
        return voice
      }
      sounds[effect] = LoadedSound(buffer: buffer, voices: voices)
    }
  }
}
