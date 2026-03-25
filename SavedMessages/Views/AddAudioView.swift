import SwiftUI
import AVFoundation

struct AddAudioView: View {
    @EnvironmentObject var storage: StorageService
    @Environment(\.dismiss) var dismiss

    @State private var isRecording = false
    @State private var hasRecording = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var recorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    @State private var permissionDenied = false
    @State private var setupError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Text(formatDuration(recordingDuration))
                    .font(.system(size: 64, weight: .thin, design: .monospaced))
                    .foregroundStyle(isRecording ? .red : .primary)

                Image(systemName: isRecording ? "waveform" : (hasRecording ? "waveform.badge.checkmark" : "mic.circle"))
                    .font(.system(size: 80))
                    .foregroundStyle(isRecording ? .red : (hasRecording ? .green : .purple))

                Button {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                } label: {
                    Label(
                        isRecording ? "Stop" : (hasRecording ? "Re-record" : "Record"),
                        systemImage: isRecording ? "stop.circle.fill" : "record.circle"
                    )
                    .font(.title2)
                    .padding()
                    .background(isRecording ? Color.red.opacity(0.15) : Color.purple.opacity(0.15))
                    .foregroundStyle(isRecording ? .red : .purple)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("recordButton")

                Spacer()

                if permissionDenied {
                    Text("Microphone access denied. Please enable it in Settings.")
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }

                if let error = setupError {
                    Text(error)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .padding()
            .navigationTitle("Audio Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        cleanUp()
                        dismiss()
                    }
                    .accessibilityIdentifier("cancelButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveRecording()
                        dismiss()
                    }
                    .disabled(!hasRecording)
                    .accessibilityIdentifier("saveButton")
                }
            }
        }
        .onAppear {
            LocationService.shared.start()
        }
    }

    private func startRecording() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    self.beginRecording()
                } else {
                    self.permissionDenied = true
                }
            }
        }
    }

    private func beginRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            setupError = "Could not configure audio session: \(error.localizedDescription)"
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let rec = try AVAudioRecorder(url: url, settings: settings)
            recorder = rec
            recordingURL = url
            rec.record()
        } catch {
            setupError = "Could not start recording: \(error.localizedDescription)"
            return
        }
        setupError = nil
        isRecording = true
        hasRecording = false
        recordingDuration = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
    }

    private func stopRecording() {
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        hasRecording = true
    }

    private func saveRecording() {
        guard let url = recordingURL,
              let data = try? Data(contentsOf: url) else { return }
        let name = "recording_\(Int(Date().timeIntervalSince1970)).m4a"
        storage.addFileItem(data: data, fileName: name, mimeType: "audio/mp4", location: LocationService.shared.currentAddress)
        try? FileManager.default.removeItem(at: url)
    }

    private func cleanUp() {
        recorder?.stop()
        timer?.invalidate()
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int(duration * 10) % 10
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}
