import Foundation
import AVFoundation
import SwiftUI

extension UserDefaults {
    static let audioMutedKey = "octant.audio.muted"
}

@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    enum Cue {
        case click       // bit toggled
        case win         // round solved
        case finish      // game over
        case tick        // countdown tick
        case start       // round start
        case error       // round timeout / network error
        case nav         // menu / button select
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var started = false

    private init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        renderBuffers(format: format)
    }

    func play(_ cue: Cue) {
        if UserDefaults.standard.bool(forKey: UserDefaults.audioMutedKey) { return }
        if !started { start() }
        guard started, let buffer = buffers[cue] else { return }
        if !player.isPlaying { player.play() }
        player.scheduleBuffer(buffer, completionHandler: nil)
    }

    private func start() {
        guard !started else { return }
        #if !os(macOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            #if DEBUG
            NSLog("[SoundPlayer] AVAudioSession setup failed: \(error)")
            #endif
        }
        #endif
        do {
            try engine.start()
            started = true
        } catch {
            #if DEBUG
            NSLog("[SoundPlayer] engine start failed: \(error)")
            #endif
        }
    }

    private func renderBuffers(format: AVAudioFormat) {
        buffers[.click]  = synthesize(format: format, duration: 0.05, voices: [Voice(freq: 880, wave: .square)], attack: 0.001, decay: 0.05, gain: 0.25)
        buffers[.nav]    = synthesize(format: format, duration: 0.06, voices: [Voice(freq: 660, wave: .sine)], attack: 0.001, decay: 0.06, gain: 0.30)
        buffers[.win]    = synthesizeArpeggio(format: format, freqs: [523.25, 659.25, 783.99], stepDuration: 0.09, wave: .sine, attack: 0.005, releaseTail: 0.10, gain: 0.35)
        buffers[.finish] = synthesizeChordSweep(format: format, duration: 0.85, freqs: [523.25, 659.25, 783.99, 1046.50], wave: .sine, attack: 0.02, decay: 0.85, gain: 0.30)
        buffers[.tick]   = synthesize(format: format, duration: 0.07, voices: [Voice(freq: 1320, wave: .sine)], attack: 0.002, decay: 0.07, gain: 0.22)
        buffers[.start]  = synthesizeArpeggio(format: format, freqs: [523.25, 1046.50], stepDuration: 0.10, wave: .square, attack: 0.005, releaseTail: 0.08, gain: 0.30)
        buffers[.error]  = synthesizeError(format: format, gain: 0.32)
    }

    // MARK: - Synthesis primitives

    private enum Wave { case sine, square, triangle }

    private struct Voice {
        let freq: Double
        let wave: Wave
    }

    private func waveform(_ wave: Wave, freq: Double, t: Double) -> Double {
        switch wave {
        case .sine:
            return sin(2 * .pi * freq * t)
        case .square:
            return sin(2 * .pi * freq * t) > 0 ? 1.0 : -1.0
        case .triangle:
            let phase = (freq * t).truncatingRemainder(dividingBy: 1.0)
            return phase < 0.5 ? (4 * phase - 1) : (3 - 4 * phase)
        }
    }

    private func envelope(at t: Double, attack: Double, decay: Double) -> Double {
        if t < 0 { return 0 }
        if t < attack { return t / max(attack, 1e-6) }
        let r = (t - attack) / max(decay, 1e-6)
        return max(0, exp(-r * 4.5))
    }

    private func makeBuffer(format: AVAudioFormat, duration: Double) -> (AVAudioPCMBuffer, Int) {
        let frames = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        return (buffer, Int(frames))
    }

    private func synthesize(format: AVAudioFormat, duration: Double, voices: [Voice], attack: Double, decay: Double, gain: Double) -> AVAudioPCMBuffer {
        let (buffer, frames) = makeBuffer(format: format, duration: duration)
        guard let p = buffer.floatChannelData?[0] else { return buffer }
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            var v: Double = 0
            for voice in voices {
                v += waveform(voice.wave, freq: voice.freq, t: t)
            }
            v /= Double(max(voices.count, 1))
            p[i] = Float(v * envelope(at: t, attack: attack, decay: decay) * gain)
        }
        return buffer
    }

    private func synthesizeArpeggio(format: AVAudioFormat, freqs: [Double], stepDuration: Double, wave: Wave, attack: Double, releaseTail: Double, gain: Double) -> AVAudioPCMBuffer {
        let total = stepDuration * Double(freqs.count) + releaseTail
        let (buffer, frames) = makeBuffer(format: format, duration: total)
        guard let p = buffer.floatChannelData?[0] else { return buffer }
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            let stepIndex = min(freqs.count - 1, Int(t / stepDuration))
            let stepStart = Double(stepIndex) * stepDuration
            let local = t - stepStart
            let env = envelope(at: local, attack: attack, decay: stepDuration)
            let v = waveform(wave, freq: freqs[stepIndex], t: t)
            p[i] = Float(v * env * gain)
        }
        return buffer
    }

    private func synthesizeChordSweep(format: AVAudioFormat, duration: Double, freqs: [Double], wave: Wave, attack: Double, decay: Double, gain: Double) -> AVAudioPCMBuffer {
        let (buffer, frames) = makeBuffer(format: format, duration: duration)
        guard let p = buffer.floatChannelData?[0] else { return buffer }
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            var v: Double = 0
            for f in freqs {
                v += waveform(wave, freq: f, t: t)
            }
            v /= Double(freqs.count)
            p[i] = Float(v * envelope(at: t, attack: attack, decay: decay) * gain)
        }
        return buffer
    }

    private func synthesizeError(format: AVAudioFormat, gain: Double) -> AVAudioPCMBuffer {
        let duration = 0.30
        let (buffer, frames) = makeBuffer(format: format, duration: duration)
        guard let p = buffer.floatChannelData?[0] else { return buffer }
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            // descending pitch from 330 -> 165 over duration
            let f = 330.0 - 165.0 * (t / duration)
            let v = waveform(.square, freq: f, t: t)
            p[i] = Float(v * envelope(at: t, attack: 0.005, decay: duration) * gain)
        }
        return buffer
    }
}
