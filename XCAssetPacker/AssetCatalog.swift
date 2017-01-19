//
//  AssetCatalog.swift
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


let imageSetFileExtension = "imageset"
let appIconSetFileExtension = "appiconset"


class Node {
    let name: String
    var sourceURL: URL?
    var properties: ImageProperties?
    let parent: Node?
    var children: [Node] = []
    
    init(sourceURL: URL? = nil, name: String, parent: Node?) {
        self.sourceURL = sourceURL
        self.name = name
        self.parent = parent
    }
    
    
    func childNode(named childName: String) -> Node {
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
    let destinationURL: URL
    let rootNode: Node
    
    let numberOfRootPathComponents: Int
    let contentsFileName = "Contents.json"
    let configuration: [String: Any]
    
    let fileManager = FileManager()
    
    
    init(at destinationURL: URL, configuration: [String: Any]?) {
        self.destinationURL = destinationURL
        self.rootNode = Node(name: destinationURL.lastPathComponent, parent: nil)
        self.numberOfRootPathComponents = destinationURL.pathComponents.count
        
        self.configuration = configuration ?? [:]
    }
    
    
    // MARK: Construct a tree of source images
    
    func addImageAsset(from sourceURL: URL, inDirectory sourceDirectoryURL: URL) {
        let numberOfPathComponents = sourceDirectoryURL.pathComponents.count
        let fileName = sourceURL.lastPathComponent
        var isAppIcon = false
        
        if let include = configuration["include-images"] as? [String: Any],
            let patternsToRequire = include["patterns"] as? [String],
            !fileName.isMatchedBy(patternsToRequire) {
            return
        }
        
        if let skip = configuration["skip-images"] as? [String: Any],
            let patternsToSkip = skip["patterns"] as? [String],
            fileName.isMatchedBy(patternsToSkip) {
            return
        }
        
        if let appIcon = configuration["app-icon"] as? [String: Any],
            let appIconPattern = appIcon["pattern"] as? String {
            isAppIcon = fileName.isMatchedBy(appIconPattern)
        } else {
            isAppIcon = fileName.isMatchedBy("AppIcon")
        }
        
        let imageProperties = ImageProperties(from: fileName, isAppIcon: isAppIcon, configuration: configuration)
        
        let groupFileExtension = isAppIcon ? appIconSetFileExtension : imageSetFileExtension
        let generalizedImageSetName = (imageProperties.name as NSString).appendingPathExtension(groupFileExtension)!
        
        
        var pathComponents = sourceURL.pathComponents.suffix(from: numberOfPathComponents)
        
        // Create an asset with a generalized name stripped of the -38, -42 or @2x etc. prefixes
        _ = pathComponents.popLast()
        pathComponents.append(generalizedImageSetName)
        
        var currentNode = rootNode
        
        for pathComponent in pathComponents {
            currentNode = currentNode.childNode(named: pathComponent)
        }
        
        let imageNode = currentNode.childNode(named: fileName)
        imageNode.properties = imageProperties
        imageNode.sourceURL = sourceURL
    }
    
    
    // MARK: Outputing the .xcasset package
    
    func applyChanges() throws {
        let numberOfImages = try applyChanges(forNode: rootNode)
        
        let suffix = destinationURL.pathComponents.suffix(4)
        let lastPathComponents = suffix.reduce("") { (combined, pathComponent) -> String in
            return combined + "/" + pathComponent
        }
        
        print("Created assets package \(lastPathComponents) containing \(numberOfImages) images")
    }
    
    
    func applyChanges(forNode node: Node) throws -> Int {
        // Create a Contents.json for each directory
        var images: [[String : Any]] = []
        var copies: [(from: URL, to: URL)] = []
        var imageProperties: [ImageProperties] = []
        
        for child in node.children where !child.isDirectory {
            if let sourceURL = child.sourceURL, let properties = child.properties {
                imageProperties.append(properties)
                
                let imageFileName = sourceURL.lastPathComponent
                let assetDestinationURL = destinationURL.appendingPathComponents(node.pathComponents).appendingPathComponent(imageFileName)
                
                images.append(imageDictionary(for: imageFileName, properties: properties))
                copies.append((sourceURL, assetDestinationURL))
            }
        }
        
        
        var contents = contentsDictionaryFor(node: node, imageProperties: imageProperties)

        if !images.isEmpty {
            contents["images"] = images
        }
        
        // Create the destination folder
        let folderURL = destinationURL.appendingPathComponents(node.pathComponents)
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        
        // Save the Contents.json
        try write(contents, to: folderURL, fileName: contentsFileName)
        
        // Apply copies
        for (sourceURL, destinationURL) in copies {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }
        
        // Perform recursively for each child directory
        var numberOfImages = images.count
        
        for child in node.children where child.isDirectory {
            numberOfImages += try applyChanges(forNode: child)
        }
        
        return numberOfImages
    }
    
    
    func write(_ json: [String: Any], to url: URL, fileName: String) throws {
        let destinationURL = url.appendingPathComponent(fileName)
        
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
        try jsonData.write(to: destinationURL)
    }
    
    
    // MARK: Generate json for each component within the .xcassets package
    
    func imageDictionary(for imageName: String, properties: ImageProperties) -> [String: Any] {
        var imageDictionary: [String: Any] = [:]
        
        imageDictionary["filename"] = imageName
        
        if let idiom = properties.idiom {
            imageDictionary["idiom"] = idiom
        }
        
        if let scale = properties.scaleString {
            imageDictionary["scale"] = scale
        }
        
        if let size = properties.type.sizeString {
            imageDictionary["size"] = size
        }
        
        if let screenWidth = properties.type.screenWidth {
            imageDictionary["screen-width"] = screenWidth
        }
        
        if let prerendered = properties.prerendered {
            imageDictionary["pre-rendered"] = prerendered
        }
        
        return imageDictionary
    }
    
    
    func contentsDictionaryFor(node: Node, imageProperties: [ImageProperties]) -> [String: Any] {
        var contents: [String : Any] = (configuration["info"] as? [String: Any]) ?? [
            "info" : [
                "version" : 1,
                "author" : "xcode"
            ]
        ]
        
        var combinedProperties: [String: Any] = [:]
        
        if let baseProperties = configuration["base"] as? [String: Any] {
            for (key, value) in baseProperties {
                combinedProperties[key] = value
            }
        }
        
        
        if let devices = configuration["devices"] as? [[String: Any]] {
            for device in devices {
                // Test that the device type matches the image format
                if let deviceType = device["device-type"] as? String,
                    deviceType == imageProperties.first?.type.deviceType,
                    let properties = device["properties"] as? [String: Any] {
                    
                    for (key, value) in properties {
                        combinedProperties[key] = value
                    }
                }
            }
        }
        
        
        if let customProperties = configuration["custom"] as? [[String: Any]] {
            for customProperty in customProperties {
                if let patterns = customProperty["patterns"] as? [String],
                    node.name.isMatchedBy(patterns),
                    let properties = customProperty["properties"] as? [String: Any] {
                    for (key, value) in properties {
                        combinedProperties[key] = value
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
