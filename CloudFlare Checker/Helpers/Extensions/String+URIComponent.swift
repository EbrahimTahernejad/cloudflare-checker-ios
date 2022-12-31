//
//  String+URIComponent.swift
//  CloudFlare Checker
//
//  Created by Ebrahim Tahernejad on 10/9/1401 AP.
//

import Foundation

extension String {
    var encodeURIComponent: String? {
        return addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }
    
    var decodeURIComponent: String? {
        return removingPercentEncoding
    }
}
