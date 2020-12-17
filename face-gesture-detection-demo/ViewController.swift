//
//  ViewController.swift
//  face-gesture-detection-demo
//
//  Created by Alexis Jimenez on 17/12/20.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var cameraView: FacialGestureCameraView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addCameraViewDelegate()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        startGestureDetection()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        stopGestureDetection()
    }
}

extension ViewController: FacialGestureCameraViewDelegate {
    func doubleEyeBlinkDetected() {
        print("Double Eye Blink Detected")
    }
    
    func smileDetected() {
        print("Smile Detected")
    }
    
    func nodLeftDetected() {
        print("Nod Left Detected")
    }
    
    func nodRightDetected() {
        print("Nod Right Detected")
    }
    
    func leftEyeBlinkDetected() {
        print("Left Eye Blink Detected")
    }
    
    func rightEyeBlinkDetected() {
        print("Right Eye Blink Detected")
    }
}

extension ViewController {
    private func addCameraViewDelegate() {
        cameraView.delegate = self
    }
    
    private func startGestureDetection() {
        cameraView.beginSession()
    }
    
    private func stopGestureDetection() {
        cameraView.stopSession()
    }
}
