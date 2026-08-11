//
//  SpeechRecognitionManager.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 8/10/26.
//
//  Microphone capture + live transcription for the store row's voice command
//  button. Apple's Speech framework does the transcription; interpreting what
//  the words mean is `OpenAIService.parseVoiceCommand`'s job.
//
//  On-device recognition is requested whenever the device supports it: a
//  shopping list is most often used inside a store, where signal is poor, and
//  it keeps the audio off Apple's servers.
//

import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechRecognitionManager: ObservableObject {

    enum SpeechError: LocalizedError {
        case microphoneDenied
        case speechDenied
        case recognizerUnavailable
        case engineFailed(String)

        var errorDescription: String? {
            switch self {
            case .microphoneDenied:
                return "Allim needs microphone access to hear your request. Turn it on in Settings › Allim."
            case .speechDenied:
                return "Allim needs speech recognition access to understand your request. Turn it on in Settings › Allim."
            case .recognizerUnavailable:
                return "Speech recognition isn't available on this device right now."
            case .engineFailed(let reason):
                return "Couldn't start recording: \(reason)"
            }
        }
    }

    /// Live transcript, updated as the user speaks.
    @Published private(set) var transcript: String = ""
    /// Smoothed 0…1 input level, used to animate the mic.
    @Published private(set) var level: Float = 0
    @Published private(set) var isListening = false

    /// Silence that ends the recording, once something has been said.
    private let silenceTimeout: TimeInterval = 1.8
    /// Hard cap so a session that never hears silence can't record forever.
    private let maxDuration: TimeInterval = 30

    private let audioEngine = AVAudioEngine()
    private let recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    private var startedAt: Date?
    private var lastTranscriptChange: Date?
    private var onFinish: ((String) -> Void)?

    /// `nonisolated` so SwiftUI can build it in a `@StateObject` initializer
    /// without hopping actors — it only assigns stored properties.
    nonisolated init(locale: Locale = .current) {
        // Fall back to en-US when the device language has no recognizer, so the
        // feature still works rather than silently doing nothing.
        recognizer = SFSpeechRecognizer(locale: locale)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    // MARK: - Authorization

    /// Asks for speech recognition and microphone access, in that order.
    /// Throws the matching `SpeechError` for whichever one the user declines.
    static func requestAuthorization() async throws {
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speechStatus == .authorized else { throw SpeechError.speechDenied }

        let micGranted: Bool = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard micGranted else { throw SpeechError.microphoneDenied }
    }

    // MARK: - Recording

    /// Starts listening. `onFinish` fires once with the final transcript, either
    /// when the user stops talking or when `stop()` is called.
    func start(onFinish: @escaping (String) -> Void) throws {
        guard !isListening else { return }
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        transcript = ""
        level = 0
        self.onFinish = onFinish

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.onFinish = nil
            throw SpeechError.engineFailed(error.localizedDescription)
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            let level = Self.meterLevel(for: buffer)
            Task { @MainActor in
                self?.applyLevel(level)
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            input.removeTap(onBus: 0)
            self.request = nil
            self.onFinish = nil
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            throw SpeechError.engineFailed(error.localizedDescription)
        }

        startedAt = Date()
        lastTranscriptChange = Date()
        isListening = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self, self.isListening else { return }

                if let result {
                    let text = result.bestTranscription.formattedString
                    if text != self.transcript {
                        self.transcript = text
                        self.lastTranscriptChange = Date()
                    }
                    if result.isFinal {
                        self.finish()
                        return
                    }
                }

                if error != nil {
                    // A recognizer error after speech was captured still leaves
                    // a usable transcript; finish with whatever we have and let
                    // the caller decide whether it's enough.
                    self.finish()
                }
            }
        }

        startSilenceTimer()
    }

    /// Ends the recording and delivers the transcript captured so far.
    func stop() {
        guard isListening else { return }
        finish()
    }

    /// Ends the recording and discards it — used when the sheet is dismissed.
    func cancel() {
        onFinish = nil
        teardown()
    }

    // MARK: - Internals

    private func finish() {
        let callback = onFinish
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        onFinish = nil
        teardown()
        callback?(text)
    }

    private func teardown() {
        isListening = false
        silenceTimer?.invalidate()
        silenceTimer = nil
        startedAt = nil
        lastTranscriptChange = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)

        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        level = 0

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForSilence()
            }
        }
    }

    private func checkForSilence() {
        guard isListening else { return }
        let now = Date()

        if let startedAt, now.timeIntervalSince(startedAt) >= maxDuration {
            finish()
            return
        }

        // Don't auto-stop before the user has said anything — they may still be
        // gathering their thoughts after tapping the button.
        guard !transcript.isEmpty, let lastChange = lastTranscriptChange else { return }
        if now.timeIntervalSince(lastChange) >= silenceTimeout {
            finish()
        }
    }

    private func applyLevel(_ newLevel: Float) {
        // Light smoothing, otherwise the meter strobes at buffer rate.
        level += (newLevel - level) * 0.3
    }

    /// RMS of a buffer mapped onto 0…1 for the mic animation.
    private nonisolated static func meterLevel(for buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }

        var sum: Float = 0
        for index in 0..<count {
            let sample = channel[index]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(count))

        // Speech sits well below full scale, so -50…0 dBFS is stretched over the
        // full range — otherwise the meter barely moves at conversational volume.
        let decibels = 20 * log10(max(rms, 1e-7))
        return max(0, min(1, (decibels + 50) / 50))
    }
}
