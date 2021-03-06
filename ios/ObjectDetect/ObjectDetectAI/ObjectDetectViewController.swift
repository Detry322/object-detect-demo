//
//  ViewController.swift
//  ObjectDetectAI
//
//  Created by diego @ webelectric
//
//

import UIKit
import AVFoundation

enum PredictionLabel : String {
    case businessCard = "business card"
    case creditCard = "credit card"
}

class Prediction {
    var prediction:PredictionLabel
    weak var progressView:UIProgressView! {
        didSet {
            progressView.progress = 0
        }
    }
    var confidence:Float = 0
    var label:String {
        get {
            return prediction.rawValue
        }
    }
    
    init(_ predictionLabel:String) {
        self.prediction = PredictionLabel(rawValue: predictionLabel)!
    }
}

class ObjectDetectViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var previewView:UIView!
    @IBOutlet weak var actionButton:UIButton!
    @IBOutlet weak var infoButton:UIButton!
    
    var boundingBoxOverlay:BoundingBoxOverlay!
    
    var previewLayer:AVCaptureVideoPreviewLayer!
    var videoDataOutput:AVCaptureVideoDataOutput!
    var videoDataOutputQueue:DispatchQueue!

    var session:AVCaptureSession!
    var deviceInput:AVCaptureDeviceInput!
    var rootLayer:CALayer!

    var tensorFlow:TensorFlowProcessor!
    
    let TF_MODEL_GRAPH_FILE:String = "faster-rcnn-inception.pb"
    let TF_MODEL_LABEL_FILE:String = "labels.txt"

    var isProcessingFrame:Bool = false
    
    var totalFrames:Int = 0
    var framesDropped:Int = 0
    
    var lastFrameReceivedAt:TimeInterval = 0
    var lastFrameTimeDifference:TimeInterval = 0
    
    var isDetecting:Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        actionButton?.layer.cornerRadius = 4
        actionButton?.layer.masksToBounds = true
        
        tensorFlow = TensorFlowProcessor()
        tensorFlow.prepare(withLabelsFile: TF_MODEL_LABEL_FILE, andGraphFile: TF_MODEL_GRAPH_FILE)
        
        rootLayer = previewView.layer
        rootLayer.masksToBounds = true

        setupAVCapture()
        
        if let results = tensorFlow.processImage("test_image.jpg") {
            boundingBoxOverlay?.assignBoxes(results)
            DispatchQueue.main.async {
                self.boundingBoxOverlay.setNeedsDisplay()
            }
        }
    }
    
    @IBAction func infoButtonPressed(_ sender: AnyObject) {
        let alertController = UIAlertController(title: "How to use ObjectDetectAI", message: "Place objects like books, cards and other items on a table with good light and see what the app can detect!", preferredStyle: .alert)
        
        let OKAction = UIAlertAction(title: "OK", style: .default) { action in
            alertController.dismiss(animated: true) {}
        }
        alertController.addAction(OKAction)

        self.present(alertController, animated: true) {
            //
        }
    }
    
    @IBAction func actionButtonPressed(_ sender: AnyObject) {
        actionButton.isEnabled = false
        let newState = !isDetecting
        changeDetection(toState: newState, animate: true)
    }
    
    //used when the app goes into background mode
    func disableDetection() {
        changeDetection(toState: false)
    }
    
    func changeDetection(toState newState:Bool, animate:Bool = false) {
        let buttonLabel = newState ? "Stop Detecting" : "Start Detecting"
        
        let completionBlock = {
            self.actionButton.setTitle(buttonLabel, for: .normal)
            self.actionButton.isEnabled = true
            self.isDetecting = newState
        }
        
        if animate {
            UIView.animate(withDuration: 0.5, delay: 0, options: UIViewAnimationOptions.transitionCrossDissolve, animations: {
            }) { (completed) in
                if completed {
                    completionBlock()
                }
            }
        }
        else {
            DispatchQueue.main.sync {
                completionBlock()
            }
        }
    }
    
    public func checkCameraAccess(_ completion:@escaping ((_ accessGranted:Bool) -> Void)) {
        #if os(iOS)
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: {
                (granted: Bool) -> Void in
                
                completion(granted)
                
            });
        #else
            //TODO add checks necessary for OS X
            completion(true)
        #endif
    }

    
    func setupAVCapture() {
    
        var error = false
        
        session = AVCaptureSession()
        
        if session.canSetSessionPreset(AVCaptureSessionPreset640x480) {
            session.sessionPreset = AVCaptureSessionPreset640x480
        }
        else {
            NSLog("Error, session preset can't be set to required values.")
            return
        }
        defer {
            if error {
                let alertController = UIAlertController(title: "Error", message: "AVCaptureSession creation failed", preferredStyle: .alert)
                let OKAction = UIAlertAction(title: "OK", style: .default) { action in
                    alertController.dismiss(animated: true) {}
                }
                alertController.addAction(OKAction)
                
                self.present(alertController, animated: true) {
                    // ...
                }

            }
        }
        
        let device:AVCaptureDevice =  AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        
        
        do {
            self.deviceInput = try AVCaptureDeviceInput(device: device)
        }
        catch let err {
            NSLog("Error getting device input: \(err)")
            error = true
            return
        }
        if session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
        }
        else {
            NSLog("Error, session.canAddInput(deviceInput) returned false")
            error = true
            return
        }
        
        
        videoDataOutput = AVCaptureVideoDataOutput()

        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: NSNumber(value: kCVPixelFormatType_32BGRA)]

        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        videoDataOutputQueue = DispatchQueue(label: "com.webelectric.VideoDataOutputQueue")
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }
        else {
            NSLog("Error, session.canAddOutput(videoDataOutput) returned false")
            error = true
            return
        }
        
        videoDataOutput.connection(withMediaType: AVMediaTypeVideo)
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.backgroundColor = UIColor.black.cgColor
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspect

        previewLayer.frame = rootLayer.bounds
        rootLayer.insertSublayer(previewLayer, at: 0)
        
        boundingBoxOverlay = BoundingBoxOverlay()
        boundingBoxOverlay.layer.frame = previewLayer.bounds
        self.previewView.addSubview(boundingBoxOverlay)
        self.previewLayer.addSublayer(boundingBoxOverlay.layer)
        
        session.startRunning()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        previewLayer?.frame.size = previewView.frame.size
    }

    func teardownAVCapture() {
        session.stopRunning()
        session.removeOutput(self.videoDataOutput)
        previewLayer.removeFromSuperlayer()
    }
    
    public func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        let time = CACurrentMediaTime()
        lastFrameTimeDifference = time - lastFrameReceivedAt
        lastFrameReceivedAt = time

        processOrDiscardFrame(sampleBuffer)
    }
    
    
    func processOrDiscardFrame(_  sampleBuffer: CMSampleBuffer) {
        
        if !isDetecting {
            return
        }
        
        totalFrames = totalFrames + 1
        
        //output calls happen on a serial queue, if we're lagging behind in processing we just discard the frame
        //no need for complex thread coordination given the simple structure of the example
        if isProcessingFrame {
            framesDropped = framesDropped + 1
            return
        }
        isProcessingFrame = true
        
        defer {
            isProcessingFrame = false
        }

        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            if let results = tensorFlow.processFrame(pixelBuffer) {
                boundingBoxOverlay?.assignBoxes(results)
                DispatchQueue.main.async {
                    self.boundingBoxOverlay.setNeedsDisplay()
                }
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

}

