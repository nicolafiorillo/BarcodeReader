//: Playground - noun: a place where people can play

import UIKit

func extractType(type: String) -> String? {
	
	var pattern = "(.*)\\.(.+)$"
//	var pattern = "(\\w+)$"
	
	var error: NSError? = nil
	var regex = NSRegularExpression(pattern: pattern, options: NSRegularExpressionOptions.DotMatchesLineSeparators, error: &error)
	
	return regex?.stringByReplacingMatchesInString(type, options: nil, range: NSRange(location:0, length:count(type)), withTemplate: "$2")
}

extractType("abba.babba.EAN-13")
extractType("abba.babba.qrcode")
