//
//  SaveEntitiesOperationLocal.swift
//  OfflineDataSyncProject
//
//  Created by Соня Буділова on 17.11.2024.
//

import Foundation
import RealmSwift

class SaveEntitiesOperationLocal<T: Synchable & Object>: Operation, @unchecked Sendable {
    let entityType: T.Type
    var entities: [T]?

    init(for entityType: T.Type) {
        self.entityType = entityType
    }

    override func main() {
        guard !isCancelled, let entities = entities else { return }

        let realmService = RealmService()
        for entity in entities {
            if isCancelled { return }
            try? realmService.setNewUpdateDate(object: entity)
            try? realmService.saveEntityObject(entity)
        }
        Logger.shared.log.info("done SaveEntitiesOperation")
    }
}
