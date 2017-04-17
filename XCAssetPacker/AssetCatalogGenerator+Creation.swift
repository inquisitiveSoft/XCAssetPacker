//
//  AssetCatalog.swift
//  XCAssetPacker
//
//  Created by Harry Jordan on 17/04/2017.
//  Copyright © 2017 Inquisitive Software. All rights reserved.
//

import Foundation



extension AssetCatalogGenerator {
    
    convenience init(from sourceDirectoryURL: URL, to destinationDirectoryURL: URL, swift swiftDestinationURL: URL?, target: SwiftTarget, overwrite shouldOverwrite: Bool, configuration: [String: Any]) throws {
        let fileManager = FileManager()
        
        guard let fileEnumerator = fileManager.enumerator(at: sourceDirectoryURL, includingPropertiesForKeys: [.isRegularFileKey], options: [], errorHandler: nil) else {
            print()
            throw AssetCatalogError.ioError("Can't create file enumerator for \(sourceDirectoryURL)")
        }
        
        
        // Validate the destination url
        var isDirectory: ObjCBool = false
        var destinationURL = destinationDirectoryURL
        
        if fileManager.fileExists(atPath: destinationURL.path, isDirectory: &isDirectory),
            isDirectory.boolValue,
            destinationURL.pathExtension != FileExtension.assetPackage.rawValue {
            destinationURL = destinationURL.appendingPathComponent("Assets.\(FileExtension.assetPackage.rawValue)")
        }
        
        
        // Validate the Swift output url
        var swiftFileURL: URL? = swiftDestinationURL
        
        if let swiftDestinationURL = swiftDestinationURL,
            fileManager.fileExists(atPath: swiftDestinationURL.path, isDirectory: &isDirectory),
            isDirectory.boolValue,
            swiftDestinationURL.pathExtension != FileExtension.swift.rawValue {
            swiftFileURL = swiftDestinationURL.appendingPathComponent("Images.\(FileExtension.swift)")
        }
            
        self.init(at: destinationURL, swift: swiftFileURL, target: target, shouldOverwrite: shouldOverwrite, configuration: configuration)
        
        
        // Limit to a set of image extensions
        let validImageExtensions: [String]
        
        if let imageExtensions = configuration.value(for: .validImageExtensions) as? [String], !imageExtensions.isEmpty {
            validImageExtensions = imageExtensions.map { $0.lowercased() }
        } else {
            validImageExtensions = ["png"]
        }
        
        
        // Enumarate images
        while let file = fileEnumerator.nextObject() {
            if let fileURL = file as? URL, let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]) {
                if validImageExtensions.contains(fileURL.pathExtension.lowercased()), let isRegularFile = resourceValues.isRegularFile, isRegularFile {
                    self.addImageAsset(from: fileURL, inDirectory: sourceDirectoryURL)
                } else if fileURL.pathExtension == FileExtension.assetPackage.rawValue {
                    // Don't search within existing .xcasset packages
                    fileEnumerator.skipDescendants()
                }
            }
        }
    }

}
