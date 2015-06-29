//
//  CameraViewController.swift
//  BarcodeReader
//
//  Created by Nicola Fiorillo on 28/06/15.
//  Copyright (c) 2015 White Peaks Mobile Software Sagl. All rights reserved.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController, CameraDelegate {

	var camera: Camera? = nil
	var videoPreview: UIView {
		get {
			return self.view
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		
		camera = Camera(view: videoPreview)
		camera?.cameraDelegate = self

		let tapRecognizer = UITapGestureRecognizer(target: self, action: "handleTap:")
		self.view.addGestureRecognizer(tapRecognizer)
	}

	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		camera!.start()
	}
	
	override func viewDidDisappear(animated: Bool) {
		super.viewDidDisappear(animated)
		camera!.stop()
	}

	override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
		
		coordinator.animateAlongsideTransition({ context in
			self.camera!.updateOrientation()
			}, completion: nil)
		
		super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
	}
	
	func handleTap(gesture: UITapGestureRecognizer) {
		if gesture.state == UIGestureRecognizerState.Ended {
			camera!.handleTap(gesture)
		}
	}
}
