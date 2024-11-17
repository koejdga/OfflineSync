//
//  SingleEntityConfig.swift
//  OfflineDataSyncProject
//
//  Created by Соня Буділова on 17.11.2024.
//

import Foundation

/// A struct that defines the configuration for syncing a single entity, including frequency settings for synchronization, deletion, and limits on the amount of data that can be saved.
///
/// This struct allows users to specify custom synchronization intervals for both active and background modes, along with deletion intervals and the maximum amount of objects to store locally. It ensures that all settings meet certain minimum thresholds unless explicitly allowed to deviate.
public struct SingleEntityConfig {
    /// The frequency (in seconds) at which data should be synchronized to the remote server when the app is active.
    public let syncRemoteFreqActive: TimeInterval?

    /// The frequency (in seconds) at which data should be synchronized to the remote server when the app is in the background.
    public let syncRemoteFreqBackground: TimeInterval?

    /// The frequency (in seconds) at which data should be synced from the remote server when the app is active.
    public let syncLocalFreqActive: TimeInterval?

    /// The frequency (in seconds) at which data should be synced from the remote server when the app is in the background.
    public let syncLocalFreqBackground: TimeInterval?

    /// The frequency (in seconds) at which deletion tasks should run in the background.
    public let deletionFreqBackground: TimeInterval?

    /// The maximum number of objects that can be saved locally.
    public let maxAmountOfSavedObjects: Int?

    // Minimum threshold values for validation
    private static let minimumFrequencyActive: TimeInterval = 5
    private static let minimumFrequencyBg: TimeInterval = 15 * 60
    private static let minimumAmount: Int = 5

    /// Flag that allows the use of non-recommended values.
    public static var allowNonRecommendedValues: Bool = false

    /// Enum to define possible configuration errors.
    enum ConfigError: Error {
        case err(String)
    }

    /// Initializes a new configuration for syncing a single entity.
    ///
    /// - Parameters:
    ///   - syncToServerFreqActive: Frequency for syncing data to the server when the app is active. Default is `nil`.
    ///   - syncToServerFreqBackground: Frequency for syncing data to the server when the app is in the background. Default is `nil`.
    ///   - syncFromServerFreqActive: Frequency for syncing data from the server when the app is active. Default is `nil`.
    ///   - syncFromServerFreqBackground: Frequency for syncing data from the server when the app is in the background. Default is `nil`.
    ///   - deletionFreqBackground: Frequency for running deletion tasks in the background. Default is `nil`.
    ///   - maxAmountOfSavedObjects: The maximum number of objects to be saved locally. Default is `nil`.
    ///
    /// - Throws: `ConfigError.err` if any of the provided settings do not meet the minimum required values or other validation rules.
    public init(
        syncToServerFreqActive: TimeInterval? = nil,
        syncToServerFreqBackground: TimeInterval? = nil,
        syncFromServerFreqActive: TimeInterval? = nil,
        syncFromServerFreqBackground: TimeInterval? = nil,
        deletionFreqBackground: TimeInterval? = nil,
        maxAmountOfSavedObjects: Int? = nil
    ) throws {
        // Validate properties and check for any invalid values
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

        // If there are any invalid properties, throw an error
        if !invalidProperties.isEmpty {
            throw ConfigError.err("Invalid properties: \(invalidProperties.joined(separator: ", "))")
        }

        // Set the properties based on the validated input
        self.syncRemoteFreqActive = syncToServerFreqActive
        self.syncRemoteFreqBackground = syncToServerFreqBackground
        self.syncLocalFreqActive = syncFromServerFreqActive
        self.syncLocalFreqBackground = syncFromServerFreqBackground
        self.deletionFreqBackground = deletionFreqBackground
        self.maxAmountOfSavedObjects = maxAmountOfSavedObjects
    }

    /// Helper function to validate a single property.
    ///
    /// - Parameters:
    ///   - name: The name of the property to validate.
    ///   - value: The value of the property to validate.
    ///   - validator: A closure that defines the validation logic. Default is the `isValidFrequency` method.
    /// - Returns: The name of the property if it's invalid, `nil` if it's valid.
    private static func validateProperty<T>(
        _ name: String,
        value: T?,
        validator: (T?, Bool) -> Bool = Self.isValidFrequency
    ) -> String? {
        let inBg = name.lowercased().contains("background")
        guard !validator(value, inBg) else { return nil }
        return name
    }

    /// Method to check if a frequency is valid based on its mode (active or background).
    ///
    /// - Parameters:
    ///   - frequency: The frequency value to validate.
    ///   - inBackgroundMode: A flag indicating whether the frequency is for background mode.
    /// - Returns: A boolean indicating if the frequency is valid.
    private static func isValidFrequency(_ frequency: TimeInterval?, inBackgroundMode: Bool) -> Bool {
        guard let frequency else { return true }
        return frequency >= (inBackgroundMode ? minimumFrequencyBg : minimumFrequencyActive)
    }

    /// Method to check if the number of saved objects is valid.
    ///
    /// - Parameters:
    ///   - amount: The number of saved objects to validate.
    ///   - inBackgroundMode: A flag indicating whether the validation is for background mode.
    /// - Returns: A boolean indicating if the number of objects is valid.
    private static func isObjectAmountValid(_ amount: Int?, inBackgroundMode: Bool) -> Bool {
        guard let amount else { return true }
        return amount >= minimumAmount
    }
}
