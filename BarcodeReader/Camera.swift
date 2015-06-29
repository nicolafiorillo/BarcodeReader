//
//  Camera.swift
//  BarcodeReader
//
//  Created by Nicola Fiorillo on 28/06/15.
//  Copyright (c) 2015 White Peaks Mobile Software Sagl. All rights reserved.
//

import UIKit
import AVFoundation

class Camera : NSObject, AVCaptureMetadataOutputObjectsDelegate {

	var cameraDelegate: CameraDelegate? = nil
	
	private let videoPreview: VideoPreviewView?

	private var cameraDevice: AVCaptureDevice! = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
	private var captureSession: AVCaptureSession? = nil
	private var videoInput: AVCaptureDeviceInput? = nil
	private var imageOutput: AVCaptureStillImageOutput? = nil
	private var metadataOutput: AVCaptureMetadataOutput? = nil
	private var metadataQueue: dispatch_queue_t? = nil

	private static let barcodes2D: Set<String> = [
		AVMetadataObjectTypePDF417Code,
		AVMetadataObjectTypeQRCode,
		AVMetadataObjectTypeAztecCode,
		AVMetadataObjectTypeEAN13Code,
		AVMetadataObjectTypeEAN8Code ]
	
	private var captureConnection: AVCaptureConnection? {
		get {
			if imageOutput == nil {
				return nil
			}
			
			if let connections = imageOutput?.connections {
				for	connection in connections {
					if let ports = connection.inputPorts {
						for port in ports {
							if port.mediaType == AVMediaTypeVideo {
								return connection as? AVCaptureConnection
							}
						}
					}
				}
			}
			
			return nil
		}
	}

	private var alternativeCameraToCurrent: AVCaptureDevice? {
		get {
			if captureSession == nil {
				return nil
			}
			
			if let cameras = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) {
				for cam in cameras as! [AVCaptureDevice] {
					if cam != cameraDevice {
						return cam
					}
				}
			}
			
			return nil
		}
	}

	init(view: UIView) {
		
		assert(view.isKindOfClass(VideoPreviewView), "View must be of type VideoPreviewView")
		videoPreview = view as? VideoPreviewView

		super.init()

		if cameraDevice == nil {
			println("BarcodeReader: camera not found")
			return
		}
		
		authorizeAndSetupCamera()

		let notificationCenter = NSNotificationCenter.defaultCenter()
		notificationCenter.addObserverForName(AVCaptureDeviceSubjectAreaDidChangeNotification, object: nil, queue: NSOperationQueue.currentQueue()) { notification in
				self.subjetChanged(notification)
		}
	}
	
	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

	func authorizeAndSetupCamera() {
		
		let status = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
		
		switch (status) {
		case AVAuthorizationStatus.Authorized:
			println("BarcodeReader: authorized to use camera")
			setupCamera()
			break;
		case AVAuthorizationStatus.NotDetermined:
			AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { granted in
				
				dispatch_async(dispatch_get_main_queue(), {
					if granted {
						self.setupCamera()
//						self.captureSession?.startRunning()
					}
					else {
						println("BarcodeReader: unauthorized to use camera")
					}
				})
			})
			break;
		case AVAuthorizationStatus.Restricted:
			println("BarcodeReader: unauthorized to use camera (Restricted)")
			break;
		case AVAuthorizationStatus.Denied:
			println("BarcodeReader: unauthorized to use camera (Denied)")
			break;
		default:
			break;
		}
	}

	func setupCamera() {
		
		if (cameraDevice == nil) {
			println("BarcodeReader: camera not found")
			return
		}
		
		captureSession = AVCaptureSession()
		
		videoInput = Camera.addVideoInputToCaptureSession(cameraDevice, captureSession: captureSession)
		
		// image outmpu
		imageOutput = AVCaptureStillImageOutput()
		if captureSession?.canAddOutput(imageOutput) == false {
			println("BarcodeReader: unable to add still image output to capture session")
			return
		}
		captureSession?.addOutput(imageOutput)

		// metadata output
		metadataOutput = AVCaptureMetadataOutput()
		metadataQueue = dispatch_get_main_queue()
		metadataOutput?.setMetadataObjectsDelegate(self, queue: metadataQueue)
		
		if captureSession?.canAddOutput(metadataOutput) == false {
			println("BarcodeReader: unable to add metadata output to capture session")
			return
		}
		captureSession?.addOutput(metadataOutput)
		Camera.configureMetadata(metadataOutput!)
		
		videoPreview?.previewLayer?.session = captureSession
				
		Camera.configureCamera(cameraDevice)
		
		println("BarcodeReader: ok")
	}
	
	func start() {
		if captureSession == nil {
			println("BarcodeReader: camera not initialized")
			return;
		}
		
		println("BarcodeReader: start camera")
		self.captureSession?.startRunning()
	}
	
	func stop() {
		if captureSession == nil {
			println("BarcodeReader: camera not initialized")
			return;
		}
		
		println("BarcodeReader: stop camera")
		self.captureSession?.stopRunning()
	}

	func switchCamera() {

		if (cameraDevice == nil) {
			println("BarcodeReader: camera not found")
			return
		}

		if captureSession == nil {
			println("BarcodeReader: camera not initialized")
			return;
		}

		captureSession?.beginConfiguration()
		
		let newCamera = alternativeCameraToCurrent
		captureSession?.removeInput(videoInput)
		
		if let newVideoInput = Camera.addVideoInputToCaptureSession(newCamera, captureSession: captureSession) {
			cameraDevice = newCamera
			videoInput = newVideoInput
			
			CameraViewControllerOld.configureCamera(cameraDevice)
		}
		else {
			captureSession?.addInput(videoInput)
		}
		
		updateConnectionToInterfaceOrientation(UIApplication.sharedApplication().statusBarOrientation)
		
		captureSession?.commitConfiguration()
	}

	var hasTorch: Bool {
		get {
			return hasTorchInternal
		}
	}
	
	func snap(completionHandler handler: ((CMSampleBuffer!, NSError!) -> Void)!) {

		if captureSession == nil {
			println("BarcodeReader: camera not initialized")
			return;
		}

		if let videoConnection = captureConnection {
			imageOutput?.captureStillImageAsynchronouslyFromConnection(videoConnection, completionHandler: handler)
		}
		else {
			println("BarcodeReader: no video connection for still image output")
			handler(nil, NSError(domain: "BarcodeReader", code: 1, userInfo: nil))
		}
	}

	private var hasTorchInternal: Bool {
		get {
			return cameraDevice != nil ? cameraDevice.hasTorch : false
		}
	}

	func toggleTorch() {
	
		if captureSession == nil {
			println("BarcodeReader: camera not initialized")
			return;
		}

		if hasTorchInternal {
	
			println("BarcodeReader: trying set torch")
	
			var error: NSError? = nil
			if !cameraDevice.lockForConfiguration(&error) {
				println("BarcodeReader: error locking camera configuration \(error?.localizedDescription)")
				return
			}
	
			Camera.toggleTorchInternal(cameraDevice)
	
			cameraDevice.unlockForConfiguration()
		}
	}
	
	func updateOrientation() {
		let interfaceOrientation = UIApplication.sharedApplication().statusBarOrientation
		updateConnectionToInterfaceOrientation(interfaceOrientation)
	}
	
	func handleTap(gesture: UITapGestureRecognizer) {
		
		if !cameraDevice.focusPointOfInterestSupported || !cameraDevice.isFocusModeSupported(AVCaptureFocusMode.AutoFocus) {
			println("BarcodeReader: focus point not supported by current camera")
			return
		}
	
		let locationInPreview = gesture.locationInView(videoPreview)
		let locationInCapture = videoPreview?.previewLayer?.captureDevicePointOfInterestForPoint(locationInPreview)
	
		if cameraDevice.lockForConfiguration(nil) {
			cameraDevice.focusPointOfInterest = locationInCapture!
			cameraDevice.focusMode = AVCaptureFocusMode.AutoFocus
	
			println("BarcodeReader: focus mode - locked to focus point")
			cameraDevice.unlockForConfiguration()
		}
	}
	
	private static func toggleTorchInternal(camera: AVCaptureDevice) {
		let torchMode = camera.torchActive ? AVCaptureTorchMode.Off : AVCaptureTorchMode.On
		if camera.isTorchModeSupported(torchMode) {
			camera.torchMode = torchMode
			println(String(format: "BarcodeReader: torch is %@", torchMode.rawValue == 0 ? "off" : "on"))
		}
	}

	private static func addVideoInputToCaptureSession(camera: AVCaptureDevice?, captureSession: AVCaptureSession?) -> AVCaptureDeviceInput? {
		
		var error: NSError? = nil
		let videoInput = AVCaptureDeviceInput(device:camera, error: &error)
		if videoInput == nil {
			println("BarcodeReader: \(error?.localizedDescription)")
			return nil
		}
		
		if captureSession?.canAddInput(videoInput) == false {
			println("BarcodeReader: unable to add video input to capture session")
			return nil
		}
		
		captureSession?.addInput(videoInput)
		
		return videoInput
	}
	
	private static func configureCamera(camera: AVCaptureDevice?) {
		
		if (camera?.isFocusModeSupported(AVCaptureFocusMode.Locked) != nil) {
			if (camera?.lockForConfiguration(nil) != nil) {
				camera?.subjectAreaChangeMonitoringEnabled = true
				camera?.unlockForConfiguration()
			}
		}
	}
	
	private static func getVideoOrientationForUIInterfaceOrientation(interfaceOrientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation {
		
		switch (interfaceOrientation) {
		case UIInterfaceOrientation.LandscapeLeft:
			return AVCaptureVideoOrientation.LandscapeLeft
		case UIInterfaceOrientation.LandscapeRight:
			return AVCaptureVideoOrientation.LandscapeRight
		case UIInterfaceOrientation.Portrait:
			return AVCaptureVideoOrientation.Portrait
		case UIInterfaceOrientation.PortraitUpsideDown:
			return AVCaptureVideoOrientation.PortraitUpsideDown
		default:
			return AVCaptureVideoOrientation.Portrait
		}
	}
	
	private func updateConnectionToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation) {
		
		if captureSession == nil {
			return;
		}
		
		let capturedOrientation = Camera.getVideoOrientationForUIInterfaceOrientation(toInterfaceOrientation)
		
		if let connections = imageOutput?.connections {
			for	connection in connections as! [AVCaptureConnection] {
				if connection.supportsVideoOrientation {
					connection.videoOrientation = capturedOrientation
				}
			}
		}
		
		if let layer = videoPreview?.previewLayer {
			if layer.connection.supportsVideoOrientation {
				videoPreview?.previewLayer?.connection.videoOrientation = capturedOrientation
			}
		}
	}
	
	private func subjetChanged(notification: NSNotification) {
		if cameraDevice.focusMode == AVCaptureFocusMode.Locked {
			if cameraDevice.lockForConfiguration(nil) {
				if cameraDevice.focusPointOfInterestSupported {
					cameraDevice.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
				}
				if cameraDevice.isFocusModeSupported(AVCaptureFocusMode.ContinuousAutoFocus) {
					cameraDevice.focusMode = AVCaptureFocusMode.ContinuousAutoFocus
				}
				
				cameraDevice.unlockForConfiguration()
				
				println("BarcodeReader: continuous focus mode")
			}
		}
	}
	
	private static func configureMetadata(metadataOutput: AVCaptureMetadataOutput) {

		let availableTypes = metadataOutput.availableMetadataObjectTypes as! [String]
		
		if availableTypes.count == 0 {
			println("BarcodeReader: no metadata types available")
			return
		}

		let supported = barcodes2D.intersect(availableTypes)
		
		println("Supported requested barcodes type: \(supported)")
		println("Unsupported requested barcodes type: \(barcodes2D.subtract(supported))")
		
		metadataOutput.metadataObjectTypes = Array(supported)
		metadataOutput.rectOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
	}
	
	func captureOutput(captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [AnyObject]!, fromConnection connection: AVCaptureConnection!) {
		
		for metadataObject in metadataObjects as! [AVMetadataObject] {
			if metadataObject.isKindOfClass(AVMetadataMachineReadableCodeObject) {
				let barcode = metadataObject as! AVMetadataMachineReadableCodeObject
				
				if cameraDelegate != nil {
					cameraDelegate!.barcodeDetected!(Barcode(type: barcode.type, content: barcode.stringValue))
				}
			}
		}
	}
}