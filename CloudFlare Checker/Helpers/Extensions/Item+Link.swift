//
//  Item+Link.swift
//  CloudFlare Checker
//
//  Created by Ebrahim Tahernejad on 10/8/1401 AP.
//

import Foundation

extension Item {
    
    enum LinkType: String {
        case vmess, vless, trojan
    }
    
    var type: LinkType? {
        return .init(rawValue: link?.components(separatedBy: ":").first ?? "")
    }
    
    func enableTLS() {
        guard let type else { return }
        switch type {
        case .vless, .trojan:
            setLink(value: "tls", forKey: "tls")
        case .vmess:
            setJSON(value: "tls", forKey: "tls")
        }
    }
    
    func set(ip: String) {
        guard let type else { return }
        switch type {
        case .vless, .trojan:
            setLink(address: ip)
        case .vmess:
            setJSON(value: ip, forKey: "add")
        }
    }
    
}


// MARK: - VMESS JSON Manipulation
extension Item {
    
    private func decodeJSON() -> (String, NSDictionary)? {
        guard
            let link,
            let colonIndex = link.firstIndex(of: ":")
        else {
            return nil
        }
        let startIndex = link.index(colonIndex, offsetBy: 3)
        let base64 = String(link[startIndex...])
        let proto = String(link[..<startIndex])
        guard
            let data = Data(base64Encoded: base64),
            let json = try? JSONSerialization.jsonObject(with: data, options: .mutableLeaves) as? NSDictionary
        else {
            return nil
        }
        return (proto, json)
    }
    
    fileprivate func setJSON(value: Any?, forKey key: String) {
        guard
            let (proto, json) = decodeJSON()
        else {
            return
        }
        json.setValue(value, forKey: key)
        guard
            let data = try? JSONSerialization.data(withJSONObject: json)
        else {
            return
        }
        link = proto + data.base64EncodedString()
    }
    
    fileprivate func getJSON<T>(valueOf key: String, type: T.Type) -> T? {
        guard
            let (_, json) = decodeJSON()
        else {
            return nil
        }
        return json.value(forKey: key) as? T
    }
    
}

// MARK: - VLESS/TROJAN URL Manipulation
extension Item {
    
    private func getLinkAddress() -> (Range<String.Index>, String)? {
        guard
            let link,
            let atSignIndex = link.firstIndex(of: "@")
        else {
            return nil
        }
        let startIndex = link.index(after: atSignIndex)
        guard
            let endIndex = link.firstIndex(of: "?")
        else {
            return nil
        }
        return (startIndex..<endIndex, String(link[startIndex..<endIndex]))
    }
    
    private func getLinkQueryRange() -> Range<String.Index>? {
        guard
            let link,
            let queryMarkIndex = link.firstIndex(of: "?")
        else {
            return nil
        }
        let startIndex = link.index(after: queryMarkIndex)
        guard
            let endIndex = link.firstIndex(of: "#")
        else {
            return nil
        }
        return startIndex..<endIndex
    }
    
    private func getLinkQuery() -> [String:String]? {
        guard
            let queryRange = getLinkQueryRange(),
            let queryString = link?[queryRange]
        else {
            return nil
        }
        return Dictionary(
            uniqueKeysWithValues:
                queryString
                    .components(separatedBy: "&")
                    .compactMap{ component -> (String, String)? in
                        let parts = component.components(separatedBy: "=")
                        guard
                            let k = parts.first?.decodeURIComponent,
                            let v = parts.last?.decodeURIComponent
                        else {
                            return nil
                        }
                        return (k, v)
                    }
        )
    }
    
    private func setLink(query: [String:String]) {
        guard
            let queryRange = getLinkQueryRange()
        else {
            return
        }
        let queryString = query.compactMap { (k, v) -> String? in
            guard
                let k = k.encodeURIComponent,
                let v = v.encodeURIComponent
            else {
                return nil
            }
            return k + "=" + v
        }.joined(separator: "&")
        link = link?.replacingCharacters(in: queryRange, with: queryString)
    }
    
    private func getLinkValue(forKey key: String) -> String? {
        return getLinkQuery()?[key]
    }
    
    fileprivate func setLink(value: String, forKey key: String) {
        guard
            var query = getLinkQuery()
        else {
            return
        }
        query[key] = value
        setLink(query: query)
    }
    
    fileprivate func setLink(address: String) {
        guard
            let (addressRange, previous) = getLinkAddress()
        else {
            return
        }
        link = link?.replacingCharacters(in: addressRange, with: address)
        let host = getLinkValue(forKey: "host") ?? getLinkValue(forKey: "sni") ?? previous
        setLink(value: host, forKey: "sni")
        setLink(value: host, forKey: "host")
    }
    
}
