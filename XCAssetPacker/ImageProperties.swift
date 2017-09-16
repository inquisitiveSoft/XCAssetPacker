//
//  ImageProperties.swift
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


struct ImageProperties {
    let name: String
    let type: ImageType
    let scale: ImageScale
    let prerendered: Bool?
    let configuration: [String: Any]
    
    
    init(from fileName: String, isAppIcon: Bool, configuration: [String: Any]) {
        let sourceImageName = (fileName as NSString).deletingPathExtension
        
        var adaptedName: String = sourceImageName
        var type: ImageType = .universal
        var scale: ImageScale = .universal
        
        // Look for an image scale e.g. @2x or @3x
        if let match = ImageProperties.scaleRegularExpression.firstMatch(in: adaptedName, range: adaptedName.asNSRange), match.numberOfRanges >= 2 {
            let rangeOfDigits = match.range(at: 1)
            let digitString = (adaptedName as NSString).substring(with: rangeOfDigits)
            
            if let scaleNumber = Int(digitString) {
                adaptedName = (sourceImageName as NSString).substring(to: match.range.location)
                scale = .scale(scaleNumber)
            }
        }
        
        // Parse standardized image extensions
        for (suffix, detectedImageType) in ImageProperties.typesForSuffixes {
            if let range = adaptedName.range(of: suffix, options: [.anchored, .backwards]) {
                type = detectedImageType
                adaptedName = sourceImageName.substring(to: range.lowerBound)
                break
            }
        }
        
        if isAppIcon {
            if let appIcon = configuration.value(for: .appIcon) as? [String: Any],
                let prerendered = appIcon.value(for: .prerendered) as? Bool {
                self.prerendered = prerendered
            } else {
                // Default to prerendered
                self.prerendered = true
            }
        } else {
            self.prerendered = nil
        }
        
        self.name = adaptedName
        self.type = type
        self.scale = scale
        self.configuration = configuration
    }
    
    
    static var scaleRegularExpression: NSRegularExpression = {
        let regularExpression = try! NSRegularExpression(pattern: "@(\\d)[xX]$", options: [])
        return regularExpression
    }()
    
    
    static var typesForSuffixes: [(String, ImageType)] {
        return ImageType.all.flatMap { (type) in
            if let suffix = type.suffix {
                return (suffix, type)
            } else {
                return nil
            }
        }
    }
    
    
    var scaleString: String? {
        switch type {
        case .watch, .watch38, .watch42:
            return "2x"
        
        default:
            if let scaleString = scale.scaleString {
                // See if the scale is identifiable from the filename
                return scaleString
            } else if let base = configuration.value(for: .base) as? [String: Any],
                let scaleString = base.value(for: .scale) as? String {
                // Look for a base scale in the configuration file
                return scaleString
            } else {
                // Otherwise default to 1x
                return "1x"
            }
        }
    }
    
    
    var idiom: String? {
        if let idiom = type.idiom {
            return idiom
        }
        
        if let base = configuration.value(for: .base) as? [String: Any],
            let idiomString = base.value(for: .idiom) as? String,
            let deviceIdiom = DeviceIdiom(idiomString) {
            return deviceIdiom.idiomString
        }
        
        return Configuration.universal.rawValue
    }
    
}


enum ImageType {
    case watch, watch38, watch42, universal, notification, settings, spotlight, iPhoneAppIcon, iPadAppIcon, iPadProAppIcon, iTunesPreview
    
    
    static var all: [ImageType] {
        return [watch, watch38, watch42, universal, notification, settings, spotlight, iPhoneAppIcon, iPadAppIcon, iPadProAppIcon, iTunesPreview]
    }

    
    var idiom: String? {
        let idiom: DeviceIdiom?
        
        switch self {
        case .watch, .watch38, .watch42:
            idiom = .watch
        
        case .iPhoneAppIcon:
            idiom = .iPhone
        
        case .iPadAppIcon, .iPadProAppIcon:
            idiom = .iPad
        
        case .iTunesPreview:
            idiom = .iOSMarketing
        
        default:
            idiom = nil
        }
        
        return idiom?.idiomString
    }
    
    
    var screenWidth: String? {
        switch self {
        case .watch:
            return nil
        
        case .watch38:
            return "<=145"
        
        case .watch42:
            return ">145"
            
        default:
            return nil
        }
    }
    
    
    var deviceType: String {
        // Used for matching with the configuration file
        switch self {
        case .watch, .watch38, .watch42:
            return DeviceIdiom.watch.configurationKey
        
        case .iPhoneAppIcon:
            return DeviceIdiom.iPhone.configurationKey
        
        case .iPadAppIcon, .iPadProAppIcon:
            return DeviceIdiom.iPad.configurationKey
        
        default:
            return "universal"
        }
    }
    
    
    var suffix: String? {
        switch self {
        // Watch types
        case .watch: 
            return nil
            
        case .watch42:
            return "-42"
        
        case .watch38:
            return "-38"
        
        case .notification:
            return "-20"
        
        case .settings:
            return "-29"
        
        case .spotlight:
            return "-40"
        
        case .iPhoneAppIcon:
            return "-60"
        
        case .iPadAppIcon:
            return "-76"
        
        case .iPadProAppIcon:
            return "-83.5"
        
        case .iTunesPreview:
            return "-1024"
        
        case .universal:
            return nil
        }
    }
    
    
    var sizeString: String? {
        switch self {
        case .notification:
            return "20x20"
        
        case .settings:
            return "29x29"
        
        case .spotlight:
            return "40x40"
        
        case .iPhoneAppIcon:
            return "60x60"

        case .iPadAppIcon:
            return "76x76"
        
        case .iPadProAppIcon:
            return "83.5x83.5"
            
        case .iTunesPreview:
            return "1024x1024"
        
        default:
            return nil
        }
    }

}


enum ImageScale {
    case scale(Int), universal
    
    var scaleString: String? {
        switch self {
        case .scale(let scale):
            return "\(scale)x"
            
        case .universal:
            return nil
        }
    }
}

