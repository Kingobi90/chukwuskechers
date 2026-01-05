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
        // Black variants
        "BLK", "BBK", "BKMT", "BKCC", "BKBL", "BKGD", "BKGY", "BKGN", "BKOR", "BKPK", "BKPR", "BKRD", "BKSL", "BKWT", "BKW",
        // White variants
        "WHT", "OFWT", "WBK", "WBL", "WCC", "WGD", "WGN", "WGY", "WMT", "WMLT", "WNV", "WOR", "WPK", "WPR", "WRD", "WSL", "WTP", "WBUG",
        // Navy variants
        "NVY", "NVBL", "NVBK", "NVCC", "NVGY", "NVGN", "NVMT", "NVOR", "NVPK", "NVRD", "NVWT",
        // Gray variants
        "GRY", "GRAY", "GYBL", "GYBK", "GYMT", "GYOR", "GYPK", "GYRD", "GYWT",
        // Charcoal variants
        "CHAR", "CC", "CCBK", "CCBL", "CCLV", "CCOR", "CCPK",
        // Blue variants
        "BLU", "LTBL", "DKBL", "BLMT", "BLPK", "BLRD", "BLWT", "BLGY", "BLOR",
        // Red variants
        "RED", "RDBK", "RDBR", "RDGY", "RDMT", "RDPK", "RDWT",
        // Pink variants
        "PINK", "PNK", "LTPK", "PKMT", "PKWT", "PKBL", "PKPR",
        // Purple variants
        "PRPL", "PRP", "PRCL", "PRMT", "PRPK", "PRWT",
        // Green variants
        "GRN", "LTGN", "DKGN", "GNMT", "GNWT", "GNBL",
        // Olive variants
        "OLV", "OLVG",
        // Brown variants
        "BRN", "DKBR", "LTBR", "CDB", "BRMT", "BRWT",
        // Beige/Tan/Natural variants
        "BGE", "TAN", "TPE", "TAUP", "DKTP", "LTTN", "SAND", "KHAK", "KHK", "NAT", "NTMT", "NTTN",
        // Orange variants
        "ORG", "ORNG", "ORMT", "ORWT", "ORBL", "CRL",
        // Yellow variants
        "YLW", "YLLW", "YLMT", "YLWT",
        // Multi/Pattern variants
        "MULT", "MLTI", "CAMO", "PRNT", "FLRL",
        // Metallic variants
        "SLV", "SLVR", "GLD", "GOLD", "RSGD", "BRNZ",
        // Stone/Slate variants
        "STN", "SLTP", "SLAT",
        // Other colors
        "MVE", "MAUV", "LAV", "LVND", "MINT", "TEAL", "TRQ",
        "COC", "COCO", "WINE", "BUG", "BURG", "PLUM", "PEACH", "LMGN", "LIME",
        // Additional common codes
        "DKGY", "LTGY", "NVGY", "CHRC", "NVCC"
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
            
            // Store text with bounding boxes for spatial analysis
            var textWithBounds: [(text: String, bounds: CGRect)] = []
            
            for observation in observations {
                guard let candidate = observation.topCandidates(1).first else { continue }
                textWithBounds.append((text: candidate.string, bounds: observation.boundingBox))
            }
            
            let fullText = textWithBounds.map { $0.text }.joined(separator: " ")
            
            DispatchQueue.main.async {
                self?.detectedText = fullText
                self?.parseTagTextWithSpatialAwareness(textWithBounds)
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        
        let handler = VNImageRequestHandler(cvPixelBuffer: image, options: [:])
        try? handler.perform([request])
    }
    
    private func parseTagTextWithSpatialAwareness(_ textWithBounds: [(text: String, bounds: CGRect)]) {
        var foundStyle: String?
        var foundColor: String?
        
        // Find the Y-coordinate of "Color" or "CLR Code" label
        var colorLabelY: CGFloat?
        var styleLabelY: CGFloat?
        
        for item in textWithBounds {
            let uppercased = item.text.uppercased()
            
            // Find Color row
            if uppercased.contains("COLOR") || uppercased == "CLR" || uppercased.contains("CLR CODE") {
                colorLabelY = item.bounds.midY
            }
            
            // Find SN/RN row
            if uppercased.contains("SN/RN") || uppercased == "SN/RN" {
                styleLabelY = item.bounds.midY
            }
        }
        
        // Now find values on the same rows
        let yTolerance: CGFloat = 0.02 // Allow 2% vertical tolerance for same row
        
        // Extract style number from SN/RN row
        if let styleY = styleLabelY {
            for item in textWithBounds {
                let yDiff = abs(item.bounds.midY - styleY)
                if yDiff < yTolerance {
                    // Check if this text contains 5-6 digits
                    let cleaned = item.text.replacingOccurrences(of: "SN", with: "")
                        .replacingOccurrences(of: "RN", with: "")
                        .trimmingCharacters(in: CharacterSet(charactersIn: ":/- "))
                    
                    if (cleaned.count == 5 || cleaned.count == 6) && cleaned.allSatisfy({ $0.isNumber }) {
                        foundStyle = cleaned
                        break
                    }
                }
            }
        }
        
        // Extract color from Color row
        if let colorY = colorLabelY {
            for item in textWithBounds {
                let yDiff = abs(item.bounds.midY - colorY)
                if yDiff < yTolerance {
                    let uppercased = item.text.uppercased()
                        .trimmingCharacters(in: CharacterSet(charactersIn: ":- "))
                    
                    // Check if this is a valid color code
                    if validColors.contains(uppercased) && uppercased != "COLOR" && uppercased != "CLR" {
                        foundColor = uppercased
                        break
                    }
                }
            }
        }
        
        // Fallback: If no style found with spatial awareness, try pattern matching
        if foundStyle == nil {
            for item in textWithBounds {
                let cleaned = item.text.replacingOccurrences(of: "SN", with: "")
                    .replacingOccurrences(of: "RN", with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: ":/- "))
                
                if (cleaned.count == 5 || cleaned.count == 6) && cleaned.allSatisfy({ $0.isNumber }) {
                    let uniqueDigits = Set(cleaned)
                    // Avoid dates and repeated digits
                    if !cleaned.hasPrefix("19") && !cleaned.hasPrefix("20") && !cleaned.hasPrefix("21") && uniqueDigits.count > 1 {
                        foundStyle = cleaned
                        break
                    }
                }
            }
        }
        
        // Fallback: If no color found with spatial awareness, look for any valid color
        if foundColor == nil {
            let sortedColors = validColors.sorted { $0.count > $1.count }
            for item in textWithBounds {
                let uppercased = item.text.uppercased()
                for color in sortedColors {
                    if uppercased == color {
                        foundColor = color
                        break
                    }
                }
                if foundColor != nil { break }
            }
        }
        
        if let style = foundStyle {
            extractedStyle = style
            extractedColor = foundColor
            allDetectedColors = foundColor != nil ? [foundColor!] : []
            multipleColorsDetected = false
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
