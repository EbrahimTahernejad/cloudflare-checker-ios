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
    
    @Published var link: String = ""
    @Published private(set) var items: [Item] = []
    
    private var pinger = Pinger(maxConcurrentPings: 2, pingCount: 8)
    private var task: Task<[PingResponse], Never>?
    
    private var ranges: [IPRange] = []
    
    @Published var results: [PingResponse]? = nil
    
    @Published var state: State = .fetchingRanges
    
    init() {
        reloadItems()
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
        Task { [weak self] () in
            await self?.set(state: .pinging)
            await self?._startPinging()
            await self?.set(state: .idle)
        }
    }
    
    private func _startPinging() async {
        let task = Task { [ranges = self.ranges, pinger = self.pinger] () in
            return await pinger.start([ranges[0].ips[0]])
        }
        self.task = task
        let results = await task.value
        print(results)
        await set(results: results)
    }
    
    @MainActor private func set(results: [PingResponse]) {
        self.results = results
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
