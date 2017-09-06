//
//  AssetCatalogGenerator.swift
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


enum AssetCatalogError: Error {
    case ioError(String)
}


enum AssetCatalogLogLevel {
    // Fast only adds up the number of images included
    case fast
    
    // Detailed populates the images and imageProperties arrays
    case detailed
}



struct AssetCatalogLog {
    
    init(logLevel: AssetCatalogLogLevel, images: [[String: Any]]) {
        self.logLevel = logLevel
        numberOfImages = images.count
        
        if logLevel == .detailed {
            self.images = images
        }
    }
    
    let logLevel: AssetCatalogLogLevel
    var numberOfImages: Int
    var images: [[String: Any]] = []
    var code: String?
    
    mutating func append(_ otherResult: AssetCatalogLog) {
        numberOfImages += otherResult.numberOfImages
        
        if logLevel == .detailed {
            images.append(contentsOf: otherResult.images)
        }
    }
    
}


class Node {
    let name: String
    var sourceURL: URL?
    var properties: ImageProperties?
    let parent: Node?
    var children: [Node] = []
    var isImageSet = false
    var isAppIcon = false
    
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


class AssetCatalogGenerator {
    let destinationURL: URL
    let swiftFileURL: URL?
    let swiftTarget: SwiftTarget
    let shouldOverwrite: Bool
    let baseIdiom: DeviceIdiom?
    let rootNode: Node
    
    let numberOfRootPathComponents: Int
    let configuration: [String: Any]
    
    let fileManager = FileManager()
    
    
    init(at destinationURL: URL, swift: URL?, target: SwiftTarget, shouldOverwrite: Bool, configuration: [String: Any]) {
        self.destinationURL = destinationURL
        self.rootNode = Node(name: destinationURL.lastPathComponent, parent: nil)
        self.numberOfRootPathComponents = destinationURL.pathComponents.count
        
        self.swiftFileURL = swift
        self.swiftTarget = target
        
        self.shouldOverwrite = shouldOverwrite
        self.configuration = configuration
        
        if let base = configuration.value(for: .base) as? [String: Any],
            let idiom = base.value(for: .idiom) as? String {
            baseIdiom = DeviceIdiom(idiom)
        } else {
            baseIdiom = nil
        }
    }
    
    
    // MARK: Construct a tree of source images
    
    func addImageAsset(from sourceURL: URL, inDirectory sourceDirectoryURL: URL) {
        let numberOfPathComponents = sourceDirectoryURL.pathComponents.count
        let fileName = sourceURL.lastPathComponent
        var isAppIcon = false
        
        if let include = configuration.value(for: .includeImages) as? [String: Any],
            let patternsToRequire = include.value(for: .multiplePatterns) as? [String],
            !fileName.isMatchedBy(patternsToRequire) {
            return
        }
        
        if let skip = configuration.value(for: .skipImages) as? [String: Any],
            let patternsToSkip = skip.value(for: .multiplePatterns) as? [String],
            fileName.isMatchedBy(patternsToSkip) {
            return
        }
        
        if let appIcon = configuration.value(for: .appIcon) as? [String: Any],
            let appIconPattern = appIcon.value(for: .pattern) as? String {
            isAppIcon = fileName.isMatchedBy(appIconPattern)
        } else {
            isAppIcon = fileName.isMatchedBy(FileName.appIcon.rawValue)
        }
        
        let imageProperties = ImageProperties(from: fileName, isAppIcon: isAppIcon, configuration: configuration)
        
        let groupFileExtension: FileExtension = isAppIcon ? .appIconSet : .imageSet
        let generalizedImageSetName = (imageProperties.name as NSString).appendingPathExtension(groupFileExtension.rawValue)!
        
        var pathComponents = sourceURL.pathComponents.suffix(from: numberOfPathComponents)
        
        // Create an asset with a generalized name stripped of the -38, -42 or @2x etc. prefixes
        _ = pathComponents.popLast()
        pathComponents.append(generalizedImageSetName)
        
        var currentNode = rootNode
        
        for pathComponent in pathComponents {
            currentNode = currentNode.childNode(named: pathComponent)
        }
        
        currentNode.isImageSet = true
        currentNode.isAppIcon = isAppIcon
        
        let imageNode = currentNode.childNode(named: fileName)
        imageNode.properties = imageProperties
        imageNode.sourceURL = sourceURL
    }
    
    
    // MARK: Outputing the .xcasset package
    
    @discardableResult func applyChanges(logLevel: AssetCatalogLogLevel = .fast, dryRun: Bool = false) throws -> AssetCatalogLog {
        // Overwrite an existing .xcasset package if the --force argument is supplied
        if shouldOverwrite {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
        } else {
            // Otherwise bail if an existing .xcasset package or swift file exist
            let destinationExists = fileManager.fileExists(atPath: destinationURL.path)
            
            if destinationExists {
                throw AssetCatalogError.ioError("An asset collection already exists at: \(destinationURL)")
            }
            
            if let swiftFileURL = swiftFileURL {
                let swiftFileExists = fileManager.fileExists(atPath: swiftFileURL.path)
                
                if(swiftFileExists) {
                    throw AssetCatalogError.ioError("An swift file already exists at: \(swiftFileURL)")
                }
            }
        }
        
        
        // Generate Swift code
        let generatedCode: String?
        
        if let swiftFileURL = swiftFileURL {
            let code = try swiftCode(forTarget: swiftTarget, rootNode: rootNode)
            try code.write(to: swiftFileURL, atomically: true, encoding: .utf8)
            generatedCode = code
        } else {
            generatedCode = nil
        }
        
        // Create the folder structure, the metadata and copy the images across
        var result = try applyChanges(forNode: rootNode, dryRun: dryRun, logLevel: logLevel)
        result.code = generatedCode
        
        return result
    }
    
    
    func applyChanges(forNode node: Node, dryRun: Bool, logLevel: AssetCatalogLogLevel) throws -> AssetCatalogLog {
        // Create a Contents.json for each directory
        var images: [[String : Any]] = []
        var copies: [(from: URL, to: URL)] = []
        var imageProperties: [ImageProperties] = []
        
        for child in node.children where !child.isDirectory {
            if let sourceURL = child.sourceURL, let properties = child.properties {
                imageProperties.append(properties)
                
                let imageFileName = sourceURL.lastPathComponent
                let assetDestinationURL = destinationURL.appending(pathComponents: node.pathComponents).appendingPathComponent(imageFileName)
                
                // Xcode 9 seperates Notification, Settings and Spotlight images for iPhone and iPad
                // if no base idiom is supplied then add both images
                //
                // This is rather messy, so would ideally be tidied up
                switch properties.type {
                case .notification, .settings, .spotlight:
                    if let idiom = baseIdiom {
                        images.append(imageDictionary(for: imageFileName, properties: properties, customIdiom: idiom.idiomString))
                    } else {
                        let targetIdioms: [DeviceIdiom] = [.iPhone, .iPad]
                        
                        for targetIdiom in targetIdioms {
                            images.append(imageDictionary(for: imageFileName, properties: properties, customIdiom: targetIdiom.idiomString))
                        }
                    }
                
                default:
                    images.append(imageDictionary(for: imageFileName, properties: properties))
                }
                
                copies.append((sourceURL, assetDestinationURL))
            }
        }
        
        
        var contents = contentsDictionaryFor(node: node, imageProperties: imageProperties)

        if !images.isEmpty {
            contents[Configuration.images.rawValue] = images
        }
        
        if !dryRun {
            // Create the destination folder
            let folderURL = destinationURL.appending(pathComponents: node.pathComponents)
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            
            // Save the Contents.json
            try write(contents, to: folderURL, fileName: FileName.contents.rawValue)
            
            // Perform copies
            for (sourceURL, destinationURL) in copies {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            }
        }
        
        // Apply recursively for each child directory
        var result = AssetCatalogLog(logLevel: logLevel, images: images)
        
        for child in node.children where child.isDirectory {
            let childResult = try applyChanges(forNode: child, dryRun: dryRun, logLevel: logLevel)
            result.append(childResult)
        }
        
        return result
    }
    
    
    func write(_ json: [String: Any], to url: URL, fileName: String) throws {
        let destinationURL = url.appendingPathComponent(fileName)
        
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
        try jsonData.write(to: destinationURL)
    }
    
    
    // MARK: Generate json for each component within the .xcassets package
    
    
    func imageDictionary(for imageName: String, properties: ImageProperties, customIdiom: String? = nil) -> [String: Any] {
        var imageDictionary: [String: Any] = [:]
        imageDictionary[Configuration.filename.rawValue] = imageName
        
        if let idiom = customIdiom {
            imageDictionary[Configuration.idiom.rawValue] = idiom
        } else if let idiom = properties.idiom {
            imageDictionary[Configuration.idiom.rawValue] = idiom
        }
        
        if let scale = properties.scaleString {
            imageDictionary[Configuration.scale.rawValue] = scale
        }
        
        if let size = properties.type.sizeString {
            imageDictionary[Configuration.size.rawValue] = size
        }
        
        if let screenWidth = properties.type.screenWidth {
            imageDictionary[Configuration.screenWidth.rawValue] = screenWidth
        }
        
        if let prerendered = properties.prerendered {
            imageDictionary[Configuration.prerendered.rawValue] = prerendered
        }
        
        return imageDictionary
    }
    
    
    func contentsDictionaryFor(node: Node, imageProperties: [ImageProperties]) -> [String: Any] {
        var contents = (configuration.value(for: .info) as? [String: Any]) ?? [
            "info" : [
                "version" : 1,
                "author" : "xcode"
            ]
        ]
        
        var combinedProperties: [String: Any] = [:]
        
        if let baseProperties = configuration.value(for: .base) as? [String: Any] {
            for (key, value) in baseProperties {
                combinedProperties[key] = value
            }
        }
        
        
        if let devices = configuration.value(for: .devices) as? [[String: Any]] {
            for device in devices {
                // Test that the device type matches the image format
                if let deviceType = device.value(for: .deviceType) as? String,
                    deviceType == imageProperties.first?.type.deviceType,
                    let properties = device.value(for: .properties) as? [String: Any] {
                    for (key, value) in properties {
                        combinedProperties[key] = value
                    }
                }
            }
        }
        
        
        if let customProperties = configuration.value(for: .custom) as? [[String: Any]] {
            for customProperty in customProperties {
                if let patterns = customProperty.value(for: .multiplePatterns) as? [String],
                    node.name.isMatchedBy(patterns),
                    let properties = customProperty.value(for: .properties) as? [String: Any] {
                    
                    for (key, value) in properties {
                        combinedProperties[key] = value
                    }
                }
            }
        }
        
        if !combinedProperties.isEmpty {
            contents[Configuration.properties.rawValue] = combinedProperties
        }
        
        return contents
    }
    
}
