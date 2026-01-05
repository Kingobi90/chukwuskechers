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
        "ACDB", "AQMT", "AQPK", "AQPR", "AQUA", "B", "BBK", "BBLM", "BBLP", "BBOR", "BCBL", "BCCL", "BCOR", "BCYL",
        "BGE", "BGOR", "BGRD", "BKAQ", "BKBL", "BKBR", "BKBU", "BKCC", "BKCL", "BKFS", "BKGD", "BKGM", "BKGR", "BKGY",
        "BKHP", "BKLB", "BKLD", "BKLG", "BKLM", "BKLP", "BKLV", "BKMN", "BKMT", "BKMV", "BKNT", "BKNV", "BKOL", "BKOR",
        "BKPK", "BKPR", "BKPW", "BKRB", "BKRD", "BKRG", "BKRY", "BKS", "BKSL", "BKSR", "BKTL", "BKTN", "BKTP", "BKTQ",
        "BKW", "BKWP", "BKWR", "BKYB", "BKYL", "BKYO", "BLAQ", "BLBK", "BLCL", "BLGR", "BLGY", "BLK", "BLLB", "BLLM",
        "BLMN", "BLMT", "BLNV", "BLOR", "BLPK", "BLPR", "BLRD", "BLSH", "BLSL", "BLTQ", "BLU", "BLW", "BLYL", "BMLT",
        "BOL", "BPPK", "BPT", "BRBK", "BRBL", "BRCK", "BRCT", "BRGR", "BRLM", "BRMT", "BRN", "BRNT", "BROL", "BROR",
        "BRPK", "BRRD", "BRS", "BRTN", "BRTP", "BRW", "BRZ", "BSGD", "BUBK", "BUGD", "BUGY", "BUMT", "BUR", "BURG",
        "CAMO", "CBLM", "CCAQ", "CCBK", "CCBL", "CCBU", "CCGD", "CCGR", "CCGY", "CCL", "CCLB", "CCLG", "CCLM", "CCLV",
        "CCMT", "CCNV", "CCOR", "CCPK", "CCPR", "CCRD", "CCSL", "CCTL", "CCTQ", "CCYL", "CDB", "CHAR", "CHBK", "CHBR",
        "CHBZ", "CHMP", "CHMT", "CHOC", "CHOR", "CHSD", "CHT", "CHTN", "CHTP", "CINN", "CLAY", "CLR", "CML", "CMNT",
        "COC", "COFF", "COG", "COPP", "CRL", "CRML", "CRMT", "CSMT", "CSNT", "CYT", "DBRN", "DCHN", "DEN", "DKBR",
        "DKCC", "DKGR", "DKGY", "DKMV", "DKNT", "DKNV", "DKPR", "DKRD", "DKRS", "DKTP", "DSCH", "DSRT", "EMRD", "FUD",
        "FUS", "GDMT", "GDPK", "GDSL", "GIR", "GLD", "GMLT", "GNBK", "GRBK", "GRMT", "GRN", "GRNV", "GROR", "GRPK",
        "GRW", "GRY", "GRYL", "GUBK", "GUN", "GURD", "GYAQ", "GYBK", "GYBL", "GYBR", "GYBU", "GYCC", "GYCL", "GYGR",
        "GYLB", "GYLM", "GYLP", "GYLV", "GYMN", "GYMT", "GYMV", "GYNV", "GYOL", "GYOR", "GYPK", "GYPR", "GYRD", "GYS",
        "GYSL", "GYTQ", "GYW", "GYYL", "HPAQ", "HPBK", "HPBL", "HPGD", "HPK", "HPLV", "HPMT", "HPNV", "HPSL", "HPTQ",
        "HTPK", "KHK", "LAV", "LBGY", "LBLV", "LBLW", "LBMT", "LBNV", "LBPK", "LBSL", "LGAQ", "LGBK", "LGBL", "LGCC",
        "LGLB", "LGLM", "LGLV", "LGMT", "LGNV", "LGPK", "LGPR", "LGY", "LIL", "LIME", "LMBK", "LMBL", "LMCC", "LMGN",
        "LMLV", "LMMT", "LPCC", "LPD", "LPHP", "LPK", "LPMT", "LPRG", "LTBL", "LTBR", "LTDN", "LTGD", "LTGR", "LTGY",
        "LTMV", "LTPK", "LTPL", "LTTN", "LUG", "LVAQ", "LVHP", "LVLP", "LVMT", "LVNP", "LVPK", "LVTQ", "MAG", "MAPL",
        "MLT", "MNT", "MOC", "MTMT", "MULT", "MUSH", "MUST", "MVE", "MVGY", "MVMT", "MVNT", "MVPR", "MVTQ", "NAT",
        "NBLM", "NLMT", "NMLT", "NPMT", "NPNK", "NTAQ", "NTBG", "NTBK", "NTBL", "NTBR", "NTCL", "NTGD", "NTGR", "NTGY",
        "NTLB", "NTLP", "NTMT", "NTNV", "NTOL", "NTOR", "NTPH", "NTPK", "NTPR", "NTRD", "NTSL", "NTTN", "NTTP", "NTW",
        "NTYL", "NUDE", "NVAQ", "NVBK", "NVBL", "NVBR", "NVBU", "NVCC", "NVCL", "NVGD", "NVGW", "NVGY", "NVHP", "NVLB",
        "NVLM", "NVLV", "NVMT", "NVNT", "NVOR", "NVPK", "NVPR", "NVPW", "NVRD", "NVSL", "NVTL", "NVTN", "NVTQ", "NVW",
        "NVY", "NVYL", "NWLB", "OFNV", "OFNY", "OFPK", "OFWM", "OFWR", "OFWT", "OLBK", "OLBR", "OLGY", "OLLM", "OLMT",
        "OLNT", "OLOR", "OLPK", "OLV", "ORBK", "ORBL", "ORCC", "ORG", "ORMT", "ORNV", "ORYL", "OWBL", "OWBR", "OWGN",
        "OWGR", "OWHT", "PBBK", "PBL", "PCH", "PERI", "PEW", "PINK", "PKBK", "PKBL", "PKCL", "PKGR", "PKGY", "PKHP",
        "PKLB", "PKLM", "PKLP", "PKLV", "PKMT", "PKNV", "PKRD", "PKSL", "PKTN", "PKTQ", "PLUM", "PMLT", "PNK", "PRAQ",
        "PRBK", "PRBL", "PRCL", "PRGR", "PRLB", "PRLV", "PRMT", "PROR", "PRPK", "PRTQ", "PRYL", "PUR", "PWAQ", "PWMT",
        "QUAL", "RAS", "RDBK", "RDBL", "RDBR", "RDCC", "RDGY", "RDMT", "RDNV", "RDOR", "RDPK", "RDPR", "RDS", "RDW",
        "RDYL", "RED", "ROS", "RSGD", "RST", "RUST", "RYBK", "RYBL", "RYL", "RYMT", "RYOR", "RYYL", "SAGE", "SAND",
        "SDNT", "SFM", "SIL", "SLAQ", "SLBK", "SLBL", "SLGD", "SLGY", "SLLP", "SLLV", "SLNV", "SLOR", "SLPK", "SLPR",
        "SLR", "SLRY", "SLT", "SLTP", "SLW", "SMLT", "SND", "SNK", "STN", "STNV", "STOL", "TAN", "TEAL", "TLBK", "TLBL",
        "TLMT", "TLNV", "TNBK", "TNBR", "TNCC", "TNTP", "TPBG", "TPBK", "TPBL", "TPBR", "TPCH", "TPCL", "TPE", "TPGD",
        "TPHP", "TPLM", "TPLV", "TPMT", "TPNT", "TPNV", "TPOR", "TPPC", "TPPK", "TPSL", "TPYL", "TQBK", "TQCR", "TQGY",
        "TQLM", "TQLV", "TQMT", "TURQ", "VIL", "W", "WAQ", "WBGY", "WBK", "WBKB", "WBKR", "WBKS", "WBL", "WBLK", "WBLM",
        "WBLP", "WBLR", "WBLU", "WBMT", "WBO", "WBPK", "WBPR", "WBR", "WBRD", "WBRN", "WBSL", "WBTQ", "WBUG", "WCC",
        "WCCL", "WCLV", "WCRL", "WFUS", "WGD", "WGR", "WGRD", "WGRN", "WGY", "WHLD", "WHP", "WHPK", "WHT", "WINE", "WLB",
        "WLBL", "WLBP", "WLBY", "WLGY", "WLM", "WLPK", "WLPR", "WLV", "WLVB", "WLVM", "WMLT", "WMN", "WMNT", "WMT",
        "WNLB", "WNT", "WNV", "WNVB", "WNVL", "WNVP", "WNVR", "WOR", "WPK", "WPKB", "WPKL", "WPLB", "WPNK", "WPR",
        "WPRP", "WPTQ", "WPUR", "WPW", "WRD", "WRDB", "WROS", "WRPK", "WRSL", "WSBK", "WSBL", "WSK", "WSL", "WSLB",
        "WSLG", "WSLP", "WSPK", "WSRD", "WTBK", "WTG", "WTGD", "WTN", "WTNT", "WTP", "WTPK", "WTQ", "WTQP", "WTRG",
        "WWHT", "WYL", "YEL", "YLBK", "YLBL", "YLLM", "YLMT", "YLNV", "YLW", "ZBA"
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
