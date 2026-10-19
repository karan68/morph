#if canImport(AppKit)
import AppKit
import SwiftUI
import Engines
import Capabilities
import Jobs
import A11y

/// Metadata window: shows what's embedded, grouped and searchable; "Remove All" saves a "No Metadata" copy.
struct MetadataView: View {
    let item: URL
    let done: (ToolOptions?) -> Void
    @State private var rows: [(group: String, key: String, value: String)] = []
    @State private var loaded = false
    @State private var query = ""

    var filtered: [(group: String, key: String, value: String)] {
        query.isEmpty ? rows : rows.filter { "\($0.group) \($0.key) \($0.value)".localizedCaseInsensitiveContains(query) }
    }
    var groups: [String] { Array(Set(filtered.map(\.group))).sorted { $0 == "File" ? true : $1 == "File" ? false : $0 < $1 } }
    var isImage: Bool { Formats.family(of: Formats.format(of: item) ?? "") == .image }

    var body: some View {
        ToolChrome(title: "Metadata", primary: "Remove All", primaryEnabled: loaded, onReset: nil, onCancel: { done(nil) }, onPrimary: { done(.none) }) {
            VStack(alignment: .leading, spacing: 12) {
                FileHeader(url: item, subtitle: loaded ? "\(rows.count) field\(rows.count == 1 ? "" : "s") found" : "Reading…")
                TextField("Search fields", text: $query).textFieldStyle(.roundedBorder).accessibilityLabel("Search metadata fields")
                List {
                    ForEach(groups, id: \.self) { g in
                        Section(g) {
                            ForEach(filtered.filter { $0.group == g }.indices, id: \.self) { i in
                                let r = filtered.filter { $0.group == g }[i]
                                HStack(alignment: .firstTextBaseline) {
                                    Text(r.key).foregroundColor(Color(Theme.ink2)).frame(width: 170, alignment: .leading).lineLimit(1)
                                    Text(r.value).textSelection(.enabled).lineLimit(3)
                                }
                                .font(.system(size: 12))
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
                .frame(height: 300)
                .overlay { if loaded && rows.isEmpty { Text("No metadata found.").foregroundColor(Color(Theme.ink3)) } }
                Text(isImage ? "Remove All also clears hidden camera and processing data. HDR and portrait effects may change. The original is never modified."
                             : "Remove All saves a copy without tags or chapters. The original is never modified.")
                    .foregroundColor(Color(Theme.ink3)).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 560)
        .task {
            rows = await Engine.readMetadata(item)
            loaded = true
            Announcer.say("\(rows.count) metadata fields.", priority: .low)
        }
    }
}
#endif
