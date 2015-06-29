//
//  ViewController.swift
//  BarcodeReader
//
//  Created by Nicola Fiorillo on 23/06/15.
//  Copyright (c) 2015 White Peaks Mobile Software Sagl. All rights reserved.
//

import UIKit
import AVFoundation
import AssetsLibrary

class CameraViewControllerOld: UIViewController {

	private var camera: AVCaptureDevice! = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
	private var videoInput: AVCaptureDeviceInput? = nil
	private var imageOutput: AVCaptureStillImageOutput? = nil
	private var captureSession: AVCaptureSession? = nil
	private var videoPreview: VideoPreviewView? = nil
	
	@IBOutlet weak var toolbar: UIView!
	
	@IBOutlet weak var torchButton: UIButton!
	@IBOutlet weak var snapButton: UIButton!
	@IBOutlet weak var switchButton: UIButton!

	var captureConnection: AVCaptureConnection? {
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
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		assert(self.view.isKindOfClass(VideoPreviewView), "Wrong view class")
		videoPreview = self.view as? VideoPreviewView
		
		let effectView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.Light))
		effectView.frame = self.toolbar.bounds
		toolbar.insertSubview(effectView, atIndex: 0)
		
		authorizeAndSetupCamera()
		
		let tapRecognizer = UITapGestureRecognizer(target: self, action: "handleTap:")
		self.view.addGestureRecognizer(tapRecognizer)
		
		let notificationCenter = NSNotificationCenter.defaultCenter()
		notificationCenter.addObserver(self, selector: "subjetChanged:", name: AVCaptureDeviceSubjectAreaDidChangeNotification, object: nil)
	}
	
	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

	func subjetChanged(notification: NSNotification) {
		if camera.focusMode == AVCaptureFocusMode.Locked {
			if camera.lockForConfiguration(nil) {
				if camera.focusPointOfInterestSupported {
					camera.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
				}
				if camera.isFocusModeSupported(AVCaptureFocusMode.ContinuousAutoFocus) {
					camera.focusMode = AVCaptureFocusMode.ContinuousAutoFocus
				}
				
				camera.unlockForConfiguration()
				
				println("BarcodeReader: continuous focus mode")
			}
		}
	}
	
	func handleTap(gesture: UITapGestureRecognizer) {
		if gesture.state == UIGestureRecognizerState.Ended {
			if !camera.focusPointOfInterestSupported || !camera.isFocusModeSupported(AVCaptureFocusMode.AutoFocus) {
				println("BarcodeReader: focus point not supported by current camera")
				return
			}
			
			let locationInPreview = gesture.locationInView(videoPreview)
			let locationInCapture = videoPreview?.previewLayer?.captureDevicePointOfInterestForPoint(locationInPreview)
			
			if camera.lockForConfiguration(nil) {
				camera.focusPointOfInterest = locationInCapture!
				camera.focusMode = AVCaptureFocusMode.AutoFocus

				println("BarcodeReader: focus mode - locked to focus point")
				camera.unlockForConfiguration()
			}
		}
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	
	@IBAction func torch(sender: UIButton) {

		if camera.hasTorch {

			println("BarcodeReader: trying set torch")
			
			var error: NSError? = nil
			if !camera.lockForConfiguration(&error) {
				println("BarcodeReader: error locking camera configuration \(error?.localizedDescription)")
				return
			}
			
			toggleTorch()

			camera.unlockForConfiguration()
		}
	}
	
	func toggleTorch() {
		let torchMode = camera.torchActive ? AVCaptureTorchMode.Off : AVCaptureTorchMode.On
		if camera.isTorchModeSupported(torchMode) {
			camera.torchMode = torchMode
			println(String(format: "BarcodeReader: torch is %@", torchMode.rawValue == 0 ? "off" : "on"))
		}
	}

	@IBAction func switchCam(sender: UIButton) {
		
		captureSession?.beginConfiguration()
		
		let newCamera = alternativeCameraToCurrent
		captureSession?.removeInput(videoInput)

		if let newVideoInput = CameraViewControllerOld.addVideoInputToCaptureSession(newCamera, captureSession: captureSession) {
			camera = newCamera
			videoInput = newVideoInput
			
			CameraViewControllerOld.configureCamera(camera)
		}
		else {
			captureSession?.addInput(videoInput)
		}

		updateConnectionToInterfaceOrientation(UIApplication.sharedApplication().statusBarOrientation)
		
		captureSession?.commitConfiguration()
	}

	static func configureCamera(camera: AVCaptureDevice?) {
		
		if (camera?.isFocusModeSupported(AVCaptureFocusMode.Locked) != nil) {
			if (camera?.lockForConfiguration(nil) != nil) {
				camera?.subjectAreaChangeMonitoringEnabled = true
				camera?.unlockForConfiguration()
			}
		}
	}
	
	static func addVideoInputToCaptureSession(camera: AVCaptureDevice?, captureSession: AVCaptureSession?) -> AVCaptureDeviceInput? {
		
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
	
	@IBAction func snap(sender: UIButton) {
		
		if let videoConnection = captureConnection {

			imageOutput?.captureStillImageAsynchronouslyFromConnection(videoConnection, completionHandler: { (buffer, error) -> Void in
				if error != nil {
					println("BarcodeReader: \(error?.localizedDescription)")
					return
				}

				self.authorizeAndWriteImage(buffer)
			})
		}
		else {
			println("BarcodeReader: no video connection for still image output")
			return
		}
	}
	
	func authorizeAndWriteImage(buffer: CMSampleBuffer!) {
		
		let status = ALAssetsLibrary.authorizationStatus()
		
		switch(status) {
		case ALAuthorizationStatus.Authorized:
			println("BarcodeReader: authorized to save image in camera roll")
			writeImage(buffer)
			break
		case ALAuthorizationStatus.NotDetermined:
			if let lib = ALAssetsLibrary() as ALAssetsLibrary? {
				lib.enumerateGroupsWithTypes(ALAssetsGroupAll, usingBlock: { (group, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
					
					println("BarcodeReader: just authorized to save image in camera roll")
					stop.memory = true
					
					self.writeImage(buffer)
					
				}, failureBlock: { (error) -> Void in
					println("BarcodeReader: just unauthorized to save image in camera roll")
				})
			}
			
			break
		case ALAuthorizationStatus.Restricted:
			println("BarcodeReader: unauthorized to save image in camera roll (Restricted)")
			break;
		case ALAuthorizationStatus.Denied:
			println("BarcodeReader: unauthorized to save image in camera roll (Denied)")
			break
		default:
			break
		}
	}
	
	func writeImage(buffer: CMSampleBuffer!) {
		let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer)
		let image = UIImage(data: imageData)
		UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
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
							self.captureSession?.startRunning()
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
		snapButton.enabled = false
		switchButton.enabled = false
		
		if (camera == nil) {
			println("BarcodeReader: camera not found")
			return
		}
		
		captureSession = AVCaptureSession()

		videoInput = CameraViewControllerOld.addVideoInputToCaptureSession(camera, captureSession: captureSession)
		
		imageOutput = AVCaptureStillImageOutput()
		if captureSession?.canAddOutput(imageOutput) == false {
			println("BarcodeReader: unable to add still image output to capture session")
			return
		}
		captureSession?.addOutput(imageOutput)
		
		videoPreview?.previewLayer?.session = captureSession
		
		torchButton.enabled = camera.hasTorch;
		snapButton.enabled = true
		switchButton.enabled = alternativeCameraToCurrent != nil

		CameraViewControllerOld.configureCamera(camera)

		println("BarcodeReader: ok")
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
		if captureSession == nil {
			return;
		}
		
		println("startRunning")
		self.captureSession?.startRunning()
	}

	override func viewDidDisappear(animated: Bool) {
		super.viewDidDisappear(animated)
		
		if captureSession == nil {
			return;
		}

		println("stopRunning")
		self.captureSession?.stopRunning()
	}
	
	override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
		
		coordinator.animateAlongsideTransition({ context in
			let interfaceOrientation = UIApplication.sharedApplication().statusBarOrientation
				self.updateConnectionToInterfaceOrientation(interfaceOrientation)
			}, completion: nil)
		
		super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
	}
	
	func getVideoOrientationForUIInterfaceOrientation(interfaceOrientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation {

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
	
	func updateConnectionToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation) {

		if captureSession == nil {
			return;
		}

		let capturedOrientation = getVideoOrientationForUIInterfaceOrientation(toInterfaceOrientation)
		
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
	
	var alternativeCameraToCurrent: AVCaptureDevice? {
		get {
			if captureSession == nil {
				return nil
			}
			
			if let cameras = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) {
				for cam in cameras as! [AVCaptureDevice] {
					if cam != camera {
						return cam
					}
				}
			}
			
			return nil
		}
	}
}