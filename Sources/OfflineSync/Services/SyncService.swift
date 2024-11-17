//
//  SyncService.swift
//  OfflineDataSyncProject
//
//  Created by Соня Буділова on 17.11.2024.
//

import Foundation
import RealmSwift

/// A class responsible for synchronizing local and remote data for a specific entity type. It handles both manual and automatic synchronization
/// (via timers and background tasks) and allows configuration of sync intervals, data retention, and background sync behavior.
///
/// The class is designed to synchronize entities that conform to the `Synchable` protocol and store data in both local and remote databases.
///
/// - Note: The `SyncService` class can synchronize data locally (from remote to local) and remotely (from local to remote), based on configured intervals and manual triggers.
public class SyncService<T: Synchable & Object> {
    /// The type of the entity being synchronized.
    private let entityType: T.Type

    /// The configuration object that defines sync intervals, data retention, and other sync-related properties.
    private var config: SingleEntityConfig

    /// The remote database used for syncing data.
    private let remoteDb: RemoteDb

    /// The timer responsible for syncing local data at the specified interval.
    private var timerForSyncLocal: Timer?

    /// The timer responsible for syncing remote data at the specified interval.
    private var timerForSyncRemote: Timer?

    /// Flag to ensure setup is performed only once.
    private var doneSetup = false

    /// The background sync service responsible for scheduling background tasks.
    private var bgSyncService: BackgroundSync<T>

    /// Initializes a new `SyncService` instance for a specific entity type with the given configuration and remote database.
    ///
    /// - Parameters:
    ///   - entityType: The type of the entity to synchronize (must conform to `Synchable` and `Object`).
    ///   - config: The configuration object specifying sync frequencies and other parameters.
    ///   - remoteDb: The remote database object used to sync data.
    ///
    /// - Note: The initial configuration can be updated later using the `save(config:)` method.
    public init(for entityType: T.Type, config: SingleEntityConfig, remoteDb: RemoteDb) {
        self.entityType = entityType
        self.remoteDb = remoteDb
        self.config = config
        self.bgSyncService = BackgroundSync(for: entityType.self, config: config, remoteDb: remoteDb)
        updateTimers(for: entityType.entityName, old: nil, new: config)
    }

    /// Registers background tasks for synchronization (local, remote, and data cleaning).
    ///
    /// This method configures the background sync tasks using the specified configuration.
    public func registerBgTasks() {
        bgSyncService.registerBackgroundTasks(config: config)
    }

    /// Updates the sync configuration of the service.
    ///
    /// - Parameters:
    ///   - config: The new configuration to be applied.
    ///
    /// - Note: This method will restart the sync timers based on the new configuration, but certain background settings can only be set once during setup.
    public func save(config: SingleEntityConfig) {
        let oldConfig: SingleEntityConfig = self.config
        self.config = config
        updateTimers(for: entityType.entityName, old: oldConfig, new: config)
    }

    // MARK: - Synchronization Methods

    /// Syncs local data by fetching updates from the remote database.
    ///
    /// This method creates and executes operations that synchronize local data with the remote database.
    /// It uses an operation queue to manage sync tasks sequentially.
    public func syncLocal() {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        let operations = Operations.getOperationsToSyncLocal(for: entityType, remoteDb: remoteDb)
        let lastOperation = operations.last!

        lastOperation.completionBlock = {
            Logger.shared.log.info("local sync operations completed? \(!lastOperation.isCancelled)")
        }

        queue.addOperations(operations, waitUntilFinished: false)
    }

    /// Syncs remote data by sending updates from the local database to the remote database.
    ///
    /// This method creates and executes operations that synchronize remote data with the local database.
    /// It uses an operation queue to manage sync tasks sequentially.
    public func syncRemote() {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        let operations = Operations.getOperationsToSyncRemote(for: entityType, remoteDb: remoteDb)
        let lastOperation = operations.last!

        lastOperation.completionBlock = {
            Logger.shared.log.info("remote sync operations completed? \(!lastOperation.isCancelled)")
        }

        queue.addOperations(operations, waitUntilFinished: false)
    }

    // MARK: - Timer Management

    /// Updates the timers for syncing based on the new configuration.
    ///
    /// - Parameters:
    ///   - entityName: The name of the entity being synchronized.
    ///   - old: The old configuration (used for comparison).
    ///   - new: The new configuration to apply.
    ///
    /// This method ensures that timers are restarted when sync frequencies change. It also logs a warning if certain background settings are modified after the initial setup.
    private func updateTimers(for entityName: String, old: SingleEntityConfig?, new: SingleEntityConfig) {
        if old?.syncLocalFreqActive != new.syncLocalFreqActive {
            startTimerForSyncLocal(entityName: entityName, interval: new.syncLocalFreqActive)
        }

        if old?.syncRemoteFreqActive != new.syncRemoteFreqActive {
            startTimerForSyncRemote(entityName: entityName, interval: new.syncRemoteFreqActive)
        }

        if doneSetup {
            if old?.deletionFreqBackground != new.deletionFreqBackground ||
                old?.maxAmountOfSavedObjects != new.maxAmountOfSavedObjects ||
                old?.syncLocalFreqBackground != new.syncLocalFreqBackground ||
                old?.syncRemoteFreqBackground != new.syncRemoteFreqBackground
            {
                Logger.shared.log.warning("Changing of background values in SingleEntityConfig has no effect, " +
                    "you can assign values only once during SyncService setup")
            }
        } else {
            doneSetup = true
        }
    }

    /// Starts a timer to sync local data at the specified interval.
    ///
    /// - Parameters:
    ///   - entityName: The name of the entity being synchronized.
    ///   - interval: The interval (in seconds) at which local sync should occur.
    private func startTimerForSyncLocal(entityName: String, interval: TimeInterval?) {
        timerForSyncLocal?.invalidate()

        guard let interval else { stopTimer(&timerForSyncLocal); return }
        timerForSyncLocal = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Logger.shared.log.verbose("sync local should be called")
            self?.syncLocal()
        }
    }

    /// Starts a timer to sync remote data at the specified interval.
    ///
    /// - Parameters:
    ///   - entityName: The name of the entity being synchronized.
    ///   - interval: The interval (in seconds) at which remote sync should occur.
    private func startTimerForSyncRemote(entityName: String, interval: TimeInterval?) {
        timerForSyncRemote?.invalidate()

        guard let interval else { stopTimer(&timerForSyncRemote); return }
        timerForSyncRemote = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Logger.shared.log.verbose("sync remote should be called")
            self?.syncRemote()
        }
    }

    /// Stops the specified timer.
    ///
    /// - Parameter timer: The timer to stop.
    private func stopTimer(_ timer: inout Timer?) {
        timer?.invalidate()
        timer = nil
    }

    /// Stops both the local and remote sync timers.
    private func stopAllTimers() {
        stopTimer(&timerForSyncLocal)
        stopTimer(&timerForSyncRemote)
    }

    // MARK: - Background Tasks

    /// Schedules background tasks for synchronization (local, remote) and data cleaning.
    ///
    /// This method configures and schedules background tasks for syncing data both locally and remotely, as well as cleaning up old or unnecessary data in the database.
    public func scheduleBgTasks() {
        bgSyncService.scheduleSyncLocal()
        bgSyncService.scheduleSyncRemote()
        bgSyncService.scheduleDbCleaning()
    }
}
