//
//  Synchable.swift
//  OfflineDataSyncProject
//
//  Created by Соня Буділова on 17.11.2024.
//

import Foundation
import RealmSwift

/// A protocol that defines the requirements for entities that can be synchronized with a remote database.
///
/// Conforms to `Object` (from Realm), `Codable`, and `Identifiable`. The conforming class must also implement
/// methods for copying an object with a new identifier and encoding the object to an encoder.
///
/// **Conformance Requirements:**
/// - The class should inherit from `RealmSwift.Object` to ensure it integrates with Realm.
/// - The conforming class must define the static property `entityName`, which returns the name of the entity.
/// - The class must have properties `lastUpdated` (to track the last update date) and `deleted` (to mark the entity as deleted).
/// - The class should implement a method `copy(withNewId:)` to allow creating a copy of the object with a new identifier.
/// - The `encode(to:)` method is required for conformance to `Codable`.
///
/// **Under the hood:**
/// - It automatically conforms to `Hashable` as well due to the `Object` and `Identifiable` conformance.
///
/// This protocol is used in data synchronization tasks where entities need to be synced between local storage and a remote database.
///
/// Example usage:
/// ```swift
/// class MyEntity: Object, Synchable {
///     static var entityName: String { "MyEntity" }
///     @objc dynamic var lastUpdated: Date = Date()
///     @objc dynamic var deleted: Bool = false
///
///     func copy(withNewId identifier: String) -> MyEntity {
///         let copy = MyEntity()
///         copy.id = identifier
///         return copy
///     }
///
///     func encode(to encoder: Encoder) throws {
///         // Implement encoding logic
///     }
/// }
/// ```
public protocol Synchable: Object, Codable, Identifiable {
    /// The name of the entity. This is used to identify the entity type for synchronization.
    static var entityName: String { get }
    
    /// The date of the last update to the entity. It is used for tracking and syncing purposes.
    var lastUpdated: Date { get set }
    
    /// A flag that indicates whether the entity has been marked as deleted.
    var deleted: Bool { get set }
    
    /// Creates a copy of the object with a new identifier.
    ///
    /// - Parameter identifier: The new identifier to assign to the copied entity.
    /// - Returns: A new copy of the object with the provided identifier.
    func copy(withNewId identifier: String) -> Self
    
    /// Encodes the object to the given encoder.
    ///
    /// - Parameter encoder: The encoder to which the object is to be encoded.
    /// - Throws: An error if encoding fails.
    func encode(to encoder: Encoder) throws
}
