import Foundation

/// State of one job as shown in its progress HUD (spec mockup 07).
public enum JobState: Equatable {
    case queued
    case running
    case succeeded([URL])
    case failed(message: String, details: String)
    case cancelled
}

/// Passed to job bodies: progress reporting, cancellation, and a place to register cleanup.
public final class JobContext: @unchecked Sendable {
    private let lock = NSLock()
    private var _cancelled = false
    private var cancelHandlers: [() -> Void] = []
    let onProgress: (Double, String?) -> Void

    init(onProgress: @escaping (Double, String?) -> Void) { self.onProgress = onProgress }

    public var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return _cancelled }

    /// Reports overall progress 0…1 and optionally the item currently being processed.
    public func report(_ fraction: Double, item: String? = nil) {
        onProgress(min(1, max(0, fraction)), item)
    }

    /// Runs `handler` immediately if already cancelled, otherwise when cancel() happens (e.g. terminate ffmpeg).
    public func onCancel(_ handler: @escaping () -> Void) {
        lock.lock()
        if _cancelled { lock.unlock(); handler(); return }
        cancelHandlers.append(handler)
        lock.unlock()
    }

    public func checkCancelled() throws {
        if isCancelled { throw JobCancelled() }
    }

    func cancel() {
        lock.lock()
        guard !_cancelled else { lock.unlock(); return }
        _cancelled = true
        let handlers = cancelHandlers
        cancelHandlers = []
        lock.unlock()
        handlers.forEach { $0() }
    }
}

public struct JobCancelled: Error {}

/// A failure with a plain-language message plus an engine log for "Details" (spec §4.3 "Errors").
public struct JobFailure: Error, LocalizedError {
    public let message: String
    public let details: String
    public init(_ message: String, details: String = "") { self.message = message; self.details = details }
    public var errorDescription: String? { message }
}

public final class Job: Identifiable, @unchecked Sendable {
    public let id = UUID()
    public let title: String
    public let subject: String
    public let itemCount: Int
    public let created = Date()
    public internal(set) var state: JobState = .queued
    public internal(set) var progress: Double = 0
    public internal(set) var currentItem: String?
    let body: (JobContext) async throws -> [URL]
    let context: JobContext
    weak var queue: JobQueue?

    init(title: String, subject: String, itemCount: Int, body: @escaping (JobContext) async throws -> [URL], onProgress: @escaping (Double, String?) -> Void) {
        self.title = title
        self.subject = subject
        self.itemCount = itemCount
        self.body = body
        self.context = JobContext(onProgress: onProgress)
    }

    public func cancel() { queue?.cancel(self) }
}

/// FIFO queue, N jobs in parallel (default 2, spec §4.3 "Concurrency"), each cancellable.
/// Observers are called on the main queue.
public final class JobQueue: @unchecked Sendable {
    public static let shared = JobQueue()

    public var maxConcurrent: Int {
        didSet { schedule() }
    }
    public var onChange: ((Job) -> Void)?

    private let lock = NSLock()
    private var pending: [Job] = []
    private var running: Set<UUID> = []
    public private(set) var all: [Job] = []

    public init(maxConcurrent: Int = 2) { self.maxConcurrent = max(1, maxConcurrent) }

    @discardableResult
    public func enqueue(title: String, subject: String, itemCount: Int = 1, body: @escaping (JobContext) async throws -> [URL]) -> Job {
        var jobRef: Job?
        let job = Job(title: title, subject: subject, itemCount: itemCount, body: body) { [weak self] fraction, item in
            guard let job = jobRef else { return }
            job.progress = fraction
            if let item = item { job.currentItem = item }
            self?.notify(job)
        }
        jobRef = job
        job.queue = self
        lock.lock()
        pending.append(job)
        all.append(job)
        lock.unlock()
        notify(job)
        schedule()
        return job
    }

    func cancel(_ job: Job) {
        lock.lock()
        if let i = pending.firstIndex(where: { $0.id == job.id }) {
            pending.remove(at: i)
            lock.unlock()
            job.state = .cancelled
            notify(job)
            return
        }
        lock.unlock()
        job.context.cancel()
    }

    private func schedule() {
        lock.lock()
        var toStart: [Job] = []
        while running.count < maxConcurrent, !pending.isEmpty {
            let j = pending.removeFirst()
            running.insert(j.id)
            toStart.append(j)
        }
        lock.unlock()
        for job in toStart { start(job) }
    }

    private func start(_ job: Job) {
        job.state = .running
        notify(job)
        Task.detached { [weak self] in
            let result: JobState
            do {
                try job.context.checkCancelled()
                let urls = try await job.body(job.context)
                result = job.context.isCancelled ? .cancelled : .succeeded(urls)
            } catch is JobCancelled {
                result = .cancelled
            } catch let f as JobFailure {
                result = job.context.isCancelled ? .cancelled : .failed(message: f.message, details: f.details)
            } catch {
                result = job.context.isCancelled ? .cancelled : .failed(message: error.localizedDescription, details: String(describing: error))
            }
            job.state = result
            if case .succeeded = result { job.progress = 1 }
            guard let self = self else { return }
            self.lock.lock()
            self.running.remove(job.id)
            self.lock.unlock()
            self.notify(job)
            self.schedule()
        }
    }

    private func notify(_ job: Job) {
        let cb = onChange
        DispatchQueue.main.async { cb?(job) }
    }
}
