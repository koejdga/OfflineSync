//
//  Synchable.swift
//  OfflineDataSyncProject
//
//  Created by Соня Буділова on 17.11.2024.
//

import Foundation
import RealmSwift

/// Under the hood it conforms to Hashable as well
/// To conform to Synchable class should inherit RealmSwiftObject
public protocol Synchable: Object, Codable, Identifiable {
    static var entityName: String { get }
    var lastUpdated: Date { get set }
    var deleted: Bool { get set }
    func copy(withNewId identifier: String) -> Self
    func encode(to encoder: Encoder) throws
}
