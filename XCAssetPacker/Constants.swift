//
//  Constants.swift
//  XCAssetPacker
//
//  Created by Harry Jordan on 16/04/2017.
//  Copyright © 2017 Inquisitive Software. All rights reserved.
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


enum Configuration: String {
    case appIcon = "app-icon"
    case pattern = "pattern"
    case includeImages = "include-images"
    case skipImages = "skip-images"
    case images = "images"
    case filename = "filename"
    case idiom = "idiom"
    case scale = "scale"
    case size = "size"
    case screenWidth = "screen-width"
    case prerendered = "pre-rendered"
    case info = "info"
    case base = "base"
    case devices = "devices"
    case deviceType = "device-type"
    case properties = "properties"
    case custom = "custom"
    case universal = "universal"
}


enum FileExtension: String {
    case imageSet = "imageset"
    case appIconSet = "appiconset"
    case json = "json"
}


enum FileName: String {
    case appIcon = "AppIcon"
    case contents = "Contents.json"
}


enum ImageScales: String {
    case appIcon = "AppIcon"
    case contents = "Contents.json"
}


extension Dictionary where Key == String {
    
    func value(for key: Configuration) -> Value? {
        return self[key.rawValue]
    }
    
}
