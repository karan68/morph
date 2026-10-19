#if canImport(PDFKit)
import Foundation
import PDFKit
import Jobs

/// PDF tools available in M1: Compress and Metadata (PDF conversions are M2/M3, spec §4.2).
public enum PDFTools {
    /// Balanced: re-save images as JPEG. Strong/Smallest: also downsample images for screen.
    /// Uses PDFKit write options that exist on macOS 13.4+ (verified in the SDK header).
    public static func compress(_ input: URL, options: CompressOptions, output: URL) throws {
        guard let doc = PDFDocument(url: input) else { throw JobFailure("Morph couldn't open this PDF.") }
        if doc.isLocked { throw JobFailure("This PDF is password-protected.") }
        guard #available(macOS 13.4, *) else {
            throw JobFailure("Compressing PDFs needs macOS 13.4 or later.")
        }
        var opts: [PDFDocumentWriteOption: Any] = [.saveImagesAsJPEGOption: true]
        if options.preset != .balanced || options.goal != .preset { opts[.optimizeImagesForScreenOption] = true }
        if !options.keepMetadata { doc.documentAttributes = [:] }
        guard doc.write(to: output, withOptions: opts) else { throw JobFailure("macOS couldn't save the compressed PDF.") }
    }

    public static func removeMetadata(_ input: URL, output: URL) throws {
        guard let doc = PDFDocument(url: input) else { throw JobFailure("Morph couldn't open this PDF.") }
        if doc.isLocked { throw JobFailure("This PDF is password-protected.") }
        doc.documentAttributes = [:]
        guard doc.write(to: output) else { throw JobFailure("macOS couldn't save the PDF.") }
    }

    public static func readMetadata(_ url: URL) -> [(group: String, key: String, value: String)] {
        guard let doc = PDFDocument(url: url) else { return [] }
        var rows = (doc.documentAttributes ?? [:]).map { ("Document", "\($0.key)", "\($0.value)") }.sorted { $0.1 < $1.1 }
        rows.append(("File", "Pages", "\(doc.pageCount)"))
        return rows
    }
}
#endif
