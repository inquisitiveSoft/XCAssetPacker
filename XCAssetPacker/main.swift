//
//  main.swift
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

import Foundation
import Cocoa


let versionNumber = "1.2"

// Setup command line options
let inputPathOption = StringOption(shortFlag: "i", longFlag: "input", helpMessage: "Path to the input folder.")
let configurationOption = StringOption(shortFlag: "c", longFlag: "config", required: false, helpMessage: "The location of a json configuration file.\n      If none is specified then uses sensible defaults.")
let outputPathOption = StringOption(shortFlag: "o", longFlag: "output", helpMessage: "Path to the output file or folder.\n      If a folder is given then an Assets.xcassets package will be created inside it.")
let swiftDestinationOption = StringOption(longFlag: "swift", helpMessage: "Path to the output swift file or folder.\n      If a folder is given then an Images.swift file will be created inside it.")
let overwriteOption = BoolOption(shortFlag: "f", longFlag: "force", helpMessage: "Overwrite any existing .xcassets package or Swift file.")

// Target
let swiftTargetMacOption = BoolOption(longFlag: "mac", helpMessage: "Set the target for generated Swift to use Cocoa.")
let swiftTargetiOSOption = BoolOption(longFlag: "iOS", helpMessage: "Set the target for generated Swift to use UIKit.")
let swiftTargetWatchOption = BoolOption(longFlag: "watch", helpMessage: "Set the target for generated Swift to use WatchKit.")

let versionOption = BoolOption(shortFlag: "v", longFlag: "version", helpMessage: "Prints the version number.")
let helpOption = BoolOption(shortFlag: "h", longFlag: "help", helpMessage: "Prints a help message.")


let cli = CommandLine()
cli.addOptions(inputPathOption, configurationOption, outputPathOption, swiftDestinationOption, swiftTargetMacOption, swiftTargetiOSOption, swiftTargetWatchOption, overwriteOption, versionOption, helpOption)


do {
    try cli.parse()
} catch {
    cli.printUsage(error)
    exit(EX_USAGE)
}


if helpOption.value {
    cli.printUsage()
    exit(EX_USAGE)
}

if versionOption.value {
    print("XCAssetPacker version \(versionNumber)")
    exit(EX_USAGE)
}



guard inputPathOption.wasSet && outputPathOption.wasSet else {
    print("Missing required options: [-i or --input, and -o or --output]\n")
    cli.printUsage()
    exit(EX_USAGE)
}


let inputPath = inputPathOption.value
let outputPath = outputPathOption.value
let shouldOverwrite: Bool = overwriteOption.value


// Determine input URL
let fileManager = FileManager()
let sourceDirectoryURL: URL

if let input = inputPath {
    sourceDirectoryURL = URL(fileURLWithPath: input)
} else {
    sourceDirectoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
}


// Determine output URL
var destinationDirectoryURL: URL

if let output = outputPath {
    destinationDirectoryURL = URL(fileURLWithPath: output).absoluteURL
} else {
    destinationDirectoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
}


// Validate swift url
var swiftDestinationURL: URL?

if let swiftDestinationPath = swiftDestinationOption.value {
    swiftDestinationURL = URL(fileURLWithPath: swiftDestinationPath).absoluteURL
} else if swiftDestinationOption.wasSet {
    swiftDestinationURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
}

let swiftTarget: SwiftTarget

if swiftTargetMacOption.wasSet {
    swiftTarget = .cocoa
} else if swiftTargetWatchOption.wasSet {
    swiftTarget = .watch
} else {
    swiftTarget = .iOS
}


// Load a configuration .json
var configuration: [String: Any] = [:]

if let configurationFilePath = configurationOption.value {
    let configurationFileURL = URL(fileURLWithPath: configurationFilePath).absoluteURL
    
    if let data = try? Data(contentsOf: configurationFileURL),
        let json = try? JSONSerialization.jsonObject(with: data, options: []),
        let configurationJSON = json as? [String: Any] {
        configuration = configurationJSON
    }
}


do {
    // Build a catalog of available images
    let assetCatalog = try AssetCatalogGenerator(from: sourceDirectoryURL, to: destinationDirectoryURL, swift: swiftDestinationURL, target: swiftTarget, overwrite: shouldOverwrite, configuration: configuration)
    
    // Generate the output packages and files
    let log = try assetCatalog.applyChanges()
    
    // Print
    let suffix = assetCatalog.destinationURL.pathComponents.suffix(4)
    let lastPathComponents = suffix.reduce("") { (combined, pathComponent) -> String in
        return combined + "/" + pathComponent
    }
    
    print("Created assets package \(lastPathComponents) containing \(log.numberOfImages) images")
    exit(EXIT_SUCCESS)
} catch let error as AssetCatalogError {
    switch error {
    case .ioError(let description):
        print(description)
        exit(EX_IOERR)
    }
} catch let error as SwiftGenerationError {
    switch error {
    case .duplicateProperty(let name, originalFileName: let originalFileName):
        print("Conflicting property '\(name)' for \(originalFileName)")
        print("Images need to have distinct llama case representations")
        exit(EX_IOERR)
    }
} catch let error {
    print("Unexpected error: \(String(describing: error))")
    exit(EX_IOERR)
}
