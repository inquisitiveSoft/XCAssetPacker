//
//  DeviceIdiom.swift
//  XCAssetPacker
//
//  Created by Harry Jordan on 04/09/2017.
//  Copyright © 2017 Inquisitive Software. All rights reserved.
//

import Foundation


public enum DeviceIdiom: String {
    case watch, iPhone, iPad
    
    static var all: [DeviceIdiom] = [watch, iPhone, iPad]
    
    
    init?(_ idiomString: String) {
        let idiom = DeviceIdiom.all.first(where: {
            $0.idiomString.caseInsensitiveCompare(idiomString) == .orderedSame
        })
        
        if let idiom = idiom {
            self = idiom
        } else {
            return nil
        }
    }
    
    
    var idiomString: String {
        // Keys used for xcasset properties
        switch self {
        case .watch:
            return "watch"
        
        case .iPhone:
            return "iphone"
        
        case .iPad:
            return "ipad"
        }
    }

    
    var configurationKey: String {
        // Keys used to match strings in the configuration .json
        return self.rawValue
    }

}
