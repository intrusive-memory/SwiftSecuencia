//
//  AttributeParserDelegate.swift
//  Pipeline
//
//  Originally created by Reuel Kim.
//  Copyright © 2017 Reuel Kim. All rights reserved.
//
//  Integrated into SwiftSecuencia with modifications for Swift 6.2 and macOS 26.0+
//  MIT License - See PIPELINE-LICENSE.md file for original Pipeline license
//
import Cocoa
import CoreMedia

/// An XMLParser delegate for parsing attributes in XMLElement objects.
class AttributeParserDelegate: NSObject, XMLParserDelegate {

	var attribute: String = ""
	var elementName: String?
	var values: [String] = []

	init(element: XMLElement, attribute: String, inElementsWithName elementName: String?) {
		super.init()

		self.attribute = attribute
		self.elementName = elementName
		let xmlDoc = XMLDocument(rootElement: element.copy() as? XMLElement)
		let parser = XMLParser(data: xmlDoc.xmlData)
		parser.delegate = self
		parser.parse()
	}

	func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {

		if self.elementName != nil {
			if elementName == self.elementName! {

				for attribute in attributeDict {
					if attribute.0 == self.attribute {
						self.values.append(attribute.1)
					}
				}
			}

		} else {

			for attribute in attributeDict {
				if attribute.0 == self.attribute {
					self.values.append(attribute.1)
				}
			}
		}
	}

}
