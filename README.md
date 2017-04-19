# XCAssetPacker
XCAssetPacker is a command line tool to create an Xcode `.xcasset` package from a folder of images.

## Installation
The easiest way to get up and running is to use homebrew: `brew install inquisitiveSoft/tools/XCAssetPacker`

Alternatively, it's very easy to download and build from source using Xcode. All dependencies are included directly in the project.

## Usage
I recommend calling `xcassetpacker` with the `--force` flag and treating the .xcassets and Swift output file as purely machine-generated.

```
xcassetpacker
	--input "Images/Source"
	--output "Resources/App.xcassets"
	--config "Images/Source/Main App Images Configuration.json"
	--swift "Code/Images.swift"
	--force
```

### Command Line Options
`-i`, `--input`: Path to the input folder.
`-c`, `--config`: The location of a json configuration file. If none is specified then uses sensible defaults.
`-o`, `--output`: Path to the output file or folder. If a folder is given then an Assets.xcassets package will be created inside it.
`--swift`: Path to the output swift file or folder. If a folder is given then an Images.swift package will be created inside it.
`-f`, `--force`: Overwrite any existing .xcassets package or Swift file.
`-h`, `--help`: Prints a help message.

You can set the target for generated Swift using: `--iOS`, `--mac` or `--watch`. By default it will generate iOS code.

## Image Naming Conventions
There are a number of image naming conventions which will be auto-detected.

- Scale is determined using a trailing `@1x`, `@2x` or `@3x`.

- Image type will also be detected using the following suffixes:

| Suffix | Detected Image Type |
| ------ | ----------  |
| -38    | Image targeting the smaller Apple Watch |
| -42    | Image targeting the larger Apple Watch |
| -20    | Notification icon |
| -29    | Settings icon |
| -40    | Spotlight icon |
| -60    | iPhone App icon |
| -76    | iPad App icon |
| -83.5  | iPad Pro App icon |

- In addition `AppIcon` is recognized as a standard icon name. App icons are stored slightly differently internally and will be marked as `prerendered` by default. For example an image named `AppIcon-40@3x.png` would be detected as the spotlight icon for the Plus sized iPhone.

### Configuration.json
XCAssetPacker has sensible defaults, so you can get started strait away, but you can also configure it using a JSON file. The most common uses are filtering which images are included, and to set image properties such as target device or rendering intent of images.

---

Skip images that match the given regex `patterns`:

```
"skip-images" : {
	"patterns" : ["Watch App .*", "Bed.*"]
}
```

---
Determine which images to include. Defaults to `png` only:

```
"valid-image-extensions" : ["png", "jpeg", "jpg", "tiff"]
```

---
Apply a dictionary of properties to every image:

```
"base" : {
	"template-rendering-intent" : "template"
}
```

---
Apply properties based on the target device:

```
"devices" : [
	{
		"device-type" : "watch",
		"properties" : {
			"template-rendering-intent" : "template"
		}
	}
]
```

---
By default images following the `AppIcon-{size}.png` naming convention
will be treated as prerendered app icons and won't be exposed to Swift or you can customize the app-icon properties:
```
"app-icon" : {
	"pattern" : "Custom App Icon Name.*",
	"prerendered" : false		/* Defaults to true */
}
```

---
Apply a dictionary of properties to images matched by the given patterns:
```
"custom" : [
	{
		"patterns" : [".*Preview.*", "SleepDuration.*", "WakeTime.*"],
		"properties" : {
			"template-rendering-intent" : "original"
		}
	}
]
```

---
`template-rendering-intent` is a property that iOS uses to determine whether an image has a tintColor applied. Valid properties are `rendering` (tinted) or `original` (not-tinted). Not supplying a value is equivalent to the 'Default' option in Xcode's UI.

A good starting point might be the [Example Configuration.json](Examples/Example%20Configuration.json).

## Credits
Uses Ben Gollmer's nifty [CommandLine framework](https://github.com/jatoben/CommandLine) for parsing CLI input.

## License
Open sourced under the Apache Version 2.0 License.
