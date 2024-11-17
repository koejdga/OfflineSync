//
//  File.swift
//  OfflineSync
//
//  Created by Соня Буділова on 17.11.2024.
//

import Foundation
import Network

public class NetworkChecker {
    private let monitor = NWPathMonitor()

    public init(onNetworkAvailable: @escaping () -> Void, onNetworkAbsent: @escaping () -> Void) {
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                onNetworkAvailable()

            } else {
                onNetworkAbsent()
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }
}
