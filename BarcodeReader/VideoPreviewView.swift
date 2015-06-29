//
//  VideoPreviewView.swift
//  BarcodeReader
//
//  Created by Nicola Fiorillo on 24/06/15.
//  Copyright (c) 2015 White Peaks Mobile Software Sagl. All rights reserved.
//

import UIKit
import AVFoundation

class VideoPreviewView: UIView {

	var previewLayer: AVCaptureVideoPreviewLayer? {
		get {
			return self.layer as? AVCaptureVideoPreviewLayer
		}
	}
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setup()
	}
	
	required init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		setup()
	}
	
	override class func layerClass() -> AnyClass {
		return AVCaptureVideoPreviewLayer.self
	}
	
	func setup() {
		println("VideoPreviewView setup")
		
		self.autoresizingMask = UIViewAutoresizing.FlexibleHeight | UIViewAutoresizing.FlexibleWidth
		self.backgroundColor = UIColor.blackColor()
		
		self.previewLayer!.videoGravity = AVLayerVideoGravityResizeAspectFill
	}
}