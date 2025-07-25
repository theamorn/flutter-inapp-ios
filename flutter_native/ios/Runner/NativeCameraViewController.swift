//
//  NativeCameraViewController.swift
//  flutter_native
//
//  Created for performance comparison demo
//

import AVFoundation
import UIKit

@objc class NativeCameraViewController: UIViewController {

    // Camera components
    private var captureSession: AVCaptureSession!
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    private var photoOutput: AVCapturePhotoOutput!
    private var videoDataOutput: AVCaptureVideoDataOutput!

    // UI Elements
    private let previewView = UIView()
    private let captureButton = UIButton(type: .system)
    private let switchCameraButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let performanceLabel = UILabel()

    private var startTime: Date!
    private var isFirstFrameRendered = false
    private var firstFrameTime: Int?
    
    // Completion handler to return timing data
    var completionHandler: (([String: Any]) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCamera()
        performanceLabel.text = "Initializing camera..."
        
        // Start timing and camera session immediately for fastest startup
        startTime = Date()
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession?.startRunning()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Ensure the preview layer frame is set correctly
        DispatchQueue.main.async {
            self.videoPreviewLayer?.frame = self.previewView.bounds
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession?.stopRunning()
        }
    }

    private func setupUI() {
        view.backgroundColor = .black

        // Setup preview view
        previewView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewView)

        // Setup close button
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("✕", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 20
        closeButton.layer.masksToBounds = true
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        // Setup capture button
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 35
        captureButton.layer.borderWidth = 5
        captureButton.layer.borderColor = UIColor.systemBlue.cgColor
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        view.addSubview(captureButton)

        // Setup switch camera button
        switchCameraButton.translatesAutoresizingMaskIntoConstraints = false
        switchCameraButton.setTitle("🔄", for: .normal)
        switchCameraButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        switchCameraButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        switchCameraButton.layer.cornerRadius = 25
        switchCameraButton.layer.masksToBounds = true
        switchCameraButton.addTarget(
            self, action: #selector(switchCameraButtonTapped), for: .touchUpInside)
        view.addSubview(switchCameraButton)

        // Setup performance label
        performanceLabel.translatesAutoresizingMaskIntoConstraints = false
        performanceLabel.textColor = .white
        performanceLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        performanceLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        performanceLabel.textAlignment = .center
        performanceLabel.layer.cornerRadius = 8
        performanceLabel.layer.masksToBounds = true
        view.addSubview(performanceLabel)

        // Setup constraints
        NSLayoutConstraint.activate([
            // Preview view
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Close button
            closeButton.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),

            // Performance label
            performanceLabel.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            performanceLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            performanceLabel.heightAnchor.constraint(equalToConstant: 40),
            performanceLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),

            // Capture button
            captureButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70),

            // Switch camera button
            switchCameraButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            switchCameraButton.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -30),
            switchCameraButton.widthAnchor.constraint(equalToConstant: 50),
            switchCameraButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    private func setupCamera() {
        captureSession = AVCaptureSession()
        // Use high preset for faster initialization while maintaining quality
        captureSession.sessionPreset = .photo

        guard let backCamera = AVCaptureDevice.default(for: .video) else {
            print("Unable to access back camera!")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            photoOutput = AVCapturePhotoOutput()
            
            // Add video data output to detect first frame
            videoDataOutput = AVCaptureVideoDataOutput()
            // Use a more efficient pixel format for faster processing
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.frame.processing.queue", qos: .userInitiated))

            if captureSession.canAddInput(input) && 
               captureSession.canAddOutput(photoOutput) && 
               captureSession.canAddOutput(videoDataOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(photoOutput)
                captureSession.addOutput(videoDataOutput)

                setupLivePreview()
            }
        } catch let error {
            print("Error Unable to initialize back camera:  \\(error.localizedDescription)")
        }
    }

    private func setupLivePreview() {
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.connection?.videoOrientation = .portrait

        previewView.layer.addSublayer(videoPreviewLayer)

        // Set frame immediately for faster display
        videoPreviewLayer.frame = previewView.bounds
    }

    private func updatePerformanceLabelWithFirstFrame() {
        guard !isFirstFrameRendered else { return }
        isFirstFrameRendered = true
        
        let elapsed = Date().timeIntervalSince(startTime) * 1000 // Convert to milliseconds
        firstFrameTime = Int(elapsed)
        
        DispatchQueue.main.async {
            self.performanceLabel.text = String(format: "Native Camera: %.0fms (First Frame)", elapsed)
        }
    }

    @objc private func closeButtonTapped() {
        // Return timing data before dismissing
        var timingData: [String: Any] = [:]
        if let firstFrameTime = firstFrameTime {
            timingData["firstFrameTime"] = firstFrameTime
        }
        timingData["isFirstFrameRendered"] = isFirstFrameRendered
        
        completionHandler?(timingData)
        dismiss(animated: true)
    }

    @objc private func captureButtonTapped() {
        // Add capture animation
        UIView.animate(
            withDuration: 0.1,
            animations: {
                self.captureButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }
        ) { _ in
            UIView.animate(withDuration: 0.1) {
                self.captureButton.transform = CGAffineTransform.identity
            }
        }

        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        photoOutput.capturePhoto(with: settings, delegate: self)

        // Flash effect
        let flashView = UIView(frame: view.bounds)
        flashView.backgroundColor = .white
        view.addSubview(flashView)

        UIView.animate(
            withDuration: 0.1,
            animations: {
                flashView.alpha = 0
            }
        ) { _ in
            flashView.removeFromSuperview()
        }
    }

    @objc private func switchCameraButtonTapped() {
        // Add rotation animation
        UIView.animate(withDuration: 0.3) {
            self.switchCameraButton.transform = self.switchCameraButton.transform.rotated(by: .pi)
        }

        // Camera switching logic would go here
        print("Switch camera tapped")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoPreviewLayer?.frame = previewView.bounds
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension NativeCameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Immediately detect the first frame without delay
        updatePerformanceLabelWithFirstFrame()
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension NativeCameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        let image = UIImage(data: imageData)

        // Save to photo library or handle the captured image
        print("Photo captured successfully!")

        // Show success feedback
        let alert = UIAlertController(
            title: "📸 Photo Captured!", message: "Native camera performance optimized",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
