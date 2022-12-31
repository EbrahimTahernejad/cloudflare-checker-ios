//
//  ContentView.swift
//  CloudFlare Checker
//
//  Created by Ebrahim Tahernejad on 10/7/1401 AP.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @StateObject var viewModel: ContentViewModel
    
    init() {
        _viewModel = StateObject(wrappedValue: ContentViewModel())
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    switch viewModel.state {
                    case .idle:
                        Slider(value: $viewModel.percentage, in: 0.0...1.0, step: 0.00001)
                        Text("Ping \(viewModel.percentage * 100.0)% of ips")
                        Button {
                            viewModel.startPinging()
                        } label: {
                            Text("GO")
                        }
                        if let results = viewModel.results {
                            ForEach(results[0..<min(20, results.count)]) { result in
                                HStack {
                                    Text("\(result.ip)")
                                    Button {
                                        UIPasteboard.general.string = result.ip
                                    } label: {
                                        Text("copy")
                                    }
                                    Spacer()
                                    Text("\(Int(result.loss * 100))%")
                                    Text("\(Int(result.time * 1000))ms")
                                }.padding(.horizontal, 10)
                            }
                        }
                    case .fetchingRanges:
                        Text("Loading...")
                    case .pinging:
                        if viewModel.progress == 0 {
                            Text("Initializing...")
                        } else {
                            Text("\(viewModel.progress * 100.0)%")
                        }
                    case .error:
                        Text("Error!")
                    }
                }
                
            }
            /*List {
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp!, formatter: itemFormatter)")
                    } label: {
                        Text(item.timestamp!, formatter: itemFormatter)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            Text("Select an item")*/
        }
    }
    
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
