//
//  RemoteDb.swift
//  OfflineDataSyncProject
//
//  Created by Соня Буділова on 17.11.2024.
//

import Foundation

public protocol RemoteDb {
    static var shared: RemoteDb { get }

    func saveEntityObject<T: Synchable>(
        _ entityObject: T,
        withID id: String?,
        completion: @escaping (Error?) -> Void)

    func fetchNewEntityObjects<T: Synchable>(
        for entityType: T.Type,
        lastSyncDate: Date?,
        completion: @escaping ([T]?, Error?) -> Void)

    func getIdsAndUpdateDates(
        entityName: String,
        completion: @escaping (Result<[Metadata], Error>) -> Void)

    func fetchUpdatedAndNewEntities<T: Synchable>(
        localMetadatas: [Metadata],
        entityType: T.Type,
        completion: @escaping (Result<[T], Error>) -> Void)
}
