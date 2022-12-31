//
//  Semaphore.swift
//  CloudFlare Checker
//
//  Created by Ebrahim Tahernejad on 10/9/1401 AP.
//

import Foundation

class Semaphore: @unchecked Sendable {
    
    private class AsyncTask {
        enum State {
            case pending
            case waitingUnlessCancelled(UnsafeContinuation<Void, Error>)
            case waiting(UnsafeContinuation<Void, Never>)
            case cancelled
        }
        var state: State
        init() {
            state = .pending
        }
        init(continuation: UnsafeContinuation<Void, Never>) {
            state = .waiting(continuation)
        }
    }
    
    private var value: Int
    private let _lock = NSRecursiveLock()
    init(value: Int) {
        self.value = value
    }
    
    private var tasks: [AsyncTask] = []
    
    // Why do we need this?
    private func lock() { _lock.lock() }
    private func unlock() { _lock.unlock() }
    
    func wait() async {
        lock()
        
        value -= 1
        if value >= 0 {
            unlock()
            return
        }
        
        await withUnsafeContinuation { [weak self] (continuation: UnsafeContinuation<Void, Never>) in
            // FIFO
            self?.tasks.insert(.init(continuation: continuation), at: 0)
            self?.unlock()
        }
    }
    
    func waitUnlessCancelled() async throws {
        lock()
        
        value -= 1
        if value >= 0 {
            unlock()
            try Task.checkCancellation()
            return
        }
        
        let task = AsyncTask()
        
        try await withTaskCancellationHandler { [task, weak self] () in
            try await withUnsafeThrowingContinuation { [task, weak self] (continuation: UnsafeContinuation<Void, Error>) in
                if case .cancelled = task.state {
                    self?.unlock()
                    continuation.resume(throwing: CancellationError())
                } else {
                    task.state = .waitingUnlessCancelled(continuation)
                    self?.tasks.insert(task, at: 0)
                    self?.unlock()
                }
            }
        } onCancel: { [task, weak self] () in
            self?.lock()
            defer { self?.unlock() }
            
            self?.value += 1
            if let index = self?.tasks.firstIndex(where: { $0 === task }) {
                self?.tasks.remove(at: index)
            }
            
            if case let .waitingUnlessCancelled(continuation) = task.state {
                continuation.resume(throwing: CancellationError())
            } else {
                task.state = .cancelled
            }
        }
    }
    
    @discardableResult
    func signal() -> Bool {
        lock()
        defer { unlock() }
        
        value += 1
        
        switch tasks.popLast()?.state {
        case let .waitingUnlessCancelled(continuation):
            continuation.resume()
            return true
        case let .waiting(continuation):
            continuation.resume()
            return true
        default:
            return false
        }
    }
}
