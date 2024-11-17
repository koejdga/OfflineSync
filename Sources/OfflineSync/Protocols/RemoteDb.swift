//
//  RemoteDb.swift
//  OfflineDataSyncProject
//
//  Created by Соня Буділова on 17.11.2024.
//

import Foundation

/// A protocol that defines the interface for interacting with a remote database.
/// This protocol is used to save, fetch, and manage synchronization of entities between a local and remote database.
///
/// **Conformance Requirements:**
/// - The conforming type must provide a shared instance (e.g., singleton) that conforms to `RemoteDb`.
/// - The protocol defines methods for saving entities, fetching new entities, and managing metadata for synchronization.
///
/// **Example usage:**
/// ```swift
/// class MyRemoteDb: RemoteDb {
///     static var shared: RemoteDb { return MyRemoteDb() }
///
///     func saveEntityObject<T: Synchable>(
///         _ entityObject: T,
///         withID id: String?,
///         completion: @escaping (Error?) -> Void) {
///         // Implement saving logic
///     }
///
///     func fetchNewEntityObjects<T: Synchable>(
///         for entityType: T.Type,
///         lastSyncDate: Date?,
///         completion: @escaping ([T]?, Error?) -> Void) {
///         // Implement fetching logic
///     }
///
///     func getIdsAndUpdateDates(
///         entityName: String,
///         completion: @escaping (Result<[Metadata], Error>) -> Void) {
///         // Implement metadata fetching logic
///     }
///
///     func fetchUpdatedAndNewEntities<T: Synchable>(
///         localMetadatas: [Metadata],
///         entityType: T.Type,
///         completion: @escaping (Result<[T], Error>) -> Void) {
///         // Implement fetching logic for updated or new entities
///     }
/// }
/// ```
/// The methods are used to handle various remote database tasks like syncing data from a server, updating local storage with new or updated data, and handling metadata (like IDs and update dates).
public protocol RemoteDb {
    /// A shared instance of the conforming `RemoteDb` type (e.g., a singleton pattern).
    static var shared: RemoteDb { get }
    
    /// Saves an entity object to the remote database.
    ///
    /// - Parameters:
    ///   - entityObject: The entity object that conforms to `Synchable` to be saved.
    ///   - id: The optional ID to be used for the entity object. If nil, an ID will be generated or inferred.
    ///   - completion: A closure to be called once the save operation finishes. It returns an error if the operation fails.
    func saveEntityObject<T: Synchable>(
        _ entityObject: T,
        withID id: String?,
        completion: @escaping (Error?) -> Void)
    
    /// Fetches new entity objects from the remote database based on the last synchronization date.
    ///
    /// - Parameters:
    ///   - entityType: The type of the entity to fetch.
    ///   - lastSyncDate: The date of the last sync, used to fetch entities updated after this date. If nil, fetch all.
    ///   - completion: A closure that returns an array of the fetched entities or an error.
    func fetchNewEntityObjects<T: Synchable>(
        for entityType: T.Type,
        lastSyncDate: Date?,
        completion: @escaping ([T]?, Error?) -> Void)
    
    /// Retrieves metadata (such as IDs and update dates) for entities of a specific type.
    ///
    /// - Parameters:
    ///   - entityName: The name of the entity to fetch metadata for.
    ///   - completion: A closure that returns a result containing an array of `Metadata` objects or an error.
    func getIdsAndUpdateDates(
        entityName: String,
        completion: @escaping (Result<[Metadata], Error>) -> Void)
    
    /// Fetches updated or newly created entities from the remote database based on local metadata.
    ///
    /// - Parameters:
    ///   - localMetadatas: An array of `Metadata` objects representing the current local entities.
    ///   - entityType: The type of the entities to fetch.
    ///   - completion: A closure that returns a result containing an array of fetched entities or an error.
    func fetchUpdatedAndNewEntities<T: Synchable>(
        localMetadatas: [Metadata],
        entityType: T.Type,
        completion: @escaping (Result<[T], Error>) -> Void)
}
