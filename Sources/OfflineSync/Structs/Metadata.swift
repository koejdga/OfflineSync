//
//  Metadata.swift
//  OfflineDataSyncProject
//
//  Created by Соня Буділова on 17.11.2024.
//

import Foundation

public struct Metadata {
    public let id: String
    public let lastUpdated: Date
    public let deleted: Bool

    public init(id: String, lastUpdated: Date, deleted: Bool) {
        self.id = id
        self.lastUpdated = lastUpdated
        self.deleted = deleted
    }
}
