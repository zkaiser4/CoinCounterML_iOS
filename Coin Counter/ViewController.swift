//
//  ViewController.swift
//  Coin Counter
//
//  Created by ZKApps on 6/4/20.
//  Copyright © 2020 ZKApps. All rights reserved.
//
import CoreML
import Vision
import UIKit
import AVFoundation


class ViewController: UIViewController , AVCapturePhotoCaptureDelegate{
    
    //Defining class variables
    @IBOutlet weak var previewView: UIView!
    
    @IBOutlet weak var coinValue: UILabel!
    var captureSession: AVCaptureSession!
    var stillImageOutput: AVCapturePhotoOutput!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    
   
    @IBAction func captureImage(_ sender: Any) {
          let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        stillImageOutput.capturePhoto(with: settings, delegate: self)
        
        
    }
    
    
  
    
    override func viewDidLoad() {
        super.viewDidLoad()
        coinValue.text = ""
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .medium
        guard let backCamera = AVCaptureDevice.default(for: AVMediaType.video)
            else {
                print("Back Camera is not accessible")
                return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            stillImageOutput = AVCapturePhotoOutput()
            if captureSession.canAddInput(input) && captureSession.canAddOutput(stillImageOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(stillImageOutput)
                setupLivePreview()
                }
            
        }
        catch let error  {
            print("Error: \(error.localizedDescription)")
        }
        
        

    
    }
    
    
    //This functions sets up the live preview in the video frame
    func setupLivePreview() {
        
        
        /*guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
           self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
           self.previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
           self.previewLayer?.connection?.videoOrientation = .portrait
        
           view.layer.insertSublayer(self.previewLayer!, at: 0)
           self.previewLayer?.frame = view.frame*/
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer.connection?.videoOrientation = .portrait
        previewView.layer.addSublayer(videoPreviewLayer)
        DispatchQueue.global(qos: .userInitiated).async { //[weak self] in
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.videoPreviewLayer.frame = self.previewView.bounds
            }
        }
        
    }
   
    //This is the delegate function to capture the image for AVPhotoCapture
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        guard let imageData = photo.fileDataRepresentation()
            else { return }
        
        let image = UIImage(data: imageData)!
        classify(image: image)
        
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.captureSession.stopRunning()
    }
    
     //This sets up the CoreML Object Identification Request
     lazy var objectIndentificationRequest: VNCoreMLRequest = {
      
      let visionModel = try! VNCoreMLModel(for: MLModel(contentsOf: Bundle.main.url(forResource: "CoinDetector", withExtension: "mlmodelc")!))
      
      let request = VNCoreMLRequest(model: visionModel) { [unowned self] request, _ in
        self.processObservations(for: request)
      }
      request.imageCropAndScaleOption = .scaleFill
      return request
    } ()
    
    
    func classify(image: UIImage) {
      DispatchQueue.global(qos: .userInitiated).async {
        let ciImage = CIImage(image: image)!
        let orientation = CGImagePropertyOrientation(rawValue: UInt32(image.imageOrientation.rawValue))
        let handler = VNImageRequestHandler(ciImage: ciImage,
                                            orientation: orientation!)
        try! handler.perform([self.objectIndentificationRequest])
      }
    }
    
    //This function is called by the Object Identification Request's completion handler
    func processObservations(for request: VNRequest) {
      DispatchQueue.main.async {
      var total : Double? = 0
      if let results = request.results {
          
          for observation in results where observation is VNRecognizedObjectObservation {
              guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                  continue
              }
              
              let topLabelObservation = objectObservation.labels[0]
              
              total! += self.convertCoin(coinDenomination: topLabelObservation.identifier)
                  
              
              
          }
        self.coinValue.text = "$\((total!*100).rounded()/100)"
        print("$\((total!*100).rounded()/100)")
          
      }
      }
    }
      
      // This function converts the identified coin string to a double
      func convertCoin(coinDenomination: String) -> Double {
          switch coinDenomination {
          case "Quarter":
              return 0.25
          case "Dime":
               return 0.10
          case "Nickel":
              return 0.05
          case "Penny" :
              return 0.01
          default:
             return 0
          }
      }
    
    
    //These functions enable the reset of the coin value when the user shakes the device
       
       override func becomeFirstResponder() -> Bool {
           return true
       }
       
       override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?){
           if motion == .motionShake {
               print("Shake event detected. Clearing label")
               coinValue.text = ""
           }
       }
}

