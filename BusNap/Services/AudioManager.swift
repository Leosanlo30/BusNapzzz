//
//  AudioManager.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 11/07/26.
//

import Foundation
import AVFoundation
import AudioToolbox // Vibracion

class AudioManager {
    static let shared = AudioManager()
    private var audioPlayer: AVAudioPlayer?
    private var vibrationTask: Task<Void, Never>?
    private var isVibrating = false
    
    private init() {}
    
    // NUEVA FUNCIÓN: Se llama en primer plano para calentar el motor
    func prepareAudioEngine() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try session.setActive(true)
            print(" Motor de audio encendido en primer plano y listo.")
        } catch {
            print(" Error al preparar la sesión de audio: \(error.localizedDescription)")
        }
    }
    
    func playAlarm() {
        
        do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Aviso: No se pudo reactivar la sesión de audio.")
            }
        // Ya no activamos la sesión aquí, porque ya se encendió antes.
        // Solo nos preocupamos por reproducir el sonido.
        guard let url = Bundle.main.url(forResource: "alarm", withExtension: "mp3") else {
            print(" No se encontró el archivo de sonido.")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = 1.0
            audioPlayer?.play()
            print(" Alarma sonando en loop...")
            startVibrationLoop()
        } catch {
            print(" No se pudo reproducir el archivo: \(error.localizedDescription)")
        }
    }
    
    func stopAlarm() {
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
            audioPlayer = nil
            
            stopVibrationLoop()
            
            // Apagamos el motor de audio para ahorrar batería
            do {
                try AVAudioSession.sharedInstance().setActive(false)
            } catch {
                print("No se pudo desactivar la sesión de audio.")
            }
            
            print(" Alarma detenida.")
        }
    }
    
    // MARK: - Funciones de vibracion
    private func startVibrationLoop() {
            isVibrating = true
            
            // Creamos una tarea asíncrona que vivirá en segundo plano
            vibrationTask = Task {
                while isVibrating {
                    // 1. Primera vibración
                    AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                    
                    // Pausa cortísima de 0.4 segundos (400 millones de nanosegundos)
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    
                    // 2. Segunda vibración inmediata (efecto "spam" o latido)
                    AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                    
                    // Pausa más larga de 1 segundo antes de repetir el ciclo
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
        
        private func stopVibrationLoop() {
            // Apagamos la bandera y cancelamos la tarea asíncrona
            isVibrating = false
            vibrationTask?.cancel()
            vibrationTask = nil
        }
}
