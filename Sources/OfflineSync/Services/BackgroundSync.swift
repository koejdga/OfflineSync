//
//  BackgroundSync.swift
//  OfflineDataSyncProject
//
//  Created by Соня Буділова on 17.11.2024.
//

import BackgroundTasks
import Foundation
import RealmSwift

/// The `BackgroundSync` class manages the background tasks for syncing data locally and remotely, as well as cleaning the local database.
/// It handles tasks like database cleaning, remote synchronization, and local synchronization with specific intervals and configurations.
public class BackgroundSync<T: Synchable & Object> {
    private let entityType: T.Type
    private let remoteDb: RemoteDb
    private let config: SingleEntityConfig

    /// The identifier for the background task related to database cleaning.
    public var dbCleaningTaskId: String {
        "db_cleaning_" + entityType.entityName
    }

    /// The identifier for the background task related to synchronizing data from the remote database.
    public var syncRemoteTaskId: String {
        "sync_remote_" + entityType.entityName
    }

    /// The identifier for the background task related to synchronizing data to the local database.
    public var syncLocalTaskId: String {
        "sync_local_" + entityType.entityName
    }

    /// Initializes a `BackgroundSync` instance with the provided configuration, entity type, and remote database.
    ///
    /// - Parameters:
    ///   - entityType: The type of the entity that will be synchronized.
    ///   - config: The configuration for the entity's sync settings.
    ///   - remoteDb: The remote database used for syncing.
    init(for entityType: T.Type, config: SingleEntityConfig, remoteDb: RemoteDb) {
        self.entityType = entityType
        self.remoteDb = remoteDb
        self.config = config
    }

    /// Registers background tasks for syncing data locally, syncing data remotely, and cleaning the local database.
    ///
    /// - Parameters:
    ///   - config: The configuration for the entity's sync settings, including frequency and maximum saved objects.
    func registerBackgroundTasks(config: SingleEntityConfig) {
        Logger.shared.log.info("registering background tasks")
        registerSyncRemote(frequency: config.syncRemoteFreqBackground)
        registerSyncLocal(frequency: config.syncLocalFreqBackground)
        registerDbCleaning(frequency: config.deletionFreqBackground, maxEntries: config.maxAmountOfSavedObjects)
        Logger.shared.log.info("registered background tasks")
    }

    /// Registers the background task for cleaning the local database.
    ///
    /// - Parameters:
    ///   - frequency: The frequency at which the database cleaning task should occur.
    ///   - maxEntries: The maximum number of entries that should be kept in the local database.
    private func registerDbCleaning(frequency: TimeInterval?, maxEntries: Int?) {
        Logger.shared.log.info("registering db cleaning")
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: dbCleaningTaskId, using: nil)
        { task in
            if frequency != nil || maxEntries != nil {
                guard let task = task as? BGProcessingTask else { return }
                self.handleDatabaseCleaning(
                    task: task,
                    deletionInterval: frequency,
                    maxEntries: maxEntries)
            }
        }
        Logger.shared.log.info("registered db cleaning")
    }

    /// Registers the background task for syncing data from the remote database.
    ///
    /// - Parameters:
    ///   - frequency: The frequency at which the remote sync task should occur.
    private func registerSyncRemote(frequency: TimeInterval?) {
        Logger.shared.log.info("registering sync remote")
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: dbCleaningTaskId, using: nil)
        { task in
            if frequency != nil {
                guard let task = task as? BGAppRefreshTask else { return }
                self.handleSyncRemote(task: task)
            }
        }
        Logger.shared.log.info("registered sync remote")
    }

    /// Registers the background task for syncing data to the local database.
    ///
    /// - Parameters:
    ///   - frequency: The frequency at which the local sync task should occur.
    private func registerSyncLocal(frequency: TimeInterval?) {
        Logger.shared.log.info("registering sync local")
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: dbCleaningTaskId, using: nil)
        { task in
            if frequency != nil {
                guard let task = task as? BGAppRefreshTask else { return }
                self.handleSyncLocal(task: task)
            }
        }
        Logger.shared.log.info("registered sync local")
    }

    /// Handles the local synchronization task, executing operations to sync data from the local database to the remote one.
    ///
    /// - Parameter task: The background app refresh task.
    private func handleSyncLocal(task: BGAppRefreshTask) {
        scheduleSyncLocal()

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        let operations = Operations.getOperationsToSyncLocal(for: entityType, remoteDb: remoteDb)
        let lastOperation = operations.last!

        task.expirationHandler = {
            queue.cancelAllOperations()
        }

        lastOperation.completionBlock = {
            task.setTaskCompleted(success: !lastOperation.isCancelled)
        }

        queue.addOperations(operations, waitUntilFinished: false)
    }

    /// Handles the remote synchronization task, executing operations to sync data from the remote database to the local one.
    ///
    /// - Parameter task: The background app refresh task.
    private func handleSyncRemote(task: BGAppRefreshTask) {
        scheduleSyncRemote()

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        let operations = Operations.getOperationsToSyncRemote(for: entityType, remoteDb: remoteDb)
        let lastOperation = operations.last!

        task.expirationHandler = {
            queue.cancelAllOperations()
        }

        lastOperation.completionBlock = {
            task.setTaskCompleted(success: !lastOperation.isCancelled)
        }

        queue.addOperations(operations, waitUntilFinished: false)
    }

    /// Handles the database cleaning task, which deletes data based on the specified conditions such as the deletion interval and the maximum number of saved entries.
    ///
    /// - Parameters:
    ///   - task: The background processing task.
    ///   - deletionInterval: The time interval for deleting old entries.
    ///   - maxEntries: The maximum number of entries that should be retained in the local database.
    private func handleDatabaseCleaning(task: BGProcessingTask, deletionInterval: TimeInterval?, maxEntries: Int?) {
        Logger.shared.log.info("handle database cleaning")
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        var predicate: NSPredicate?
        if let deletionInterval {
            predicate = NSPredicate(format: "lastUpdated < %@", NSDate(timeIntervalSinceNow: deletionInterval))
        }
        let cleanDatabaseOperation = CleanDatabaseOperation(
            for: entityType, predicate: predicate, maxEntries: maxEntries)

        task.expirationHandler = {
            queue.cancelAllOperations()
        }

        cleanDatabaseOperation.completionBlock = {
            let success = !cleanDatabaseOperation.isCancelled
            task.setTaskCompleted(success: success)
        }

        queue.addOperation(cleanDatabaseOperation)
    }

    /// Schedules the database cleaning task based on the configured frequency and other parameters.
    public func scheduleDbCleaning() {
        Logger.shared.log.info("scheduleDatabaseCleaningIfNeeded started")
        let request = BGProcessingTaskRequest(identifier: dbCleaningTaskId)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false

        do {
            Logger.shared.log.info("scheduled database cleaning")
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule database cleaning: \(error)")
        }
    }

    /// Schedules the local synchronization task based on the configured frequency.
    public func scheduleSyncLocal() {
        guard let frequency = config.syncLocalFreqBackground else { return }
        let request = BGAppRefreshTaskRequest(identifier: syncLocalTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: frequency)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }

    /// Schedules the remote synchronization task based on the configured frequency.
    public func scheduleSyncRemote() {
        guard let frequency = config.syncLocalFreqBackground else { return }
        let request = BGAppRefreshTaskRequest(identifier: syncRemoteTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: frequency)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
}
