//
//  Operations.swift
//  OfflineDataSyncProject
//
//  Created by Соня Буділова on 17.11.2024.
//

import Foundation
import RealmSwift
import SwiftyBeaver

struct Operations {
    static func getOperationsToSyncLocal<T: Synchable & Object>(
        for entityType: T.Type,
        remoteDb: RemoteDb?
    ) -> [Operation] {
        let getIdsAndUpdates = GetIdsAndUpdatesOperation(for: entityType)
        let fetchUpdatedEntities = FetchUpdatedEntitiesOperation(for: entityType, remoteDb: remoteDb)
        let saveEntities = SaveEntitiesOperationLocal(for: entityType)

        fetchUpdatedEntities.addDependency(getIdsAndUpdates) // maybe remove
        saveEntities.addDependency(fetchUpdatedEntities) // maybe remove

        let passMetadataToFetcher = BlockOperation {
            fetchUpdatedEntities.localMetadata = getIdsAndUpdates.result
        }
        passMetadataToFetcher.addDependency(getIdsAndUpdates)
        fetchUpdatedEntities.addDependency(passMetadataToFetcher)

        let passEntitiesToSaver = BlockOperation {
            if case let .success(entities)? = fetchUpdatedEntities.result {
                saveEntities.entities = entities
            }
        }
        passEntitiesToSaver.addDependency(fetchUpdatedEntities)
        saveEntities.addDependency(passEntitiesToSaver)

        return [getIdsAndUpdates, passMetadataToFetcher, fetchUpdatedEntities, passEntitiesToSaver, saveEntities]
    }

    static func getOperationsToSyncRemote<T: Synchable & Object>(
        for entityType: T.Type,
        remoteDb: RemoteDb?
    ) -> [Operation] {
        let fetchIdsAndUpdates = FetchIdsAndUpdatesOperation(remoteDb: remoteDb, entityName: T.entityName)
        let getUpdatedEntities = GetEntitiesAndSaveOperation<T>(entityType: entityType, remoteDb: remoteDb)

        getUpdatedEntities.addDependency(fetchIdsAndUpdates)

        let passMetadataToEntities = BlockOperation {
            if let result = fetchIdsAndUpdates.result, case let .success(metadata) = result {
                getUpdatedEntities.metadata = metadata
            } else {
                getUpdatedEntities.cancel()
            }
        }

        passMetadataToEntities.addDependency(fetchIdsAndUpdates)
        getUpdatedEntities.addDependency(passMetadataToEntities)

        return [
            fetchIdsAndUpdates,
            passMetadataToEntities,
            getUpdatedEntities
        ]
    }
}
