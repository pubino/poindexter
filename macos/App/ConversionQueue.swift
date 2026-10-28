import Foundation
import Observation
import PoindexterCore

enum Preferences {
    static let dpi = "dpi"
    static let jpeg = "jpeg"
    static let collapseOverlays = "collapseOverlays"
    static let notes = "notes"

    static var options: ConversionOptions {
        let d = UserDefaults.standard
        let dpi = d.object(forKey: Self.dpi) as? Int ?? 220
        return ConversionOptions(
            dpi: ConversionOptions.dpiRange.contains(dpi) ? dpi : 220,
            format: d.bool(forKey: jpeg) ? .jpeg : .png,
            notes: d.object(forKey: notes) as? Bool ?? true,
            collapseOverlays: d.bool(forKey: collapseOverlays))
    }
}

struct Job: Identifiable {
    enum State {
        case queued
        case converting(done: Int, total: Int)
        case finished(URL, slides: Int)
        case failed(String)
    }

    let id = UUID()
    let source: URL
    var state: State = .queued
}

/// Converts PDFs one at a time off the main thread, publishing progress for the UI.
@MainActor @Observable
final class ConversionQueue {
    private(set) var jobs: [Job] = []
    private var running = false

    func add(_ urls: [URL]) {
        for url in urls {
            if url.pathExtension.lowercased() == "pdf" {
                jobs.append(Job(source: url))
            } else {
                jobs.append(Job(source: url, state: .failed("Not a PDF file")))
            }
        }
        startIfIdle()
    }

    func clearFinished() {
        jobs.removeAll {
            switch $0.state {
            case .finished, .failed: true
            default: false
            }
        }
    }

    private func startIfIdle() {
        guard !running, let index = jobs.firstIndex(where: { if case .queued = $0.state { true } else { false } })
        else { return }
        running = true
        let id = jobs[index].id
        let source = jobs[index].source
        let options = Preferences.options
        jobs[index].state = .converting(done: 0, total: 0)

        Task.detached(priority: .userInitiated) {
            let state: Job.State
            do {
                let output = OutputNaming.uniquePPTX(for: source)
                let result = try Converter.convert(source, to: output, options: options) { done, total in
                    Task { @MainActor [weak self] in self?.update(id, .converting(done: done, total: total)) }
                }
                state = .finished(result.output, slides: result.slides)
            } catch {
                state = .failed(error.localizedDescription)
            }
            await MainActor.run { [weak self] in
                self?.update(id, state)
                self?.running = false
                self?.startIfIdle()
            }
        }
    }

    private func update(_ id: UUID, _ state: Job.State) {
        guard let i = jobs.firstIndex(where: { $0.id == id }) else { return }
        // A late progress update must not overwrite the final state.
        if case .converting = state, case .finished = jobs[i].state { return }
        if case .converting = state, case .failed = jobs[i].state { return }
        jobs[i].state = state
    }
}
