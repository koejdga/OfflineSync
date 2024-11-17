//
//  SyncService.swift
//  OfflineDataSyncProject
//
//  Created by Соня Буділова on 17.11.2024.
//

import Foundation
import RealmSwift

public class SyncService<T: Synchable & Object> {
    private let entityType: T.Type
    private var config: SingleEntityConfig
    private let remoteDb: RemoteDb
    private var timerForSyncLocal: Timer?
    private var timerForSyncRemote: Timer?
    private var doneSetup = false
    private var bgSyncService: BackgroundSync<T>

    public init(for entityType: T.Type, config: SingleEntityConfig, remoteDb: RemoteDb) {
        self.entityType = entityType
        self.remoteDb = remoteDb
        self.config = config
        self.bgSyncService = BackgroundSync(for: entityType.self, config: config, remoteDb: remoteDb)
        updateTimers(for: entityType.entityName, old: nil, new: config)
    }

    public func registerBgTasks() {
        bgSyncService.registerBackgroundTasks(config: config)
    }

    public func save(config: SingleEntityConfig) {
        let oldConfig: SingleEntityConfig = self.config
        self.config = config
        updateTimers(for: entityType.entityName, old: oldConfig, new: config)
    }

    // MARK: - Synching Methods

    /// getUpdatesFromRemoteDb
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

    /// sendUpdatesFromLocalDb
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

    // MARK: - Timer Methods

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
                Logger.shared.log.warning("Changing of background values in SignleEntityConfig has no effect, " +
                    "you can assign values only once during SyncService setup")
            }
        } else {
            doneSetup = true
        }
    }

    private func startTimerForSyncLocal(entityName: String, interval: TimeInterval?) {
        timerForSyncLocal?.invalidate()

        guard let interval else { stopTimer(&timerForSyncLocal); return }
        timerForSyncLocal = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Logger.shared.log.verbose("sync local should be called")
            self?.syncLocal()
        }
    }

    private func startTimerForSyncRemote(entityName: String, interval: TimeInterval?) {
        timerForSyncRemote?.invalidate()

        guard let interval else { stopTimer(&timerForSyncRemote); return }
        timerForSyncRemote = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Logger.shared.log.verbose("sync remote should be called")
            self?.syncRemote()
        }
    }

    private func stopTimer(_ timer: inout Timer?) {
        timer?.invalidate()
        timer = nil
    }

    private func stopAllTimers() {
        stopTimer(&timerForSyncLocal)
        stopTimer(&timerForSyncRemote)
    }

    // MARK: - BG

    public func scheduleBgTasks() {
        bgSyncService.scheduleSyncLocal()
        bgSyncService.scheduleSyncRemote()
        bgSyncService.scheduleDbCleaning()
    }
}
