//
//  AudioManager.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 11/07/26.
//

import OSLog
import Foundation
import AVFoundation
import AudioToolbox // Vibracion

/// Contrato de reproducción de la alarma, inyectable para tests.
@MainActor
protocol AlarmPlaying: AnyObject {
    /// Deja la sesión de audio lista mientras la app está en primer plano,
    /// para poder sonar después desde segundo plano.
    func prepare()
    func playAlarm(soundName: String, vibrate: Bool)
    func stopAlarm()
}

@MainActor
final class AudioManager: AlarmPlaying {
    static let shared = AudioManager()

    private var audioPlayer: AVAudioPlayer?
    private var previewPlayer: AVAudioPlayer?
    private var vibrationTask: Task<Void, Never>?
    private var previewStopTask: Task<Void, Never>?
    private var interruptionObserver: NSObjectProtocol?

    /// `true` mientras la alarma debe estar sonando (aunque una llamada la interrumpa).
    private(set) var isAlarmActive = false

    private init() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            MainActor.assumeIsolated {
                self?.handleInterruption(rawType: rawType)
            }
        }
    }

    // MARK: - AlarmPlaying

    /// Se llama en primer plano al iniciar el viaje. La sesión se mezcla con
    /// otras apps: la música del usuario sigue a volumen normal durante el trayecto.
    func prepare() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            Log.audio.error("No se pudo preparar la sesión de audio: \(error.localizedDescription, privacy: .public)")
        }
    }

    func playAlarm(soundName: String, vibrate: Bool) {
        stopAlarm()
        stopPreview()
        isAlarmActive = true

        // La vibración no depende del archivo de audio: si falta, al menos vibra.
        if vibrate { startVibrationLoop() }

        do {
            // Ahora sí bajamos el volumen de otras apps: la alarma debe oírse.
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            Log.audio.error("No se pudo activar la sesión de audio: \(error.localizedDescription, privacy: .public)")
        }

        guard let player = makePlayer(soundName: soundName) else { return }
        player.numberOfLoops = -1
        player.volume = 1.0
        player.play()
        audioPlayer = player
        Log.audio.info("Alarma sonando")
    }

    /// Detiene sonido y vibración siempre, esté o no reproduciéndose el audio
    /// (p. ej. tras una interrupción por llamada).
    func stopAlarm() {
        isAlarmActive = false
        vibrationTask?.cancel()
        vibrationTask = nil

        guard let player = audioPlayer else { return }
        player.stop()
        audioPlayer = nil
        deactivateSession()
    }

    // MARK: - Preview

    /// Reproduce unos segundos de un tono para elegirlo en Ajustes.
    func previewSound(named soundName: String, vibrate: Bool = false, duration: Duration = .seconds(3)) {
        guard !isAlarmActive else { return }
        stopPreview()

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true)

        if vibrate { AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) }
        guard let player = makePlayer(soundName: soundName) else { return }
        player.play()
        previewPlayer = player

        previewStopTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.stopPreview()
        }
    }

    func stopPreview() {
        previewStopTask?.cancel()
        previewStopTask = nil
        guard let player = previewPlayer else { return }
        player.stop()
        previewPlayer = nil
        if !isAlarmActive { deactivateSession() }
    }

    // MARK: - Private

    private func makePlayer(soundName: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") else {
            Log.audio.error("No se encontró el sonido \(soundName, privacy: .public).mp3")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            Log.audio.error("No se pudo cargar el sonido: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            Log.audio.debug("No se pudo desactivar la sesión de audio")
        }
    }

    /// Si una llamada o Siri interrumpe la alarma, la reanudamos al terminar.
    private func handleInterruption(rawType: UInt?) {
        guard let rawType, AVAudioSession.InterruptionType(rawValue: rawType) == .ended,
              isAlarmActive, let player = audioPlayer else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
    }

    private func startVibrationLoop() {
        vibrationTask = Task {
            while !Task.isCancelled {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                try? await Task.sleep(for: .milliseconds(400))
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
