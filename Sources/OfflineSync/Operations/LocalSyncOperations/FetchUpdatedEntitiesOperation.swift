//
//  FetchUpdatedEntitiesOperation.swift
//  OfflineDataSyncProject
//
//  Created by Соня Буділова on 17.11.2024.
//

import Foundation
import RealmSwift

class FetchUpdatedEntitiesOperation<T: Synchable & Object>: Operation, @unchecked Sendable {
    let entityType: T.Type
    let remoteDb: RemoteDb?
    var localMetadata: [Metadata]?
    var result: Result<[T], Error>?

    init(for entityType: T.Type, remoteDb: RemoteDb?) {
        self.entityType = entityType
        self.remoteDb = remoteDb
    }

    override func main() {
        guard !isCancelled, let localMetadata = localMetadata else { return }

        let semaphore = DispatchSemaphore(value: 0)
        remoteDb?.fetchUpdatedAndNewEntities(
            localMetadatas: localMetadata,
            entityType: entityType
        ) { [weak self] res in
            self?.result = res
            semaphore.signal()
        }

        semaphore.wait()
        Logger.shared.log.info("done FetchUpdatedEntitiesOperation")
    }
}
