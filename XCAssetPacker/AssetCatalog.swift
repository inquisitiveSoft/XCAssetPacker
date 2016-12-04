//
//  AssetCatalog.swift
//  XCAssetPacker
//
//  Created by Harry Jordan on 23/11/2016.
//  Copyright © 2016 Inquisitive Software. All rights reserved.
//

import Foundation


let imageSetFileExtension = "imageset"


class Node {
    let name: String
    var sourceURL: URL?
    var format: ImageFormat?
    let parent: Node?
    var children: [Node] = []
    
    init(sourceURL: URL? = nil, name: String, parent: Node?) {
        self.sourceURL = sourceURL
        self.name = name
        self.parent = parent
    }
    
    
    func childNode(named childName: String) -> Node {
        if childName.
    
        for child in children {
            if child.name.compare(childName, options: [.caseInsensitive]) == .orderedSame {
                return child
            }
        }
        
        let newNode = Node(name: childName, parent: self)
        children.append(newNode)
        
        return newNode
    }
    
    
    var isDirectory: Bool {
        return sourceURL == nil
    }
    
    
    var pathComponents: [String] {
        var currentNode: Node? = self
        var pathComponents: [String] = []
        
        while let node = currentNode, node.parent != nil {
            pathComponents.append(node.name)
            currentNode = node.parent
        }
        
        return pathComponents.reversed()
    }
    
    
//    var folderPathComponents: [String] {
//        var currentNode: Node? = self.parent
//        var pathComponents: [String] = []
//        
//        while let node = currentNode, node.parent != nil {
//            pathComponents.append(node.name)
//            currentNode = node.parent
//        }
//        
//        return pathComponents
//    }

    
    func printTree(depth: Int = 0) {
        let depthPadding = (0...depth).reduce("") { (existing, _) -> String in
            return existing + "   "
        }
        
        print(depthPadding + "- \(name)")
        let childDepth = depth + 1
        
        for child in children {
            child.printTree(depth: childDepth)
        }
    }
    
}


class AssetCatalog {
    let rootURL: URL
    let root: Node
    
    let numberOfRootPathComponents: Int
    let contentsFileName = "Contents.json"
    let properties: [String: Any]?
    
    let fileManager = FileManager()
    
    
    init(at rootURL: URL, properties: [String: Any]?) {
        self.rootURL = rootURL
        self.root = Node(name: rootURL.lastPathComponent, parent: nil)
        self.numberOfRootPathComponents = rootURL.pathComponents.count
        
        self.properties = properties
    }
    
    
    func addImageAsset(from sourceURL: URL, inDirectory sourceDirectoryURL: URL) {
        let numberOfPathComponents = sourceDirectoryURL.pathComponents.count
        let fileName = sourceURL.lastPathComponent
        let properties = imageProperties(for: fileName)
        
        let imageSetFileName = (properties.name as NSString).appendingPathExtension(imageSetFileExtension)!
        
        var pathComponents = sourceURL.pathComponents.suffix(from: numberOfPathComponents)
        _ = pathComponents.popLast()
        pathComponents.append(imageSetFileName)
        
        var currentNode = root
        
        for pathComponent in pathComponents {
            currentNode = currentNode.childNode(named: pathComponent)
        }
        
        let imageNode = currentNode.childNode(named: fileName)
        imageNode.format = properties.format
        imageNode.sourceURL = sourceURL
    }
    
    
    func applyChanges() throws {
        
        try applyChanges(forNode: root)
    }
    
    
    func applyChanges(forNode node: Node) throws {
        // Create a Contents.json for each directory
        var images: [[String : Any]] = []
        var copies: [(from: URL, to: URL)] = []
        var imageFormats: [ImageFormat] = []
        
        for child in node.children where !child.isDirectory {
            if let sourceURL = child.sourceURL, let format = child.format {
                imageFormats.append(format)
                
                let imageFileName = sourceURL.lastPathComponent
                let destinationURL = rootURL.appendingPathComponents(node.pathComponents).appendingPathComponent(imageFileName)
                
                images.append(imageDictionary(for: imageFileName, type: format))
                copies.append((sourceURL, destinationURL))
            }
        }
        
        
        var contents = contentsDictionaryFor(node: node, imageFormats: imageFormats)

        if !images.isEmpty {
            contents["images"] = images
        }
        
        // Create the destination folder
        let folderURL = rootURL.appendingPathComponents(node.pathComponents)
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        
        // Save the Contents.json
        try write(contents, to: folderURL, fileName: contentsFileName)
        
        // Apply copies
        for (sourceURL, destinationURL) in copies {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }
        
        // Perform recursively for each child directory
        for child in node.children where child.isDirectory {
            try applyChanges(forNode: child)
        }
    }
    
    
    func imageDictionary(for imageName: String, type: ImageFormat) -> [String: Any] {
        var imageDictionary: [String: Any] = [:]
        
        imageDictionary["filename"] = imageName
        
        if let idiom = type.idiom {
            imageDictionary["idiom"] = idiom
        }

        if let scale = type.scale {
            imageDictionary["scale"] = scale
        }
        
        if let screenWidth = type.screenWidth {
            imageDictionary["screen-width"] = screenWidth
        }
        
        return imageDictionary
    }
    
    
    func write(_ json: [String: Any], to url: URL, fileName: String) throws {
        let destinationURL = url.appendingPathComponent(fileName)
        
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
        try jsonData.write(to: destinationURL)
    }
    
    
    func imageProperties(for fileName: String) -> (name: String, format: ImageFormat) {
        let sourceImageName = (fileName as NSString).deletingPathExtension
        var adaptedName: String = sourceImageName
        var format: ImageFormat = .watch
        
        // Look for image extensions
        if let range = sourceImageName.range(of: "-42", options: [.anchored, .backwards]) {
            format = .watch42
            adaptedName = sourceImageName.substring(to: range.lowerBound)
        } else if let range = sourceImageName.range(of: "-38", options: [.anchored, .backwards]) {
            format = .watch38
            adaptedName = sourceImageName.substring(to: range.lowerBound)
        }
        
        return (adaptedName, format)
    }
    
    
    func contentsDictionaryFor(node: Node, imageFormats: [ImageFormat]) -> [String: Any] {
        var contents: [String : Any] = (properties?["info"] as? [String: Any]) ?? [
            "info" : [
                "version" : 1,
                "author" : "xcode"
            ]
        ]
        
        var combinedProperties: [String: Any] = [:]
        
        if let baseProperties = properties?["base"] as? [String: Any] {
            for (key, value) in baseProperties {
                combinedProperties[key] = value
            }
        }
        
        
        if let devices = properties?["devices"] as? [[String: Any]] {
            for device in devices {
                if let deviceType = device["device-type"] as? String,
                    deviceType == imageFormats.first?.deviceType,
                    let properties = device["properties"] as? [String: Any] {
                    
                    for (key, value) in properties {
                        combinedProperties[key] = value
                    }
                }
            }
        }
        
        
        if let customProperties = properties?["custom"] as? [[String: Any]] {
            for customProperty in customProperties {
                if let patterns = customProperty["patterns"] as? [String] {
                    for pattern in patterns {
                        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                            let properties = customProperty["properties"] as? [String: Any] {
                            let nodeName = node.name
                            let range = NSRange(location: 0, length: (nodeName as NSString).length)
                            
                            if regex.firstMatch(in: nodeName, options: [], range: range) != nil {
                                for (key, value) in properties {
                                    combinedProperties[key] = value
                                }
                            }
                        }
                    }
                }
            }
        }
        
        if !combinedProperties.isEmpty {
            contents["properties"] = combinedProperties
        }
        
        return contents
    }
    
}


enum ImageFormat {
    case watch, watch38, watch42
    
    var idiom: String? {
        switch self {
        case .watch, .watch38, .watch42:
            return "watch"
        }
    }
    
    var screenWidth: String? {
        switch self {
        case .watch:
            return nil
        
        case .watch38:
            return "<=145"
        
        case .watch42:
            return ">145"
        }
    }
    
    var scale: String? {
        switch self {
        case .watch, .watch38, .watch42:
            return "2x"
        }
    }
    
    var deviceType: String {
        switch self {
        case .watch, .watch38, .watch42:
            return "watch"
        }
    }
    
//    var properties: [String : Any]? {
//        switch self {
//        case .watch:
//            return nil
//    
//        case .watch38, .watch42:
//            return ["template-rendering-intent" : "template"]
//        }
//    }

}


extension URL {
    
    func appendingPathComponents(_ pathComponents: [String]) -> URL {
        var url = self
        
        for pathComponent in pathComponents {
            url = url.appendingPathComponent(pathComponent)
        }
        
        return url
    }

}


// https://github.com/ankurp/Cent/blob/master/Sources/Dictionary.swift

extension Dictionary {

    mutating func merge<K, V>(dict: [K: V]){
        for (k, v) in dict {
            self.updateValue(v as! Value, forKey: k as! Key)
        }
    }
    
}

