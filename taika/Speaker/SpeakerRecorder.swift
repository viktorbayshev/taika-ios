//
//  SpeakerRecorder.swift
//  taika
//
//  Created by product on 26.12.2025.
//
import AVFoundation
import Speech

extension Notification.Name {
    static let speakerRecorderDidStart = Notification.Name("speakerRecorderDidStart")
    static let speakerRecorderDidStop = Notification.Name("speakerRecorderDidStop")
}

protocol SpeakerRecording: AnyObject {
    var isRecording: Bool { get }
    var recordingMeter: Double { get }
    var partialText: String { get }

    func requestPermission(completion: @escaping (Bool) -> Void)
    func start(completion: @escaping (URL?) -> Void)
    func stop() -> URL?
    func currentAudioURL() -> URL?
}

@MainActor
final class SpeakerRecorder: NSObject, ObservableObject, SpeakerRecording {
    @Published var isRecording: Bool = false
    @Published var recordingMeter: Double = 0.0
    @Published var partialText: String = ""

    enum Status: Equatable {
        case idle
        case requestingPermission
        case permissionDenied
        case starting
        case recording
        case startFailed
        case stopping
        case stopFailed
    }

    @Published var status: Status = .idle
    @Published var lastErrorMessage: String? = nil

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "th-TH"))
    private var speechAuthorized: Bool = false

    static let shared = SpeakerRecorder()

    private var recorder: AVAudioRecorder?
    private var leveltimer: Timer?
    private let filename = "speaker_attempt.m4a"
    private var currentURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        status = .requestingPermission
        lastErrorMessage = nil

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            status = .permissionDenied
            lastErrorMessage = "mic session setup failed"
            completion(false)
            return
        }

        session.requestRecordPermission { [weak self] micGranted in
            DispatchQueue.main.async {
                guard let self = self else {
                    completion(false)
                    return
                }
                if micGranted {
                    self.status = .starting
                } else {
                    self.status = .permissionDenied
                    self.lastErrorMessage = "mic permission denied"
                }
                completion(micGranted)
            }
        }
    }

    func start(completion: @escaping (URL?) -> Void) {
        status = .starting
        lastErrorMessage = nil

        requestPermission { [weak self] ok in
            guard ok, let self = self else {
                if let self = self {
                    self.status = .permissionDenied
                    self.lastErrorMessage = "mic permission denied"
                }
                completion(nil)
                return
            }

            self.requestSpeechAuthorization { speechOk in
                let settings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100.0,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]

                do {
                    try FileManager.default.removeItem(at: self.currentURL)
                } catch {}

                do {
                    let r = try AVAudioRecorder(url: self.currentURL, settings: settings)
                    r.isMeteringEnabled = true
                    r.prepareToRecord()
                    r.record()
                    NotificationCenter.default.post(name: .speakerRecorderDidStart, object: nil)

                    self.recorder = r
                    self.isRecording = true
                    self.status = .recording
                    self.startLevelMeter()
                    self.partialText = ""
                    if speechOk {
                        self.startLiveTranscription()
                    }
                    completion(self.currentURL)
                } catch {
                    self.isRecording = false
                    self.status = .startFailed
                    self.lastErrorMessage = "recorder start failed"
                    completion(nil)
                }
            }
        }
    }

    func stop() -> URL? {
        return stopRecording()
    }

    func stopRecording() -> URL? {
        status = .stopping
        lastErrorMessage = nil

        // idempotent: safe to call multiple times
        recorder?.stop()
        recorder = nil

        // if we were not recording, treat as stopFailed but keep idempotent behavior
        if !isRecording {
            status = .stopFailed
            lastErrorMessage = "stop called while not recording"
        }

        stopLiveTranscription()
        partialText = ""

        stopLevelMeter()
        isRecording = false

        let url = currentAudioURL()
        if url == nil {
            status = .stopFailed
            lastErrorMessage = lastErrorMessage ?? "no audio file"
        }

        NotificationCenter.default.post(name: .speakerRecorderDidStop, object: lastAttemptSummary())

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {}

        if url != nil {
            status = .idle
        }

        return url
    }

    func currentAudioURL() -> URL? {
        let path = currentURL.path
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? NSNumber,
              size.intValue > 0
        else { return nil }
        return currentURL
    }

    private func startLevelMeter() {
        stopLevelMeter()
        recordingMeter = 0.0
        leveltimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard let r = self.recorder else {
                self.recordingMeter = 0.0
                return
            }
            r.updateMeters()
            let power = r.averagePower(forChannel: 0) // -160...0
            let normalized = max(0.0, min(1.0, Double((power + 160.0) / 160.0)))
            self.recordingMeter = normalized
        }
        RunLoop.main.add(leveltimer!, forMode: .common)
    }

    private func stopLevelMeter() {
        leveltimer?.invalidate()
        leveltimer = nil
        recordingMeter = 0.0
    }

    private func lastAttemptSummary() -> String {
        switch status {
        case .stopFailed:
            return "recording stopped (failed): \(lastErrorMessage ?? "unknown")"
        default:
            return "recording stopped"
        }
    }

    private func startLiveTranscription() {
        stopLiveTranscription()

        guard speechAuthorized, let recognizer = speechRecognizer, recognizer.isAvailable else {
            return
        }

        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine = engine
        recognitionRequest = request

        do {
            engine.prepare()
            try engine.start()
        } catch {
            stopLiveTranscription()
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let r = result {
                self.partialText = r.bestTranscription.formattedString
            }
            if error != nil || (result?.isFinal == true) {
                // keep partialText as last known
                self.stopLiveTranscription()
            }
        }
    }

    private func stopLiveTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if let engine = audioEngine {
            // removeTap may throw if not installed; keep it safe
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            engine.reset()
        }
        audioEngine = nil
    }
    private func requestSpeechAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] auth in
            DispatchQueue.main.async {
                let ok: Bool
                switch auth {
                case .authorized:
                    ok = true
                default:
                    ok = false
                }
                self?.speechAuthorized = ok
                completion(ok)
            }
        }
    }
}
