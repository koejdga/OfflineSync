//
//  File.swift
//  OfflineSync
//
//  Created by Соня Буділова on 17.11.2024.
//

import SwiftyBeaver

class Logger {
    static let shared = Logger()
    let log = SwiftyBeaver.self

    private init() {
        let console = ConsoleDestination()
        console.useNSLog = true
        log.addDestination(console)
    }
}
