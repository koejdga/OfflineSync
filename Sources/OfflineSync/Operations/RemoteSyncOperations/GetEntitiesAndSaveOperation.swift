//
//  GetEntitiesAndSaveOperation.swift
//  OfflineDataSyncProject
//
//  Created by Соня Буділова on 17.11.2024.
//

import Foundation
import RealmSwift

class GetEntitiesAndSaveOperation<T: Synchable & Object>: Operation, @unchecked Sendable {
    let entityType: T.Type
    var metadata: [Metadata]?
    var result: [T] = []
    let remoteDb: RemoteDb?

    init(entityType: T.Type, remoteDb: RemoteDb?) {
        self.entityType = entityType
        self.remoteDb = remoteDb
    }

    override func main() {
        guard !isCancelled, let metadata = metadata else { return }

        let realmService = RealmService()
        result = realmService.getUpdatedAndNewEntities(objectsMetadata: metadata, entityType: entityType)

        guard !isCancelled else { return }

        for entity in result {
            guard !isCancelled else { return }

            Logger.shared.log.info("we are here")
            try? realmService.setNewUpdateDate(object: entity)
            let semaphore = DispatchSemaphore(value: 0)
            remoteDb?.saveEntityObject(entity, withID: String(describing: entity.id)) { error in
                if let err = error {
                    Logger.shared.log.error("Could not save local entity on server: \(err)")
                } else {
                    Logger.shared.log.debug("Entity saved successfully.")
                }
                semaphore.signal()
            }
            semaphore.wait()
        }
        Logger.shared.log.info("done GetEntitiesAndSaveOperation")
    }
}
