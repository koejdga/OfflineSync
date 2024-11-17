//
//  GetIdsAndUpdatesOperation.swift
//  OfflineDataSyncProject
//
//  Created by Соня Буділова on 17.11.2024.
//

import Foundation
import RealmSwift

class GetIdsAndUpdatesOperation<T: Synchable & Object>: Operation, @unchecked Sendable {
    let entityType: T.Type
    var result: [Metadata]?

    init(for entityType: T.Type) {
        self.entityType = entityType
    }

    override func main() {
        guard !isCancelled else { return }

        result = RealmService().getIdsAndUpdateDates(entityType: entityType)
        Logger.shared.log.info("done GetIdsAndUpdatesOperation")
    }
}
