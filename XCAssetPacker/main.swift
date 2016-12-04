//
//  main.swift
//  XCAssetPacker
//
//  Created by Harry Jordan on 23/11/2016.
//  Copyright © 2016 Inquisitive Software. All rights reserved.
//

import Foundation

import Foundation
import Cocoa

let assetPackageExtension = "xcassets"


// Setup command line input
let inputPath = StringOption(shortFlag: "i", longFlag: "input", required: true, helpMessage: "Path to the input folder")
let rules = StringOption(shortFlag: "r", longFlag: "rules", required: false, helpMessage: "Location of a rules .json file")
let outputPath = StringOption(shortFlag: "o", longFlag: "output", required: true, helpMessage: "Path to the output file")
let overwrite = BoolOption(shortFlag: "f", longFlag: "force", helpMessage: "Overwrite .xcassets package")
let help = BoolOption(shortFlag: "h", longFlag: "help", helpMessage: "Prints a help message.")
//let verbosity = CounterOption(shortFlag: "v", longFlag: "verbose",
//  helpMessage: "Print verbose messages. Specify multiple times to increase verbosity.")

let cli = CommandLine()
cli.addOptions(inputPath, rules, outputPath, overwrite)

do {
    try cli.parse()
} catch {
    cli.printUsage(error)
    exit(EX_USAGE)
}


// Validate input
let fileManager = FileManager()
let sourceDirectoryURL: URL

if let input = inputPath.value {
    sourceDirectoryURL = URL(fileURLWithPath: input)
} else {
    sourceDirectoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
}

guard let fileEnumerator = fileManager.enumerator(at: sourceDirectoryURL, includingPropertiesForKeys: [.isRegularFileKey], options: [], errorHandler: nil) else {
    print("Can't create file enumerator for \(sourceDirectoryURL)")
    exit(EX_IOERR)
}


// Load .json
var properties: [String: Any] = [:]

if let rulesFilePath = rules.value {
    let propertiesFileURL = URL(fileURLWithPath: rulesFilePath).absoluteURL
    
    if let data = try? Data(contentsOf: propertiesFileURL),
        let json = try? JSONSerialization.jsonObject(with: data, options: []),
        let propertiesJSON = json as? [String: Any] {
        properties = propertiesJSON
    }
}


// Validate output
var destinationURL: URL

if let output = outputPath.value {
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


// Overwrite an existing asset url
if overwrite.value || true {
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
let catalog = AssetCatalog(at: destinationURL, properties: properties)

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
    print("Can't apply changes: \(error)")
    exit(EX_IOERR)
}


exit(EXIT_SUCCESS)

