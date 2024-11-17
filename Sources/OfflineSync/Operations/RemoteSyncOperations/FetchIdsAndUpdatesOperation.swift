//
//  FetchIdsAndUpdatesOperation.swift
//  OfflineDataSyncProject
//
//  Created by Соня Буділова on 17.11.2024.
//

import Foundation

class FetchIdsAndUpdatesOperation: Operation, @unchecked Sendable {
    let remoteDb: RemoteDb?
    let entityName: String
    var result: Result<[Metadata], Error>?

    init(remoteDb: RemoteDb?, entityName: String) {
        self.remoteDb = remoteDb
        self.entityName = entityName
    }

    override func main() {
        guard !isCancelled else { return }

        let semaphore = DispatchSemaphore(value: 0)
        remoteDb?.getIdsAndUpdateDates(entityName: entityName) { [weak self] res in
            self?.result = res
            semaphore.signal()
        }
        semaphore.wait()
        Logger.shared.log.info("done FetchIdsAndUpdatesOperation")
    }
}
