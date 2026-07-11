//
//  AudioManager.swift
//  BusNap
//
//  Created by Leonardo Ariel San Martin Lopez  on 11/07/26.
//

import Foundation
import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    private var audioPlayer: AVAudioPlayer?
    
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
        } catch {
            print(" No se pudo reproducir el archivo: \(error.localizedDescription)")
        }
    }
    
    func stopAlarm() {
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
            audioPlayer = nil
            
            // Apagamos el motor de audio para ahorrar batería
            do {
                try AVAudioSession.sharedInstance().setActive(false)
            } catch {
                print("No se pudo desactivar la sesión de audio.")
            }
            
            print(" Alarma detenida.")
        }
    }
}
