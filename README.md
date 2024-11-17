#  OfflineSync Swift Package

### How to install:


### What this Swift package can:

-
-
-



### How to use:

1. Define models that you want to store, they must fulfill next requirements:

  - Inherit Object from RealmSwift, conform to Synchable protocol from this package
  - Properties that will be stored in database must be marked with `@Persisted`
  - To avoid issues with serialization add CodingKeys with all properties

Synchable protocol:

```swift
public protocol Synchable: Object, Codable, Identifiable {
    static var entityName: String { get } // table name for the entity
    var lastUpdated: Date { get set }
    var deleted: Bool { get set }
    func copy(withNewId identifier: String) -> Self
    func encode(to encoder: Encoder) throws
}
```

Example:

```swift
import Foundation
import OfflineSync // add import of this package
import RealmSwift // add import of RealmSwift

class TodoTask: Object, Synchable {
    static let entityName = "todotasks"

    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var name: String
    @Persisted var dueDate: Date
    @Persisted var isDone: Bool
    @Persisted var lastUpdated: Date
    @Persisted var deleted: Bool = false

    func copy(withNewId identifier: String) -> Self {
        let newTask = TodoTask()
        newTask.id = identifier
        newTask.name = name
        newTask.dueDate = dueDate
        newTask.isDone = isDone
        newTask.lastUpdated = lastUpdated
        newTask.deleted = deleted

        guard let newTask = newTask as? Self else { fatalError("Unable to return Self from copy function") }
        return newTask
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(dueDate, forKey: .dueDate)
        try container.encode(isDone, forKey: .isDone)
        try container.encode(lastUpdated, forKey: .lastUpdated)
        try container.encode(deleted, forKey: .deleted)
    }

    enum CodingKeys: String, CodingKey {
        case name
        case dueDate = "due_date"
        case isDone = "is_done"
        case lastUpdated = "last_updated"
        case deleted
    }
}
```

Properties `last_updated` and `deleted` should be changed when modifying or deleting object

2. Add a class with a database of your choosing that conforms to RemoteDb protocol provided in this package

RemoteDb protocol:

```swift
import Foundation

public protocol RemoteDb {
    static var shared: RemoteDb { get }

    func saveEntityObject<T: Synchable>(
        _ entityObject: T,
        withID id: String?,
        completion: @escaping (Error?) -> Void)

    func fetchNewEntityObjects<T: Synchable>(
        for entityType: T.Type,
        lastSyncDate: Date?,
        completion: @escaping ([T]?, Error?) -> Void)

    func getIdsAndUpdateDates(
        entityName: String,
        completion: @escaping (Result<[Metadata], Error>) -> Void)

    func fetchUpdatedAndNewEntities<T: Synchable>(
        localMetadatas: [Metadata],
        entityType: T.Type,
        completion: @escaping (Result<[T], Error>) -> Void)
}
```

Example with FirebaseFirestore:

```swift
import FirebaseFirestore

class FirestoreService: RemoteDb {
    public static let shared: any RemoteDb = FirestoreService()
    private init() {}

    private let database = Firestore.firestore()

    func fetchNewEntityObjects<T: Synchable>(
        for entityType: T.Type,
        lastSyncDate: Date?,
        completion: @escaping ([T]?, Error?) -> Void
    ) {
        let todotasksCollection = database.collection(entityType.entityName)

        guard let lastSyncDate else {
            return fetchAllEntityObjects(for: entityType, completion: completion)
        }

        let query = todotasksCollection.whereField("last_updated", isGreaterThan: lastSyncDate)

        executeQuery(query, completion: completion)
    }

    func fetchAllEntityObjects<T: Synchable>(for entityType: T.Type, completion: @escaping ([T]?, Error?) -> Void) {
        let collection = database.collection(entityType.entityName)
        executeQuery(collection, completion: completion)
    }

    func saveEntityObject<T: Synchable>(_ entityObject: T, withID id: String?, completion: @escaping (Error?) -> Void) {
        do {
            //            log.info("object to save in remote db: \(entityObject)")
            let data = try Firestore.Encoder().encode(entityObject)
            //            log.info("data: \(data)")

            if let id, id != "" {
                log.info("id is not nil, id = '\(id)'")
                database.collection(T.entityName).document(id).setData(data, merge: true) { error in
                    completion(error)
                }
            } else {
                log.info("id is nil or empty")
                database.collection(T.entityName).addDocument(data: data) { error in
                    completion(error)
                }
            }
        } catch {
            completion(error)
        }
    }

    private func executeQuery<T: Synchable>(_ query: Query, completion: @escaping ([T]?, Error?) -> Void) {
        query.getDocuments { snapshot, error in
            if let error {
                completion(nil, error)
                return
            }

            guard let documents = snapshot?.documents else {
                completion([], nil)
                return
            }

            let objects: [T] = documents.compactMap { doc in
                guard let fetched = try? doc.data(as: T.self) else { return nil }
                return fetched.copy(withNewId: doc.documentID)
            }

            completion(objects, nil)
        }
    }

    // MARK: - New methods

    /// Fetches remote entities with new IDs and those with updated timestamps.
    func fetchUpdatedAndNewEntities<T: Synchable>(
        localMetadatas: [Metadata],
        entityType: T.Type,
        completion: @escaping (Result<[T], Error>) -> Void
    ) {
        let collectionRef = database.collection(entityType.entityName)

        collectionRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            var entitiesToSync: [T] = []

            for document in documents {
                do {
                    let deserialized = try document.data(as: T.self)
                    let remoteEntity = deserialized.copy(withNewId: document.documentID)

                    if let metadataForLocalObj = localMetadatas.filter(
                        { $0.id == document.documentID }
                    ).first {
                        if metadataForLocalObj.deleted {
                            /* do nothing, object is already deleted */
                        } else if metadataForLocalObj.lastUpdated < remoteEntity.lastUpdated {
                            // Entity is updated
                            entitiesToSync.append(remoteEntity)
                        }
                    } else {
                        // Entity is new
                        entitiesToSync.append(remoteEntity)
                    }

                } catch {
                    print("Failed to decode Firestore document \(document.documentID): \(error)")
                }
            }

            completion(.success(entitiesToSync))
        }
    }

    func getIdsAndUpdateDates(
        entityName: String,
        completion: @escaping (Result<[Metadata], Error>) -> Void
    ) {
        let collectionRef = database.collection(entityName)

        collectionRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            let remoteEntities: [Metadata] = documents.compactMap { document in
                guard let lastUpdatedTimestamp = document.data()["last_updated"] as? Timestamp,
                      let deleted = document.data()["deleted"] as? Bool
                else { return nil }
                let lastUpdated = lastUpdatedTimestamp.dateValue()
                return Metadata(id: document.documentID, lastUpdated: lastUpdated, deleted: deleted)
            }

            completion(.success(remoteEntities))
        }
    }
}
```

- Create a class where all sync configs will be created. 

Example:

```swift
import Foundation

class SyncingService {
    public static let shared = SyncingService()
    var syncTodoTaskService: SyncService<TodoTask>?

    private init() {
        do {
            let todotaskConfig = try SingleEntityConfig(
                syncToServerFreqActive: TimeInterval(10 * 60),
                syncToServerFreqBackground: TimeInterval(15 * 60),
                syncFromServerFreqActive: TimeInterval(10 * 60),
                syncFromServerFreqBackground: TimeInterval(15 * 60),
                deletionFreqBackground: TimeInterval(15 * 60),
                maxAmountOfSavedObjects: 6)

            syncTodoTaskService = SyncService(
                for: TodoTask.self, config: todotaskConfig, remoteDb: FirestoreService.shared)

        } catch {
            log.error("Unable to create SingleEntityConfig: \(error)")
        }
    }

    public func registerBgTasks() {
        syncTodoTaskService?.registerBgTasks()
    }

    public func scheduleBgTasks() {
        syncTodoTaskService?.scheduleBgTasks()
    }
}
```

3. In `AppDelegate` in `didFinishLaunchingWithOptions` register background tasks for entities (here is used methods manually defined below in SyncingService, you can also just call `syncTodoTaskService.registerBgTasks()` where `syncTodoTaskService` is `SyncService`)

```swift
let realmService = RealmService() // TODO: maybe remove

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions:
                        [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        SyncingService.shared.registerBgTasks()
        return true
    }
}
```

4. Schedule background tasks for each entity when entering background mode (here is used methods manually defined below in SyncingService, you can also just call `syncTodoTaskService.scheduleBgTasks()` where `syncTodoTaskService` is `SyncService`)

Example:

```swift
@main
struct OfflineDataSyncProjectApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
                    .onReceive(
                        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification
                        )) { _ in
                        SyncingStuffInProject.shared.syncTodoTaskService?.scheduleBgTasks()
                    }
            }
        }
    }
}
```