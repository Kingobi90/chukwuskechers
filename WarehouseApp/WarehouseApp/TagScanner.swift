import SwiftUI
import AVFoundation
import Vision

class TagScannerViewModel: NSObject, ObservableObject {
    @Published var detectedText: String?
    @Published var extractedStyle: String?
    @Published var extractedColor: String?
    @Published var allDetectedColors: [String] = []
    @Published var multipleColorsDetected = false
    @Published var isScanning = false
    
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var lastProcessTime = Date()
    private let processingInterval: TimeInterval = 0.5
    
    private let validColors = [
        "BLK", "BBK", "BKMT", "BKCC", "BKBL", "BKGD", "BKGY", "BKGN", "BKOR", "BKPK", "BKPR", "BKRD", "BKSL", "BKWT", "BKW",
        "WHT", "OFWT", "WBK", "WBL", "WCC", "WGD", "WGN", "WGY", "WMT", "WMLT", "WNV", "WOR", "WPK", "WPR", "WRD", "WSL", "WTP", "WBUG",
        "NVY", "NVBL", "NVBK", "NVCC", "NVGY", "NVGN", "NVMT", "NVOR", "NVPK", "NVRD", "NVWT",
        "GRY", "GRAY", "GYBL", "GYBK", "GYMT", "GYOR", "GYPK", "GYRD", "GYWT",
        "CHAR", "CC", "CCBK", "CCBL", "CCLV", "CCOR", "CCPK",
        "BLU", "LTBL", "DKBL", "BLMT", "BLPK", "BLRD", "BLWT", "BLGY", "BLOR",
        "RED", "RDBK", "RDBR", "RDGY", "RDMT", "RDPK", "RDWT",
        "PINK", "PNK", "LTPK", "PKMT", "PKWT", "PKBL", "PKPR",
        "PRPL", "PRP", "PRCL", "PRMT", "PRPK", "PRWT",
        "GRN", "LTGN", "DKGN", "GNMT", "GNWT", "GNBL",
        "OLV", "OLVG",
        "BRN", "DKBR", "LTBR", "CDB", "BRMT", "BRWT",
        "BGE", "TAN", "TPE", "TAUP", "DKTP", "LTTN", "SAND", "KHAK", "KHK", "NAT", "NTMT", "NTTN",
        "ORG", "ORNG", "ORMT", "ORWT", "ORBL", "CRL",
        "YLW", "YLLW", "YLMT", "YLWT",
        "MULT", "MLTI", "CAMO", "PRNT", "FLRL",
        "SLV", "SLVR", "GLD", "GOLD", "RSGD", "BRNZ",
        "STN", "SLTP", "SLAT",
        "MVE", "MAUV", "LAV", "LVND", "MINT", "TEAL", "TRQ",
        "COC", "COCO", "WINE", "BUG", "BURG", "PLUM", "PEACH", "LMGN", "LIME"
    ]
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        captureSession.sessionPreset = .high
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        if let connection = videoOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
        }
    }
    
    func startScanning() {
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
            DispatchQueue.main.async {
                self?.isScanning = true
            }
        }
    }
    
    func stopScanning() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
            DispatchQueue.main.async {
                self?.isScanning = false
            }
        }
    }
    
    private func processImage(_ image: CVPixelBuffer) {
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            let fullText = recognizedStrings.joined(separator: " ")
            
            DispatchQueue.main.async {
                self?.detectedText = fullText
                self?.parseTagText(fullText)
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        
        let handler = VNImageRequestHandler(cvPixelBuffer: image, options: [:])
        try? handler.perform([request])
    }
    
    private func parseTagText(_ text: String) {
        let uppercased = text.uppercased()
        let components = uppercased.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        
        var foundStyle: String?
        var foundColors: [String] = []
        var labeledColor: String?
        
        // Parse style number
        for (index, component) in components.enumerated() {
            if component.contains("SN/RN") || component.contains("SN") || component.contains("RN") {
                let nextIndex = index + 1
                if nextIndex < components.count {
                    let potentialStyle = components[nextIndex]
                        .replacingOccurrences(of: "SN/RN", with: "")
                        .replacingOccurrences(of: "SN", with: "")
                        .replacingOccurrences(of: "RN", with: "")
                        .trimmingCharacters(in: CharacterSet(charactersIn: ":/- "))
                    
                    if potentialStyle.count == 6 && potentialStyle.allSatisfy({ $0.isNumber }) {
                        foundStyle = potentialStyle
                    }
                }
            }
            
            // Priority 1: Look for color after COLOR label
            if component.contains("COLOR") || component.contains("CLR") {
                let nextIndex = index + 1
                if nextIndex < components.count {
                    let potentialColor = components[nextIndex]
                        .replacingOccurrences(of: "COLOR", with: "")
                        .replacingOccurrences(of: "CLR", with: "")
                        .replacingOccurrences(of: "CODE", with: "")
                        .replacingOccurrences(of: ":", with: "")
                        .trimmingCharacters(in: CharacterSet(charactersIn: ":- "))
                    
                    if validColors.contains(potentialColor) {
                        labeledColor = potentialColor
                    }
                }
            }
        }
        
        // Fallback: Find style with regex
        let stylePattern = "\\b\\d{6}\\b"
        if foundStyle == nil, let regex = try? NSRegularExpression(pattern: stylePattern) {
            let range = NSRange(uppercased.startIndex..., in: uppercased)
            if let match = regex.firstMatch(in: uppercased, range: range) {
                if let matchRange = Range(match.range, in: uppercased) {
                    foundStyle = String(uppercased[matchRange])
                }
            }
        }
        
        // Priority 2: Find all exact color matches in text (sorted by length to avoid substrings)
        let sortedColors = validColors.sorted { $0.count > $1.count }
        for color in sortedColors {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: color) + "\\b"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(uppercased.startIndex..., in: uppercased)
                let matches = regex.matches(in: uppercased, range: range)
                if !matches.isEmpty && !foundColors.contains(color) {
                    foundColors.append(color)
                }
            }
        }
        
        // Prioritize labeled color
        if let labeled = labeledColor {
            foundColors.removeAll { $0 == labeled }
            foundColors.insert(labeled, at: 0)
        }
        
        if let style = foundStyle {
            extractedStyle = style
            allDetectedColors = foundColors
            multipleColorsDetected = foundColors.count > 1
            extractedColor = foundColors.first
        }
    }
}

extension TagScannerViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastProcessTime) >= processingInterval else { return }
        lastProcessTime = now
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        processImage(pixelBuffer)
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
