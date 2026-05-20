@MainActor
final class PostSnapshotCache {
    static let shared = PostSnapshotCache()

    private var postsById: [String: LocalizedPostResponse] = [:]
    private var insertionOrder: [String] = []
    private let limit = 150

    private init() {}

    func post(id: String) -> LocalizedPostResponse? {
        postsById[id]
    }

    func store(_ post: LocalizedPostResponse) {
        let id = post.id
        if postsById[id] == nil {
            insertionOrder.append(id)
        }
        postsById[id] = post
        trimIfNeeded()
    }

    func store(contentsOf posts: [LocalizedPostResponse]) {
        posts.forEach(store)
    }

    private func trimIfNeeded() {
        while insertionOrder.count > limit {
            let id = insertionOrder.removeFirst()
            postsById[id] = nil
        }
    }
}
