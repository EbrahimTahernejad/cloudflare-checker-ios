//
//  ContentViewModel.swift
//  CloudFlare Checker
//
//  Created by Ebrahim Tahernejad on 10/7/1401 AP.
//

import Combine
import CoreData
import SwiftUI

class ContentViewModel: ObservableObject {
    
    enum State {
        case fetchingRanges, error, idle, pinging
    }
    
    private var cancelBag: Set<AnyCancellable> = .init()
    private var viewContext: NSManagedObjectContext {
        PersistenceController.shared.container.viewContext
    }
    
    private var pinger = Pinger(maxConcurrentPings: 18, pingCount: 5)
    private var task: Task<[PingResponse], Never>?
    
    private var ranges: [IPRange] = []
    
    @Published var link: String = ""
    @Published var percentage: Double = 1000.0 / 1000000.0
    
    @Published private(set) var items: [Item] = []
    @Published private(set) var results: [PingResponse]? = nil
    @Published private(set) var state: State = .fetchingRanges
    @Published private(set) var progress: Double = 0.0
    
    init() {
        reloadItems()
        pinger.$progress
            .receive(on: DispatchQueue.main)
            .assign(to: \.progress, on: self)
            .store(in: &cancelBag)
        Task { [weak self] () in
            do {
                self?.ranges = try await IPTool.cloudflare()
                await self?.set(state: .idle)
            } catch {
                await self?.set(state: .error)
            }
        }
    }
    
    func startPinging() {
        guard state == .idle else { return }
        progress = 0
        Task { [weak self] () in
            await self?.set(state: .pinging)
            await self?._startPinging()
            await self?.set(state: .idle)
        }
    }
    
    private func _startPinging() async {
        let task = Task { [ranges = self.ranges, pinger = self.pinger, percentage = self.percentage] () -> [PingResponse] in
            let ips = ranges.flatMap { $0.ips.shuffled()[0..<Int(Double($0.ips.count) * percentage)] }
            return await pinger.start(ips)
        }
        self.task = task
        let results = await task.value
        await set(results: results)
    }
    
    @MainActor private func set(results: [PingResponse]) {
        self.results = results.sorted { $0.loss < $1.loss || ( $0.loss == $1.loss && $0.time < $1.time ) }
    }
    
    @MainActor private func set(state: State) {
        self.state = state
    }
    
    // MARK: - CoreData item management
    private func reloadItems() {
        items = (try? Item.fetchRequest().execute()) ?? []
    }
    
    private func addItem() {
        let newItem = Item(context: viewContext)
        newItem.timestamp = Date()
        newItem.link = link

        do {
            try viewContext.save()
        } catch {
            // error
        }
        
        reloadItems()
    }

    private func deleteItems(offsets: IndexSet) {
        offsets.map { items[$0] }.forEach(viewContext.delete)

        do {
            try viewContext.save()
        } catch {
            // error
        }
        
        reloadItems()
    }
    
}
