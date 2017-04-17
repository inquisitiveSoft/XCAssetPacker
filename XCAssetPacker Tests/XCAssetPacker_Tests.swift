//
//  XCAssetPacker_Tests.swift
//  XCAssetPacker Tests
//
//  Created by Harry Jordan on 17/04/2017.
//  Copyright © 2017 Inquisitive Software. All rights reserved.
//

import XCTest


class XCAssetPacker_Tests: XCTestCase {
    
    
    func testWatchNoConstraints() {
        validateAssetCatalog(directory: "Watch") { (assetCatalog, log) in
            XCTAssertEqual(log.numberOfImages, 85, "Expect to find 85 test images")
        }
    }
    
    
    func testWatchSkipImagesContainingTheWordCircle() {
        validateAssetCatalog(directory: "Watch", configurationFileName: "Skip Circles Rules") { (assetCatalog, log) in
            XCTAssertEqual(log.numberOfImages, 67, "Expect to find 67 test images")
        }
    }
   
    
    func testSwiftGeneration() {
        validateAssetCatalog(directory: "Watch", swift: .watch) { (assetCatalog, log) in
            XCTAssertEqual(log.numberOfImages, 85, "Expect to find 85 test images")
        }
    }
    
    
    func validateAssetCatalog(directory: String, configurationFileName: String? = nil, swift swiftTarget: SwiftTarget? = nil, expectations: (AssetCatalogGenerator, AssetCatalogLog) -> Void) {
        do {
            let bundle = Bundle(for: XCAssetPacker_Tests.self)
            let watchURL = bundle.url(forResource: directory, withExtension: nil, subdirectory: nil)!
            let destinationURL = watchURL.deletingLastPathComponent()
            let swiftDestinationURL: URL?
            let target: SwiftTarget
            
            if let swiftTarget = swiftTarget {
                swiftDestinationURL = destinationURL.appendingPathComponent("\(swiftTarget.libraryName).swift")
                target = swiftTarget
            } else {
                swiftDestinationURL = nil
                target = .iOS
            }
            
            let configuration: [String: Any]
            if let configurationFileName = configurationFileName {
                configuration = try self.configuration(forFileName: configurationFileName, inBundle: bundle)
                XCTAssert(!configuration.isEmpty, "Couldn't load configuration for name: \(configurationFileName)")
            } else {
                configuration = [:]
            }
            
            let assetCatalog = try AssetCatalogGenerator(from: watchURL, to: destinationURL, swift: swiftDestinationURL, target: target, overwrite: true, configuration: configuration)
            let log = try assetCatalog.applyChanges(logLevel: .detailed, dryRun: true)
            
            expectations(assetCatalog, log)
        } catch let error as AssetCatalogError {
            switch error {
            case .ioError(let decription):
                XCTFail(decription)
            }
        } catch let error {
            XCTFail(String(describing: error))
        }
    }
    
    
    func configuration(forFileName jsonFileName: String, inBundle bundle: Bundle) throws -> [String: Any] {
        guard let configurationFileURL = bundle.url(forResource: jsonFileName, withExtension: "json", subdirectory: nil) else {
            throw AssetCatalogError.ioError("Ivli")
        }
        
        
        let data = try Data(contentsOf: configurationFileURL)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        
        if let configurationJSON = json as? [String: Any] {
            return configurationJSON
        } else {
            throw AssetCatalogError.ioError("Invalid json")
        }
    }
    
}
