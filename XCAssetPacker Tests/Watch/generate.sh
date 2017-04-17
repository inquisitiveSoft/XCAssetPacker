#!/bin/sh

# Create the .xcassets package for generated complications
XCAssetPacker --input "Generated/Images" --config "../Source/Complication Rules.json" --output "Generated/Complications.xcassets" -f

# Create the .xcassets package for static images
XCAssetPacker --input "Source" --config "../Source/Watch App Rules.json" --output "Generated/Watch App.xcassets" -f
