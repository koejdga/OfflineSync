//
//  DeleteFeedEntries.swift
//  OfflineDataSyncProject
//
//  Created by Соня Буділова on 17.11.2024.
//

import Foundation
import RealmSwift

class CleanDatabaseOperation<T: Synchable & Object>: Operation, @unchecked Sendable {
    let predicate: NSPredicate?
    let maxEntries: Int?
    let entityType: T.Type

    init(for entityType: T.Type, predicate: NSPredicate?, maxEntries: Int?) {
        self.entityType = entityType
        self.predicate = predicate
        self.maxEntries = maxEntries
    }

    override func main() {
        RealmService().deleteFeedEntries(entity: T.self,
                                         predicate: predicate,
                                         maxEntries: maxEntries,
                                         cancelCheck: { [weak self] in
                                             self?.isCancelled ?? true
                                         })
    }
}
