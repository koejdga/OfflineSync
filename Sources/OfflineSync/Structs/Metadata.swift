//
//  Metadata.swift
//  OfflineDataSyncProject
//
//  Created by Соня Буділова on 17.11.2024.
//

import Foundation

/// A struct that represents metadata for an entity. It contains information about the entity's ID, the last time it was updated, and whether it has been deleted.
///
/// This struct is typically used for tracking the state of entities in the context of synchronization, allowing the system to know which entities need to be updated or removed.
public struct Metadata {
    /// The unique identifier of the entity.
    ///
    /// This ID is used to distinguish different entities and is typically used in sync operations to fetch or update specific entities.
    public let id: String

    /// The date and time when the entity was last updated.
    ///
    /// This date is useful for determining if an entity has been modified since the last synchronization, allowing for updates to be fetched.
    public let lastUpdated: Date

    /// A flag indicating whether the entity has been deleted.
    ///
    /// This is typically used in synchronization scenarios to determine whether the entity should be removed from the local storage or database.
    public let deleted: Bool

    /// Initializes a new `Metadata` instance with the provided values.
    ///
    /// - Parameters:
    ///   - id: The unique identifier of the entity.
    ///   - lastUpdated: The date when the entity was last updated.
    ///   - deleted: A flag indicating if the entity has been deleted.
    public init(id: String, lastUpdated: Date, deleted: Bool) {
        self.id = id
        self.lastUpdated = lastUpdated
        self.deleted = deleted
    }
}
