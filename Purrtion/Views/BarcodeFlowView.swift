import SwiftUI
import AVFoundation

/// Scan → look up in Open Food Facts → choose amount → log.
struct BarcodeFlowView: View {
    let day: Date
    /// Set when scanning for a recipe or meal: the product is picked with its amount instead of being logged.
    var onPick: ((FoodItem, Double, ServingOption) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var path: [FoodItem] = []
    @State private var state: LookupState = .scanning
    @State private var manualCode = ""
    @State private var lastCode: String?
    @State private var torchOn = false
    @AppStorage(Extras.multiScanKey) private var multiScan = true
    @State private var addedName: String?

    enum LookupState: Equatable {
        case scanning, loading(String), notFound(String), failed(String)
    }

    private var scannerAvailable: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    /// The torch only burns while actually looking for a code – off as soon as one was recognised.
    private var torchActive: Bool {
        guard torchOn, path.isEmpty, case .scanning = state else { return false }
        return true
    }
    private var torchAvailable: Bool { scannerAvailable && AVCaptureDevice.default(for: .video)?.hasTorch == true }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 16) {
                    scannerArea
                    statusArea
                    manualEntry
                    Spacer()
                }
                .padding(16)
            }
            .overlay(alignment: .top) {
                if let addedName {
                    Label("\(addedName) eingetragen", systemImage: "checkmark.circle.fill")
                        .font(Theme.font(14, .bold)).foregroundStyle(.white).lineLimit(1)
                        .padding(.horizontal, 14).padding(.vertical, 8).background(Theme.accent, in: Capsule())
                        .padding(.top, 8).transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationTitle("Barcode scannen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { torchOn.toggle() } label: {
                        Image(systemName: torchOn ? "bolt.fill" : "bolt.slash.fill")
                    }
                    .accessibilityLabel(torchOn ? "Blitz ausschalten" : "Blitz einschalten")
                    .disabled(!torchAvailable)
                }
            }
            .navigationDestination(for: FoodItem.self) { food in
                if let onPick {
                    FoodDetailView(food: food, mode: .pick { f, q, s in
                        onPick(f, q, s)
                        dismiss()
                    })
                } else {
                    FoodDetailView(food: food, mode: .add(day: day), onDone: { _ in dismiss() },
                                   onAddAnother: multiScan ? { name in
                        // Back to the scanner for the next product; the name shows as a short confirmation.
                        path = []
                        state = .scanning
                        lastCode = nil
                        withAnimation(Motion.quick) { addedName = name }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { withAnimation(Motion.quick) { addedName = nil } }
                    } : nil)
                }
            }
            .onChange(of: path) { _, p in if p.isEmpty { state = .scanning; lastCode = nil } }
        }
    }

    @ViewBuilder
    private var scannerArea: some View {
        ZStack {
            if scannerAvailable {
                BarcodeScanner(isTorchOn: torchActive) { code in lookup(code) }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                ScannerFrame()
            } else {
                VStack(spacing: 12) {
                    CatMascot(mood: .sleeping, pixel: 5)
                    Text("Kamera-Scanner nicht verfügbar").font(Theme.font(16, .semibold)).foregroundStyle(Theme.textPrimary)
                    Text("Gib den Barcode unten einfach per Hand ein.").font(Theme.font(14)).foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            }
        }
        .frame(height: 300)
    }

    @ViewBuilder
    private var statusArea: some View {
        switch state {
        case .scanning:
            Text(scannerAvailable ? "Halte den Barcode in den Rahmen" : "").font(Theme.font(15, .medium)).foregroundStyle(Theme.textSecondary)
        case .loading:
            WalkingCatLoader(pixel: 2.5, width: 200, text: "Suche Produkt …")
        case .notFound(let code):
            VStack(spacing: 8) {
                PixelSpriteView(sprite: Sprites.fish, pixel: 3)
                Text("Produkt \(code) nicht gefunden").font(Theme.font(15, .semibold)).foregroundStyle(Theme.textPrimary)
                Text("Du kannst es über ⚡ Schnell-Eintrag manuell erfassen.").font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
                Button("Nochmal scannen") { state = .scanning; lastCode = nil }.font(Theme.font(15, .semibold))
            }
            .multilineTextAlignment(.center)
        case .failed(let msg):
            VStack(spacing: 8) {
                Text(msg).font(Theme.font(14)).foregroundStyle(Theme.danger)
                Button("Nochmal versuchen") { state = .scanning; lastCode = nil }.font(Theme.font(15, .semibold))
            }
        }
    }

    private var manualEntry: some View {
        HStack(spacing: 10) {
            TextField("Barcode eingeben", text: $manualCode)
                .keyboardType(.numberPad)
                .font(Theme.font(17))
                .padding(.horizontal, 16).frame(height: 50)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Button { lookup(manualCode) } label: {
                Image(systemName: "arrow.right").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 50, height: 50).background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(SquishButtonStyle())
            .disabled(manualCode.count < 6)
        }
    }

    private func lookup(_ raw: String) {
        let code = raw.filter(\.isNumber)
        guard code.count >= 6, code != lastCode, path.isEmpty else { return }
        if case .loading = state { return }
        lastCode = code
        Haptics.tap()
        state = .loading(code)
        Task {
            do {
                if let food = try await OpenFoodFacts.product(barcode: code) {
                    Haptics.success()
                    state = .scanning
                    path = [food]
                } else {
                    Haptics.warning()
                    state = .notFound(code)
                }
            } catch {
                state = .failed("Keine Verbindung zu Open Food Facts.")
            }
        }
    }
}

struct ScannerFrame: View {
    @State private var scan = false
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width * 0.75, h: CGFloat = 130
            ZStack {
                RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 4, dash: [14, 10]))
                    .frame(width: w, height: h)
                Rectangle().fill(Theme.accent).frame(width: w - 20, height: 3)
                    .offset(y: scan ? h / 2 - 12 : -h / 2 + 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { scan = true } }
    }
}

/// Dedicated AVFoundation barcode scanner. VisionKit does not expose its camera session's
/// torch; owning the session here makes the preview and flash reliable on every iPhone.
struct BarcodeScanner: UIViewControllerRepresentable {
    var isTorchOn: Bool
    var onCode: (String) -> Void

    func makeUIViewController(context: Context) -> BarcodeCameraViewController {
        let vc = BarcodeCameraViewController(onCode: onCode)
        vc.setTorch(isTorchOn)
        return vc
    }

    func updateUIViewController(_ vc: BarcodeCameraViewController, context: Context) {
        vc.onCode = onCode
        vc.setTorch(isTorchOn)
    }

    static func dismantleUIViewController(_ vc: BarcodeCameraViewController, coordinator: ()) {
        vc.stop()
    }

    func makeCoordinator() {}
}

final class BarcodeCameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: (String) -> Void
    private let session = AVCaptureSession()
    private var device: AVCaptureDevice?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var configured = false
    private var torchOn = false

    init(onCode: @escaping (String) -> Void) {
        self.onCode = onCode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureCamera()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard configured, !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    func setTorch(_ enabled: Bool) {
        torchOn = enabled
        guard let device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = enabled ? .on : .off
            device.unlockForConfiguration()
        } catch { }
    }

    func stop() {
        setTorch(false)
        if session.isRunning { session.stopRunning() }
    }

    private func configureCamera() {
        guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else { return }
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else { return }
                DispatchQueue.main.async { self?.configureCamera() }
            }
            return
        }
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera) else { return }
        session.beginConfiguration()
        session.sessionPreset = .high
        guard session.canAddInput(input) else { session.commitConfiguration(); return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { session.commitConfiguration(); return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean13, .ean8, .upce, .code128, .code39, .interleaved2of5]
        session.commitConfiguration()
        device = camera
        configured = true
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.insertSublayer(preview, at: 0)
        previewLayer = preview
        setTorch(torchOn)
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let code = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject })
            .compactMap(\.stringValue).first else { return }
        onCode(code)
    }
}
