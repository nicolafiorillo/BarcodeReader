//
//  CameraProtocol.swift
//  BarcodeReader
//
//  Created by Nicola Fiorillo on 29/06/15.
//  Copyright (c) 2015 White Peaks Mobile Software Sagl. All rights reserved.
//

import Foundation

@objc protocol CameraDelegate : NSObjectProtocol {
	optional func barcodeDetected(barcode: Barcode)
}