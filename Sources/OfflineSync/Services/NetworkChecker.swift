//
//  File.swift
//  OfflineSync
//
//  Created by Соня Буділова on 17.11.2024.
//

import Foundation
import Network

/// A class responsible for monitoring the network connectivity status and notifying when the network is available or absent.
///
/// This class uses the `NWPathMonitor` API to observe changes in the network path and triggers the appropriate closure when the network is available or absent. It provides a simple way to track network status in real-time and take action based on the connectivity state.
public class NetworkChecker {
    /// The monitor used to track network path changes.
    private let monitor = NWPathMonitor()

    /// Initializes a new `NetworkChecker` instance to monitor the network status.
    ///
    /// - Parameters:
    ///   - onNetworkAvailable: A closure to be called when the network is available.
    ///   - onNetworkAbsent: A closure to be called when the network is absent.
    ///
    /// This initializer sets up the `NWPathMonitor` to track changes in the network path. When the network status is updated, the appropriate closure is triggered based on whether the network is available or not.
    public init(onNetworkAvailable: @escaping () -> Void, onNetworkAbsent: @escaping () -> Void) {
        // Set the path update handler to respond to network changes.
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                // Network is available, trigger the onNetworkAvailable closure.
                onNetworkAvailable()
            } else {
                // Network is absent, trigger the onNetworkAbsent closure.
                onNetworkAbsent()
            }
        }

        // Start monitoring the network path using a background queue.
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }
}
