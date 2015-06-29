//
//  Barcode.swift
//  BarcodeReader
//
//  Created by Nicola Fiorillo on 29/06/15.
//  Copyright (c) 2015 White Peaks Mobile Software Sagl. All rights reserved.
//

import Foundation

class Barcode : NSObject {
	
	private var type: String = ""
	var Type: String {
		get {
			return type
		}
		set {
			type = Barcode.extractType(newValue)!
		}
	}
	var content: String = ""
	
	init(type: String, content: String) {
		super.init()
		
		self.Type = type
		self.content = content
	}
	
	private static func extractType(type: String) -> String? {
		
		var pattern = "(.*)\\.(.+)$"
		
		var error: NSError? = nil
		var regex = NSRegularExpression(pattern: pattern, options: NSRegularExpressionOptions.DotMatchesLineSeparators, error: &error)
		
		var result = regex?.stringByReplacingMatchesInString(type, options: nil, range: NSRange(location:0, length:count(type)), withTemplate: "$2")

		return result
	}
}