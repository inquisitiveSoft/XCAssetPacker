//
//  SwiftGeneration.swift
//  XCAssetPacker
//
//  Created by Harry Jordan on 23/11/2016.
//  Copyright © 2016 Inquisitive Software. All rights reserved.
//	
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//  
//  http://www.apache.org/licenses/LICENSE-2.0
//  
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation


enum SwiftGenerationError: Error {
    case duplicateProperty(name: String, originalFileName: String)
}



enum SwiftTarget {
    case cocoa, iOS, watch
    
    var libraryName: String {
        switch self {
        case .cocoa:
            return "Cocoa"
        
        case .iOS:
            return "UIKit"
        
        case .watch:
            return "ClockKit"
        }
    }
    
    var imageClassName: String {
        switch self {
        case .cocoa:
            return "NSImage"
        
        case .iOS, .watch:
            return "UIImage"
        }
    }

}


extension AssetCatalogGenerator {

    func swiftCode(forTarget target: SwiftTarget, rootNode node: Node) throws -> String {
        let result = try generateSwiftCode(forTarget: target, node: node, depth: 0)
        
        return header(forTarget: target) + result.code
    }
    
    
    func generateSwiftCode(forTarget target: SwiftTarget, node: Node, depth: Int) throws -> (code: String, propertyNames: [String]) {
        // Code Indents
        let topLevel = String(repeating: "    ", count: depth)
        let firstIndent = String(repeating: "    ", count: depth + 1)
        let secondIndent = String(repeating: "    ", count: depth + 2)
        
        // Group name
        let structName: String
        let groupPropertyName: String?
        
        if depth == 0 {
            structName = "ImageAssetCatalog"
            groupPropertyName = nil
        } else {
            structName = "ImageAssetCatalog" + node.name
            
            let groupName = node.name.llamaCase()
            groupPropertyName = groupName
        }
        
        var generatedCode = ""
        var propertyNames: [String] = []

        if let groupPropertyName = groupPropertyName {
            // Add a var to the struct to accesss the images in this group
            generatedCode += topLevel + "var \(groupPropertyName) = \(structName)()\n"
        }
        
        generatedCode += topLevel + "struct \(structName) {\n"
        
        if depth == 0 {
            generatedCode += firstIndent + "private func image(named name: String) -> \(target.imageClassName) {\n" +
            secondIndent + "// Force unwrapping here as it seems reasonable to assume the image exists\n" +
            secondIndent + "// since the .xcassets package was generated in tandem with this code\n" +
            secondIndent + "return \(target.imageClassName)(named: name)!\n" +
            firstIndent + "}\n\n"
        }
        
        // Sort using the numeric option, so that numbered image sets appear in a logical order
        let childNodes = node.children.sorted(by: { (firstNode, secondNode) -> Bool in
            let firstProperty = firstNode.swiftPropertyName(withinGroup: groupPropertyName)
            let secondProperty = secondNode.swiftPropertyName(withinGroup: groupPropertyName)
            
            let comparison = firstProperty.compare(secondProperty, options: [.caseInsensitive, .numeric, .widthInsensitive, .forcedOrdering], locale: Locale.current)
            return comparison == .orderedAscending
        })
        
        for child in childNodes where child.isDirectory && child.isImageSet && !child.isAppIcon {
            let propertyName = child.swiftPropertyName(withinGroup: groupPropertyName)
            
            if propertyNames.contains(propertyName) {
                throw SwiftGenerationError.duplicateProperty(name: propertyName, originalFileName: child.name)
            } else {
                propertyNames.append(propertyName)
                
                generatedCode += firstIndent + "var \(propertyName): \(target.imageClassName) { return image(named: \"\(child.swiftCatalogName)\") }\n"
            }
        }
        
        for child in node.children where child.isDirectory && !child.isImageSet && !child.isAppIcon {
            let result = try self.generateSwiftCode(forTarget: target, node: child, depth: depth + 1)
            generatedCode += result.code
            
            propertyNames.append(contentsOf: result.propertyNames)
        }
        
        generatedCode += topLevel + "}\n\n"
        
        return (generatedCode, propertyNames)
    }
    
    
    func header(forTarget target: SwiftTarget) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd"
        
        let dateString = dateFormatter.string(from: Date())
        
        let header = "//  *********************************************************\n" +
        "//  *********************************************************\n" +
        "//  ***\n" +
        "//  ***  DO NOT EDIT\n" +
        "//  ***  This file is machine-generated by XCAssetPacker\n" +
        "//  ***  and is intended to be overwritten regularly\n" +
        "//  ***\n" +
        "//  ***  Last updated: \(dateString)\n" +
        "//  ***\n" +
        "//  *********************************************************\n" +
        "//  *********************************************************\n\n" +
        "import \(target.libraryName)\n\n" +
        "extension \(target.imageClassName) {\n" +
        "    static let assets = ImageAssetCatalog()\n" +
        "    static let r = ImageAssetCatalog()\n" +
        "}\n\n"
        
        return header
    }
    
}


extension Node {

    func swiftPropertyName(withinGroup groupName: String?) -> String {
        var name = swiftCatalogName
    
        if let groupName = groupName,
            let matchingRange = name.range(of: groupName, options: [.anchored, .caseInsensitive]) {
            let uniqueSubstring = name.substring(from: matchingRange.upperBound)
            name = uniqueSubstring
        }
        
        name = name.llamaCase()
        
        // Append a prefix as digits aren't allowed as the fist character of a variable
        if let firstCharacter = name.unicodeScalars.first, CharacterSet.decimalDigits.contains(firstCharacter) {
            let prefix = "i"
            name = prefix + name
        }
        
        return name
    }
    
    
    var swiftCatalogName: String {
        return (name as NSString).deletingPathExtension
    }
    
}


extension String {
    // Adapted from: https://gist.github.com/AmitaiB/bbfcba3a21411ee6d3f972320bcd1ecd
    
    func llamaCase() -> String {
        //
        var adaptedText: String = ""
        var isFirstLetter = true
        
        self.enumerateSubstrings(in: startIndex..<endIndex, options: .byWords) { (substring, substringRange, _, stop) in
            guard var substring = substring else { return }
            
            if let firstCharacterOfWord = substring.characters.popFirst() {
                var firstLetterOfWord = String(firstCharacterOfWord)
                firstLetterOfWord = isFirstLetter ? firstLetterOfWord.lowercased() : firstLetterOfWord.uppercased()
                adaptedText += firstLetterOfWord + substring
                isFirstLetter = false
            } else {
                // If getting the first character fails then just append the original substring
                adaptedText += substring
            }
        }
        
        return adaptedText
    }

}

