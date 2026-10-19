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
        let target = options.keepMetadata ? doc : try rebuilt(from: doc)
        guard target.write(to: output, withOptions: opts) else { throw JobFailure("macOS couldn't save the compressed PDF.") }
    }

    /// A new document containing copies of the pages only. Document-level metadata (Info dictionary and the XMP
    /// packet in the catalog) stays behind with the original.
    static func rebuilt(from doc: PDFDocument) throws -> PDFDocument {
        let fresh = PDFDocument()
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i)?.copy() as? PDFPage else { throw JobFailure("Morph couldn't read page \(i + 1).") }
            fresh.insert(page, at: fresh.pageCount)
        }
        fresh.documentAttributes = [:]
        return fresh
    }

    public static func removeMetadata(_ input: URL, output: URL) throws {
        guard let doc = PDFDocument(url: input) else { throw JobFailure("Morph couldn't open this PDF.") }
        if doc.isLocked { throw JobFailure("This PDF is password-protected.") }
        let fresh = try rebuilt(from: doc)
        guard fresh.pageCount == doc.pageCount, fresh.write(to: output) else { throw JobFailure("macOS couldn't save the PDF.") }
    }

    public static func readMetadata(_ url: URL) -> [(group: String, key: String, value: String)] {
        guard let doc = PDFDocument(url: url) else { return [] }
        var rows = (doc.documentAttributes ?? [:]).map { ("Document", "\($0.key)", "\($0.value)") }.sorted { $0.1 < $1.1 }
        rows.append(("File", "Pages", "\(doc.pageCount)"))
        return rows
    }
}
#endif
