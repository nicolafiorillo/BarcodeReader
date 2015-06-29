//
//  CameraViewControllerEx.swift
//  BarcodeReader
//
//  Created by Nicola Fiorillo on 27/06/15.
//  Copyright (c) 2015 White Peaks Mobile Software Sagl. All rights reserved.
//

import UIKit

class CameraViewControllerEx: CameraViewController {

	@IBOutlet weak var switchButton: UIButton!
	@IBOutlet weak var snapButton: UIButton!
	@IBOutlet weak var torchButton: UIButton!

	override func viewDidLoad() {
		super.viewDidLoad()

		torchButton.enabled = camera!.hasTorch;
		snapButton.enabled = true
//		switchButton.enabled = alternativeCameraToCurrent != nil
	}
	
	@IBAction func switchCamera(sender: UIButton) {
		camera!.switchCamera()
	}
	
	@IBAction func snap(sender: UIButton) {
		camera!.snap { buffer, err in
			println("Image is here \(buffer)")
		}
	}
	
	@IBAction func torch(sender: UIButton) {
		if camera!.hasTorch {
			camera!.toggleTorch()
		}
	}

	func barcodeDetected(barcode: Barcode) {
		if self.presentedViewController == nil {
			let alert = UIAlertController(title: barcode.Type, message: barcode.content, preferredStyle: UIAlertControllerStyle.Alert)
			alert.addAction(UIAlertAction(title: "Ok", style: .Default, handler: nil))
		
			presentViewController(alert, animated: true, completion: nil)
		}
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
}