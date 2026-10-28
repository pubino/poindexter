import AppKit
import PoindexterCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    var queue: ConversionQueue
    @State private var targeted = false
    @State private var choosing = false

    var body: some View {
        VStack(spacing: 0) {
            dropZone
                .padding(16)
            if !queue.jobs.isEmpty {
                Divider()
                List(queue.jobs) { JobRow(job: $0) }
                    .listStyle(.inset)
                HStack {
                    Spacer()
                    Button("Clear Finished") { queue.clearFinished() }
                }
                .padding(12)
            }
        }
        .frame(minWidth: 440, minHeight: 300)
        .fileImporter(isPresented: $choosing, allowedContentTypes: [.pdf], allowsMultipleSelection: true) {
            if case .success(let urls) = $0 { queue.add(urls) }
        }
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
            Text("Drop PDF presentations here")
                .font(.title3.weight(.medium))
            Text("Each page becomes a slide in a PowerPoint file saved next to the PDF.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Choose PDFs…") { choosing = true }
                .keyboardShortcut("o")
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .foregroundStyle(targeted ? Color.accentColor : Color.secondary.opacity(0.5))
                .background(RoundedRectangle(cornerRadius: 14).fill(targeted ? Color.accentColor.opacity(0.08) : .clear))
        )
        .dropDestination(for: URL.self) { urls, _ in
            queue.add(urls)
            return !urls.isEmpty
        } isTargeted: { targeted = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Drop area for PDF files")
    }
}

struct JobRow: View {
    let job: Job

    var body: some View {
        HStack(spacing: 10) {
            icon.frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(job.source.lastPathComponent).lineLimit(1).truncationMode(.middle)
                detail.font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if case .finished(let url, _) = job.state {
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                Button("Open") { NSWorkspace.shared.open(url) }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var icon: some View {
        switch job.state {
        case .queued: Image(systemName: "clock").foregroundStyle(.secondary)
        case .converting: ProgressView().controlSize(.small)
        case .finished: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }

    @ViewBuilder private var detail: some View {
        switch job.state {
        case .queued: Text("Waiting…")
        case .converting(let done, let total):
            if total > 0 {
                ProgressView(value: Double(done), total: Double(total)) {
                    Text("Slide \(done) of \(total)")
                }
            } else {
                Text("Opening…")
            }
        case .finished(let url, let slides): Text("\(slides) slides → \(url.lastPathComponent)")
        case .failed(let message): Text(message)
        }
    }
}

struct SettingsView: View {
    @AppStorage(Settings.collapseOverlays) private var collapseOverlays = false
    @AppStorage(Settings.jpeg) private var jpeg = false
    @AppStorage(Settings.notes) private var notes = true
    @AppStorage(Settings.dpi) private var dpi = 220

    var body: some View {
        Form {
            Toggle("One slide per beamer frame (skip overlay build-up steps)", isOn: $collapseOverlays)
            Toggle("Copy slide text into speaker notes", isOn: $notes)
            Picker("Image format", selection: $jpeg) {
                Text("PNG — sharpest text").tag(false)
                Text("JPEG — smaller files").tag(true)
            }
            Picker("Resolution", selection: $dpi) {
                Text("Standard (150 dpi)").tag(150)
                Text("High (220 dpi)").tag(220)
                Text("Maximum (300 dpi)").tag(300)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding()
    }
}
