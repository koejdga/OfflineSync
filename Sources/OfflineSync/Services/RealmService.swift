//
//  RealmService.swift
//  OfflineDataSyncProject
//
//  Created by Соня Буділова on 17.11.2024.
//

import Foundation
import RealmSwift

let realmConfig = Realm.Configuration(
    schemaVersion: 4,
    migrationBlock: { _, oldSchemaVersion in
        if oldSchemaVersion < 4 {}
    }
)

public class RealmService {
    private let realm: Realm

    public init() {
        do {
            Realm.Configuration.defaultConfiguration = realmConfig
            realm = try Realm()
        } catch {
            print("Error initializing Realm: \(error.localizedDescription)")
            fatalError("Failed to initialize Realm")
        }
    }

    // MARK: - TodoTask Methods

    public func getAllEntityObjects<T: Synchable>() -> [T] {
        return realm.objects(T.self)
            .toArray(ofType: T.self)
    }

    func deleteAllEntityObjects<T: Object>(ofType type: T.Type) throws {
        do {
            try realm.write {
                let objectsToDelete = realm.objects(type)
                realm.delete(objectsToDelete)
            }
        } catch {
            throw error
        }
    }

    func getNewEntityObjects<T: Synchable>(date: Date) -> [T] {
        return realm.objects(T.self)
            .filter("lastUpdated > %@", date)
            .toArray(ofType: T.self)
    }

    public func saveEntityObject<T: Synchable>(_ entity: T, realm: Realm? = nil) throws {
        do {
            let realmToUse = if let realm { realm } else { self.realm }
            try realmToUse.write {
                if let existingObject = realmToUse.object(ofType: T.self,
                                                          forPrimaryKey: entity.id)
                {
                    Logger.shared.log.info("deleting existing entity object")
                    realmToUse.delete(existingObject)
                }
                realmToUse.add(entity)
                Logger.shared.log.info("added new entity object")
            }
        } catch {
            throw error
        }
    }

    public func deleteEntityObject<T: Synchable>(_ entity: T) throws {
        do {
            try realm.write {
                if let existingObject = realm.object(ofType: T.self,
                                                     forPrimaryKey: entity.id)
                {
                    existingObject.deleted = true
                    Logger.shared.log.info("deleted existing entity object")
                } else {
                    Logger.shared.log.info("delete method was called but nothing was deleted")
                }
            }
        } catch {
            throw error
        }
    }

    // MARK: - New methods

    func getIdsAndUpdateDates<S: Synchable>(entityType: S.Type, realm: Realm? = nil) -> [Metadata] {
        Logger.shared.log.debug("Current thread: \(Thread.current)")
        let realmToUse = if let realm { realm } else { self.realm }

        let allObjects = realmToUse.objects(entityType).toArray(ofType: entityType)
        return allObjects.map { Metadata(id: String(describing: $0.id),
                                         lastUpdated: $0.lastUpdated,
                                         deleted: $0.deleted) }
    }

    func getUpdatedAndNewEntities<T: Synchable>(
        objectsMetadata: [Metadata], entityType: T.Type, realm: Realm? = nil
    ) -> [T] {
        let realmToUse = if let realm { realm } else { self.realm }

        let allObjects = realmToUse.objects(T.self).toArray(ofType: T.self)

        var entitiesToSync: [T] = []

        for localEntity in allObjects {
            // Check if there is remote instance with such id that local one has
            if let metadataForRemoteObj = objectsMetadata.filter(
                { $0.id == String(describing: localEntity.id) }
            ).first {
                if metadataForRemoteObj.deleted {
                    /* do nothing, object is already deleted */
                } else if metadataForRemoteObj.lastUpdated < localEntity.lastUpdated {
                    // Entity is updated
                    entitiesToSync.append(localEntity)
                }
            } else {
                // Entity is new
                entitiesToSync.append(localEntity)
            }
        }

        return entitiesToSync
    }

    func setNewUpdateDate<T: Synchable>(object: T, realm: Realm? = nil) throws {
        let realmToUse = if let realm { realm } else { self.realm }

        try realmToUse.write {
            object.lastUpdated = Date()
        }
    }

    // MARK: - Background Stuff

    func deleteFeedEntries1<T: Synchable>(entity: T.Type,
                                          predicate: NSPredicate?,
                                          cancelCheck: @escaping () -> Bool)
    {
        var entriesToDelete: Results<T>

        if let predicate = predicate {
            entriesToDelete = realm.objects(T.self).filter(predicate)
        } else {
            entriesToDelete = realm.objects(T.self)
        }

        do {
            for entry in entriesToDelete.sorted(byKeyPath: "lastUpdated", ascending: true) {
                print("Deleting entry with timestamp: \(entry.lastUpdated.description)")

                try realm.write {
                    realm.delete(entry)
                }

                if cancelCheck() {
                    break
                }
            }
        } catch {
            print("Error deleting entries: \(error)")
        }
    }

    func deleteFeedEntries<T: Synchable>(
        entity: T.Type,
        predicate: NSPredicate?, // change to date, move predicate inside
        maxEntries: Int? = nil,
        cancelCheck: @escaping () -> Bool
    ) {
        do {
            if let predicate {
                let entriesToDelete = realm.objects(entity.self).filter(predicate)

                for entry in entriesToDelete {
                    print("Deleting entry with timestamp: \(entry.lastUpdated.description)")

                    try realm.write {
                        realm.delete(entry)
                    }

                    if cancelCheck() {
                        break
                    }
                }
            }

            if let maxEntries {
                let allEntries = realm.objects(entity.self)
                    .sorted(byKeyPath: "lastUpdated", ascending: true)

                if allEntries.count > maxEntries {
                    let amountToDelete = allEntries.count - maxEntries
                    let entriesToDelete = allEntries.prefix(amountToDelete)

                    for entry in entriesToDelete {
                        print("Deleting entry with timestamp: \(entry.lastUpdated.description)")

                        try realm.write {
                            realm.delete(entry)
                        }

                        if cancelCheck() {
                            break
                        }
                    }

                    print("Deleted \(amountToDelete) excess entries to maintain max limit of \(maxEntries).")
                }
            }

        } catch {
            print("Error deleting entries: \(error)")
        }
    }
}

extension Results {
    func toArray<T>(ofType: T.Type) -> [T] {
        var array = [T]()
        for index in 0 ..< count {
            if let result = self[index] as? T {
                array.append(result)
            }
        }

        return array
    }
}
