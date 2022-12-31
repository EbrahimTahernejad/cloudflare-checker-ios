//
//  IPTool.swift
//  CloudFlare Checker
//
//  Created by Ebrahim Tahernejad on 10/8/1401 AP.
//

import Foundation
import GBPing

struct PingResponse: Identifiable {
    let id: String = UUID().uuidString
    let ip: String
    let transmitted: UInt64
    let received: UInt64
    let time: TimeInterval
    
    var loss: Double {
        guard transmitted > 0 else { return 0 }
        return Double(transmitted - received) / Double(transmitted)
    }
}

class Pinger {
    private let semaphore: Semaphore
    private let pingCount: Int
    
    @Published private(set) var progress: Double = 0.0
    
    init(maxConcurrentPings: Int = 400, pingCount: Int) {
        self.pingCount = pingCount
        semaphore = Semaphore(value: maxConcurrentPings)
    }
    
    func start(_ ips: [String]) async -> [PingResponse] {
        return await withTaskGroup(of: (PingResponse?).self, returning: [PingResponse].self) { [weak self] group -> [PingResponse] in
            for ip in ips {
                group.addTask { [weak self] () in
                    return await self?.ping(ip)
                }
            }
                  
            var responses = [PingResponse]()
            var allDoneCount = 0
            for await response in group {
                allDoneCount += 1
                progress = Double(allDoneCount) / Double(ips.count)
                guard let response = response else { continue }
                responses.append(response)
            }
            
            return responses
        }
    }
    
    private func ping(_ ip: String) async -> PingResponse? {
        do {
            try await semaphore.waitUnlessCancelled()
        } catch {
            return nil
        }
        defer {
            semaphore.signal()
        }
        return await _ping(ip)
    }
    
    private func _ping(_ ip: String) async -> PingResponse? {
        return await GBPingContainer(ip: ip, limit: pingCount).start()
    }
    
}

// MARK: - Add async/await to GBPing
fileprivate class GBPingContainer: NSObject, GBPingDelegate {
    var ping: GBPing?
    let ip: String
    let limit: Int
    var sent: UInt64 = 0
    var replied: UInt64 = 0
    var continuation: CheckedContinuation<PingResponse?, Never>? = nil
    var rrts: [TimeInterval] = []
    var lock = NSRecursiveLock()
    var isFinished = false
    
    init(ip: String, limit: Int) {
        let ping = GBPing()
        ping.host = ip
        ping.timeout = 1.0
        ping.pingPeriod = 0.1
        self.ping = ping
        self.limit = limit
        self.ip = ip
        super.init()
        ping.delegate = self
    }
    
    func start() async -> PingResponse? {
        return await withCheckedContinuation { [weak self] continuation in
            self?.ping?.setup { (success, _) in
                guard success else {
                    continuation.resume(with: .success(nil))
                    return
                }
                self?.continuation = continuation
                self?.ping?.startPinging()
            }
        }
    }
    
    func ping(_ pinger: GBPing, didSendPingWith summary: GBPingSummary) {
        print("Ping \(ip) #\(summary.sequenceNumber)")
        lock.lock()
        guard !isFinished else { return }
        guard summary.sequenceNumber < limit else {
            pinger.stop()
            let rrt = rrts.count > 0 ? rrts.reduce(0, +) / TimeInterval(rrts.count) : 0.0
            isFinished = true
            continuation?.resume(with: .success(.init(ip: ip, transmitted: sent, received: replied, time: rrt)))
            lock.unlock()
            return
        }
        sent += 1
        lock.unlock()
    }
    
    func ping(_ pinger: GBPing, didReceiveReplyWith summary: GBPingSummary) {
        guard summary.sequenceNumber < limit else { return }
        replied += 1
        rrts.append(summary.rtt)
    }
}
