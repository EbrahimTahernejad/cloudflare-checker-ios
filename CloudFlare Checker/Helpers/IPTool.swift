//
//  IPTool.swift
//  CloudFlare Checker
//
//  Created by Ebrahim Tahernejad on 10/10/1401 AP.
//

import Foundation

struct IPRange {
    let range: String
    var ips: [String] {
        return IPTool.rangeToIPs(range)
    }
}

class IPTool {
    
    static func cloudflare() async throws -> [IPRange] {
        let ranges = try await Fetch.getCloudflareIPRanges()
        return ranges.map { IPRange(range: $0) }
    }
    
    fileprivate static func rangeToIPs(_ range: String) -> [String] {
        let components = range.components(separatedBy: "/")
        guard
            components.count == 2,
            let subnet = Int(components.last ?? ""),
            let base = components.first
        else {
            return []
        }
        let ip = base
            .components(separatedBy: ".")
            .enumerated()
            .map { UInt32($0.1)! << UInt32((3 - $0.0) * 8) }
            .reduce(UInt32(0), +)
        let offsets = Array(UInt32(0)..<(UInt32(1) << (32 - subnet)))
        return offsets
            .map { ip + $0 }
            .map { ip in
                let ip4 = String((ip >> 00) & UInt32(255))
                let ip3 = String((ip >> 08) & UInt32(255))
                let ip2 = String((ip >> 16) & UInt32(255))
                let ip1 = String((ip >> 24) & UInt32(255))
                return "\(ip1).\(ip2).\(ip3).\(ip4)"
            }
    }
    
}


// MARK: - Fetch
extension IPTool {
    
    fileprivate class Fetch {
        
        static func request(_ url: String) async throws -> Data {
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                guard let url = URL(string: url) else {
                    continuation.resume(throwing: URLError(.badURL))
                    return
                }
                let request = URLRequest(url: url)
                let task = URLSession.shared.dataTask(with: request) { data, _, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let data = data else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                        return
                    }
                    continuation.resume(returning: data)
                }
                task.resume()
            }
        }
        
        static func getCloudflareIPRanges() async throws -> [String] {
            let responseData = try await Self.request("https://www.cloudflare.com/ips-v4")
            guard
                let response = String(data: responseData, encoding: .utf8)
            else {
                throw URLError(.badServerResponse)
            }
            return response
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.count > 0 }
        }
        
    }
    
}
