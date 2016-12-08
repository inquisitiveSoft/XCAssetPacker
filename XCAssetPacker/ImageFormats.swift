//
//  ImageFormats.swift
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


enum ImageFormat {
    case watch, watch38, watch42
    
    var idiom: String? {
        switch self {
        case .watch, .watch38, .watch42:
            return "watch"
        }
    }
    
    var screenWidth: String? {
        switch self {
        case .watch:
            return nil
        
        case .watch38:
            return "<=145"
        
        case .watch42:
            return ">145"
        }
    }
    
    var scale: String? {
        switch self {
        case .watch, .watch38, .watch42:
            return "2x"
        }
    }
    
    var deviceType: String {
        switch self {
        case .watch, .watch38, .watch42:
            return "watch"
        }
    }
    
    
    static func inferImageProperties(from fileName: String, configuration: [String: Any]) -> (name: String, format: ImageFormat) {
        let sourceImageName = (fileName as NSString).deletingPathExtension
        var adaptedName: String = sourceImageName
        var format: ImageFormat = .watch
        
        // Parse standardized image extensions
        if let range = sourceImageName.range(of: "-42", options: [.anchored, .backwards]) {
            format = .watch42
            adaptedName = sourceImageName.substring(to: range.lowerBound)
        } else if let range = sourceImageName.range(of: "-38", options: [.anchored, .backwards]) {
            format = .watch38
            adaptedName = sourceImageName.substring(to: range.lowerBound)
        }
        
        return (adaptedName, format)
    }

}

