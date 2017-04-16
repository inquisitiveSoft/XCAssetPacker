//
//  Extensions.swift
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


extension String {

    func isMatchedBy(_ patterns: [String]) -> Bool {
        for pattern in patterns {
            if isMatchedBy(pattern) {
                return true
            }
        }
        
        return false
    }
    
    
    func isMatchedBy(_ pattern: String) -> Bool {
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            return regex.numberOfMatches(in: self, options: [], range: self.asNSRange) > 0
        }
        
        return false
    }
    
    
    var asNSRange: NSRange {
        return NSRange(location: 0, length: (self as NSString).length)
    }

}


extension URL {
    
    func appending(pathComponents: [String]) -> URL {
        var url = self
        
        for pathComponent in pathComponents {
            url = url.appendingPathComponent(pathComponent)
        }
        
        return url
    }

}


// The MIT License (MIT)
//
// Copyright (c) 2014 Ankur Patel
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// https://github.com/ankurp/Cent/blob/master/Sources/Dictionary.swift


extension Dictionary {

    mutating func merge<K, V>(dict: [K: V]) {
        for (k, v) in dict {
            self.updateValue(v as! Value, forKey: k as! Key)
        }
    }
    
}

