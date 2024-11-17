//
//  SingleEntityConfig.swift
//  OfflineDataSyncProject
//
//  Created by Соня Буділова on 17.11.2024.
//

import Foundation

public struct SingleEntityConfig {
    public let syncRemoteFreqActive: TimeInterval?
    public let syncRemoteFreqBackground: TimeInterval?
    public let syncLocalFreqActive: TimeInterval?
    public let syncLocalFreqBackground: TimeInterval?
    public let deletionFreqBackground: TimeInterval?
    public let maxAmountOfSavedObjects: Int?

    private static let minimumFrequencyActive: TimeInterval = 5
    private static let minimumFrequencyBg: TimeInterval = 15 * 60
    private static let minimumAmount: Int = 5
    public static var allowNonRecommendedValues: Bool = false

    enum ConfigError: Error {
        case err(String)
    }

    public init(
        syncToServerFreqActive: TimeInterval? = nil,
        syncToServerFreqBackground: TimeInterval? = nil,
        syncFromServerFreqActive: TimeInterval? = nil,
        syncFromServerFreqBackground: TimeInterval? = nil,
        deletionFreqBackground: TimeInterval? = nil,
        maxAmountOfSavedObjects: Int? = nil
    ) throws {
        let invalidProperties = [
            Self.validateProperty("syncToServerFreqActive", value: syncToServerFreqActive),
            Self.validateProperty("syncToServerFreqBackground", value: syncToServerFreqBackground),
            Self.validateProperty("syncFromServerFreqActive", value: syncFromServerFreqActive),
            Self.validateProperty("syncFromServerFreqBackground", value: syncFromServerFreqBackground),
            Self.validateProperty("deletionFreqBackground", value: deletionFreqBackground),
            Self.validateProperty("maxAmountOfSavedObjects",
                                  value: maxAmountOfSavedObjects,
                                  validator: Self.isObjectAmountValid)
        ].compactMap { $0 }

        if !invalidProperties.isEmpty {
            throw ConfigError.err("Invalid properties: \(invalidProperties.joined(separator: ", "))")
        }

        self.syncRemoteFreqActive = syncToServerFreqActive
        self.syncRemoteFreqBackground = syncToServerFreqBackground
        self.syncLocalFreqActive = syncFromServerFreqActive
        self.syncLocalFreqBackground = syncFromServerFreqBackground
        self.deletionFreqBackground = deletionFreqBackground
        self.maxAmountOfSavedObjects = maxAmountOfSavedObjects
    }

    /// Helper function to validate a single property
    private static func validateProperty<T>(
        _ name: String,
        value: T?,
        validator: (T?, Bool) -> Bool = Self.isValidFrequency
    ) -> String? {
        let inBg = name.lowercased().contains("background")
        guard !validator(value, inBg) else { return nil }
        return name
    }

    /// Method to check if a frequency is valid
    private static func isValidFrequency(_ frequency: TimeInterval?, inBackgroundMode: Bool) -> Bool {
        guard let frequency else { return true }
        return frequency >= (inBackgroundMode ? minimumFrequencyBg : minimumFrequencyActive)
    }

    /// Method to check if a frequency is valid
    private static func isObjectAmountValid(_ amount: Int?, inBackgroundMode: Bool) -> Bool {
        guard let amount else { return true }
        return amount >= minimumAmount
    }
}
