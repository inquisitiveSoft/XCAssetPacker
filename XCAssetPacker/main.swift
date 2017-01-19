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


let assetPackageExtension = "xcassets"

// Setup command line input
let inputPathOption = StringOption(shortFlag: "i", longFlag: "input", helpMessage: "Path to the input folder")
let configurationOption = StringOption(shortFlag: "c", longFlag: "config", required: false, helpMessage: "The location of a json configuration file or folder. If none is specified then uses sensible defaults.")
let outputPathOption = StringOption(shortFlag: "o", longFlag: "output", helpMessage: "Path to the output file or folder. If a folder is given then an Assets.xcassets package will be created inside it.")
let overwriteOption = BoolOption(shortFlag: "f", longFlag: "force", helpMessage: "Overwrite .xcassets package")
let helpOption = BoolOption(shortFlag: "h", longFlag: "help", helpMessage: "Prints a help message.")
let verbosityOption = BoolOption(shortFlag: "v", longFlag: "verbose", helpMessage: "Print verbose messages")

let cli = CommandLine()
cli.addOptions(inputPathOption, configurationOption, outputPathOption, overwriteOption, helpOption, verbosityOption)


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


guard inputPathOption.wasSet && outputPathOption.wasSet else {
    print("Missing required options: [-i or --input, and -o or --output]\n")
    cli.printUsage()
    exit(EX_USAGE)
}


// Validate input
let fileManager = FileManager()
let sourceDirectoryURL: URL

if let input = inputPathOption.value {
    sourceDirectoryURL = URL(fileURLWithPath: input)
} else {
    sourceDirectoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
}

guard let fileEnumerator = fileManager.enumerator(at: sourceDirectoryURL, includingPropertiesForKeys: [.isRegularFileKey], options: [], errorHandler: nil) else {
    print("Can't create file enumerator for \(sourceDirectoryURL)")
    exit(EX_IOERR)
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


// Validate output
var destinationURL: URL

if let output = outputPathOption.value {
    destinationURL = URL(fileURLWithPath: output).absoluteURL
} else {
    destinationURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
}


var isDirectory: ObjCBool = false

if fileManager.fileExists(atPath: destinationURL.path, isDirectory: &isDirectory),
    isDirectory.boolValue,
    destinationURL.pathExtension != assetPackageExtension {
    destinationURL = destinationURL.appendingPathComponent("Assets.\(assetPackageExtension)")
}


// Overwrite an existing .xcasset package if the --force argument is supplied
if overwriteOption.value {
    try? fileManager.removeItem(at: destinationURL)
} else {
    let fileExists = fileManager.fileExists(atPath: destinationURL.path)
    
    if fileExists {
        print("An asset collection already exists at: \(destinationURL)")
        exit(EX_IOERR)
    }
}


// Enumarate images
let validImageExtensions = ["png"]
let catalog = AssetCatalog(at: destinationURL, configuration: configuration)

while let file = fileEnumerator.nextObject() {
    if let fileURL = file as? URL, let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]) {
        if validImageExtensions.contains(fileURL.pathExtension.lowercased()), let isRegularFile = resourceValues.isRegularFile, isRegularFile {
            catalog.addImageAsset(from: fileURL, inDirectory: sourceDirectoryURL)
        } else if fileURL.pathExtension == assetPackageExtension {
            // Don't search within existing .xcasset packages
            fileEnumerator.skipDescendants()
        }
    }
}


do {
    try catalog.applyChanges()
} catch {
    print("Failed to apply changes: \(error)")
    exit(EX_IOERR)
}


exit(EXIT_SUCCESS)

