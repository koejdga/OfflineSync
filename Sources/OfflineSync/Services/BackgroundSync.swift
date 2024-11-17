//
//  BackgroundSync.swift
//  OfflineDataSyncProject
//
//  Created by Соня Буділова on 17.11.2024.
//

import BackgroundTasks
import Foundation
import RealmSwift

public class BackgroundSync<T: Synchable & Object> {
    private let entityType: T.Type
    private let remoteDb: RemoteDb
    private let config: SingleEntityConfig

    public var dbCleaningTaskId: String {
        "db_cleaning_" + entityType.entityName
    }

    public var syncRemoteTaskId: String {
        "sync_remote_" + entityType.entityName
    }

    public var syncLocalTaskId: String {
        "sync_local_" + entityType.entityName
    }

    init(for entityType: T.Type, config: SingleEntityConfig, remoteDb: RemoteDb) {
        self.entityType = entityType
        self.remoteDb = remoteDb
        self.config = config
    }

    func registerBackgroundTasks(config: SingleEntityConfig) {
        Logger.shared.log.info("registering background tasks")
        registerSyncRemote(frequency: config.syncRemoteFreqBackground)
        registerSyncLocal(frequency: config.syncLocalFreqBackground)
        registerDbCleaning(frequency: config.deletionFreqBackground, maxEntries: config.maxAmountOfSavedObjects)
        Logger.shared.log.info("registered background tasks")
    }

    // maybe create some struct with frequency and max objects
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
