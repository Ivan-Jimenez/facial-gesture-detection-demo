//
//  FacialGestureCameraView.swift
//  face-gesture-detection-demo
//
//  Created by Alexis Jimenez on 17/12/20.
//

import UIKit
import AVFoundation
import FirebaseMLVision

class FacialGestureCameraView: UIView {
    private var restingFace: Bool = true
    
    private lazy var vision: Vision = {
        return Vision.vision()
    }()
    
    private lazy var options: VisionFaceDetectorOptions = {
        let option = VisionFaceDetectorOptions()
        
        option.performanceMode    = .accurate
        option.landmarkMode       = .none
        option.classificationMode = .all
        option.isTrackingEnabled  = false
        option.contourMode        = .none
        
        return option
    }()
    
    private lazy var videoDataOutput: AVCaptureVideoDataOutput = {
        let videoOutput = AVCaptureVideoDataOutput()
        
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        videoOutput.connection(with: .video)?.isEnabled = true
        
        return videoOutput
    }()
    
    private let videoDataOutputQueue: DispatchQueue = DispatchQueue(label: "Constants.videoDataOutputQueue")
    
    private lazy var session: AVCaptureSession = {
        return AVCaptureSession()
    }()
    
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()
    
    private let captureDevice: AVCaptureDevice? = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
    
    public var leftNodThreshold:      CGFloat = 20.0
    public var rightNodThreshold:     CGFloat = -4
    public var smileProbability:      CGFloat = 0.8
    public var openEyeMaxProbability: CGFloat = 0.95
    public var openEyeMinProbability: CGFloat = 0.1
    
    public weak var delegate: FacialGestureCameraViewDelegate?
}

// MARK: - Logic
extension FacialGestureCameraView {
    private func detectFacesOnDevice(in image: VisionImage, width: CGFloat, height: CGFloat) {
        let faceDetector = vision.faceDetector(options: options)
        
        faceDetector.process(image, completion: { features, error in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            
            guard error == nil, let features = features, !features.isEmpty else { return }
            
            if let face = features.first {
                let leftEyeOpenProbability = face.leftEyeOpenProbability
                let rightEyeOpenProbability = face.rightEyeOpenProbability
                
                // left head node
                if face.headEulerAngleZ > self.leftNodThreshold {
                    if self.restingFace {
                        self.restingFace = false
                        self.delegate?.nodLeftDetected?()
                    }
                } else if face.headEulerAngleZ < self.rightNodThreshold {
                    // right head tilt
                    if self.restingFace {
                        self.restingFace = false
                        self.delegate?.nodRightDetected?()
                    }
                } else if leftEyeOpenProbability > self.openEyeMaxProbability && rightEyeOpenProbability < self.openEyeMinProbability {
                    // right eye blink
                    if self.restingFace {
                        self.restingFace = false
                        self.delegate?.rightEyeBlinkDetected?()
                    }
                } else if rightEyeOpenProbability > self.openEyeMaxProbability && leftEyeOpenProbability < self.openEyeMinProbability {
                    // left eye blink
                    if self.restingFace {
                        self.restingFace = false
                        self.delegate?.leftEyeBlinkDetected?()
                    }
                } else if face.smilingProbability > self.smileProbability {
                    // smile detected
                    if self.restingFace {
                        self.restingFace = false
                        self.delegate?.smileDetected?()
                    }
                } else if leftEyeOpenProbability < self.openEyeMinProbability && rightEyeOpenProbability < self.openEyeMinProbability {
                    // full/both eye blink
                    if self.restingFace {
                        self.restingFace = false
                        self.delegate?.doubleEyeBlinkDetected?()
                    }
                } else {
                    // face got reseted
                    self.restingFace = true
                }
            }
        })
    }
}

// MARK: - Handlers
extension FacialGestureCameraView {
    func beginSession() {
        guard let deviceCapture = captureDevice else { return }
        guard let deviceInput = try? AVCaptureDeviceInput(device: deviceCapture) else { return }
        
        if session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
        }
        
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }
        
        layer.masksToBounds = true
        layer.addSublayer(previewLayer)
        
        previewLayer.frame = bounds
        
        session.startRunning()
    }
    
    func stopSession() {
        session.stopRunning()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension FacialGestureCameraView: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get image buffer from sample buffer.")
            return
        }
        
        let visionImage = VisionImage(buffer: sampleBuffer)
        let metadata = VisionImageMetadata()
        let visionOrientation = visionImageOrientation(from: imageOrientation())
        
        metadata.orientation = visionOrientation
        visionImage.metadata =  metadata
        
        let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
        let imageHeight =  CGFloat(CVPixelBufferGetHeight(imageBuffer))
        
        DispatchQueue.global().async {
            self.detectFacesOnDevice(in: visionImage, width: imageWidth, height: imageHeight)
        }
    }
}

// MARK: - Util Functions
extension FacialGestureCameraView {
    private func visionImageOrientation(from imageOrientation: UIImage.Orientation) -> VisionDetectorImageOrientation {
        switch imageOrientation {
        case .up:            return .topLeft
        case .down:          return .bottomRight
        case .left:          return .leftBottom
        case .right:         return .topRight
        case .upMirrored:    return .topRight
        case .downMirrored:  return .bottomLeft
        case .leftMirrored:  return .leftTop
        case .rightMirrored: return .rightBottom
        @unknown default:
            fatalError()
        }
    }
    
    private func imageOrientation(fromDevicePosition devicePosition: AVCaptureDevice.Position = .front) -> UIImage.Orientation {
        var deviceOrientation = UIDevice.current.orientation
        
        if deviceOrientation == .faceDown || deviceOrientation == .faceUp || deviceOrientation == .unknown {
            deviceOrientation = currentUIOrientation()
        }
        
        switch deviceOrientation {
        case .portrait:                    return devicePosition == .front ? .leftMirrored  : .right
        case .landscapeLeft:               return devicePosition == .front ? .downMirrored  : .up
        case .portraitUpsideDown:          return devicePosition == .front ? .rightMirrored : .left
        case .landscapeRight:              return devicePosition == .front ? .upMirrored    : .down
        case .faceDown, .faceUp, .unknown: return .up
        @unknown default:
            fatalError()
        }
    }
    
    private func currentUIOrientation() -> UIDeviceOrientation {
        let deviceOrientation = { () -> UIDeviceOrientation in
            switch UIApplication.shared.windows.first?.windowScene?.interfaceOrientation {
            case .landscapeLeft:             return .landscapeRight
            case .landscapeRight:            return .landscapeLeft
            case .portraitUpsideDown:        return .portraitUpsideDown
            case .portrait, .unknown, .none: return .portrait
            @unknown default:
                fatalError()
            }
        }
        
        guard Thread.isMainThread else {
            var currentOrientation: UIDeviceOrientation = .portrait
            
            DispatchQueue.main.async {
                currentOrientation = deviceOrientation()
            }
            return currentOrientation
        }
        return deviceOrientation()
    }
}

// MARK: - Delegate
@objc public protocol FacialGestureCameraViewDelegate: class {
    @objc optional func doubleEyeBlinkDetected()
    @objc optional func smileDetected()
    @objc optional func nodLeftDetected()
    @objc optional func nodRightDetected()
    @objc optional func leftEyeBlinkDetected()
    @objc optional func rightEyeBlinkDetected()
}
