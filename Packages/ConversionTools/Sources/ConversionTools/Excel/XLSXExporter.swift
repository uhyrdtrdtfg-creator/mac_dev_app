import Foundation

/// Generates a minimal but valid `.xlsx` (Office Open XML) workbook with no third-party
/// dependencies. Uses a hand-written ZIP container with STORED (uncompressed) entries.
public enum XLSXExporter {
    public static func build(columns: [String], rows: [[String]], sheetName: String = "Sheet1") -> Data {
        let sheet = worksheetXML(columns: columns, rows: rows)
        let files: [(name: String, data: Data)] = [
            ("[Content_Types].xml", Data(contentTypesXML.utf8)),
            ("_rels/.rels", Data(rootRelsXML.utf8)),
            ("xl/workbook.xml", Data(workbookXML(sheetName: sheetName).utf8)),
            ("xl/_rels/workbook.xml.rels", Data(workbookRelsXML.utf8)),
            ("xl/worksheets/sheet1.xml", Data(sheet.utf8)),
        ]
        return zip(files)
    }

    // MARK: - Worksheet

    private static func worksheetXML(columns: [String], rows: [[String]]) -> String {
        var sb = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>
        """
        sb += rowXML(cells: columns, rowIndex: 1)
        for (i, row) in rows.enumerated() {
            sb += rowXML(cells: row, rowIndex: i + 2)
        }
        sb += "</sheetData></worksheet>"
        return sb
    }

    private static func rowXML(cells: [String], rowIndex: Int) -> String {
        var sb = "<row r=\"\(rowIndex)\">"
        for (c, value) in cells.enumerated() {
            let ref = "\(columnLetter(c))\(rowIndex)"
            sb += cellXML(ref: ref, value: value)
        }
        sb += "</row>"
        return sb
    }

    private static func cellXML(ref: String, value: String) -> String {
        if value == "NULL" || value.isEmpty {
            return "<c r=\"\(ref)\"/>"
        }
        if isNumeric(value) {
            return "<c r=\"\(ref)\"><v>\(value)</v></c>"
        }
        return "<c r=\"\(ref)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(escapeXML(value))</t></is></c>"
    }

    /// 0-based column index → Excel column letters (A, B, …, Z, AA, …).
    public static func columnLetter(_ index: Int) -> String {
        var n = index
        var result = ""
        repeat {
            result = String(UnicodeScalar(UInt8(65 + n % 26))) + result
            n = n / 26 - 1
        } while n >= 0
        return result
    }

    private static func isNumeric(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        return s.range(of: "^-?(0|[1-9][0-9]*)(\\.[0-9]+)?$", options: .regularExpression) != nil
    }

    private static func escapeXML(_ s: String) -> String {
        var out = ""
        for scalar in s.unicodeScalars {
            switch scalar {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&apos;"
            default:
                // Strip control characters that are illegal in XML 1.0.
                if scalar.value < 0x20 && scalar != "\t" && scalar != "\n" && scalar != "\r" { continue }
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    // MARK: - Static OOXML parts

    private static let contentTypesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>
    """

    private static let rootRelsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>
    """

    private static func workbookXML(sheetName: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="\(escapeXML(sheetName))" sheetId="1" r:id="rId1"/></sheets></workbook>
        """
    }

    private static let workbookRelsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>
    """

    // MARK: - Minimal ZIP (STORED entries)

    private static func zip(_ files: [(name: String, data: Data)]) -> Data {
        var localData = Data()
        var central = Data()
        var offset = 0
        // Fixed DOS date 1980-01-01, time 00:00.
        let dosTime: UInt16 = 0
        let dosDate: UInt16 = 0x0021

        for file in files {
            let nameBytes = Array(file.name.utf8)
            let crc = crc32(file.data)
            let size = UInt32(file.data.count)

            // Local file header.
            var local = Data()
            local.append(le32(0x04034b50))
            local.append(le16(20))            // version needed
            local.append(le16(0))             // flags
            local.append(le16(0))             // method = stored
            local.append(le16(dosTime))
            local.append(le16(dosDate))
            local.append(le32(crc))
            local.append(le32(size))          // compressed size
            local.append(le32(size))          // uncompressed size
            local.append(le16(UInt16(nameBytes.count)))
            local.append(le16(0))             // extra length
            local.append(contentsOf: nameBytes)
            local.append(file.data)

            // Central directory record.
            var cd = Data()
            cd.append(le32(0x02014b50))
            cd.append(le16(20))               // version made by
            cd.append(le16(20))               // version needed
            cd.append(le16(0))                // flags
            cd.append(le16(0))                // method
            cd.append(le16(dosTime))
            cd.append(le16(dosDate))
            cd.append(le32(crc))
            cd.append(le32(size))
            cd.append(le32(size))
            cd.append(le16(UInt16(nameBytes.count)))
            cd.append(le16(0))                // extra
            cd.append(le16(0))                // comment
            cd.append(le16(0))                // disk number
            cd.append(le16(0))                // internal attrs
            cd.append(le32(0))                // external attrs
            cd.append(le32(UInt32(offset)))   // local header offset
            cd.append(contentsOf: nameBytes)

            localData.append(local)
            central.append(cd)
            offset += local.count
        }

        var result = localData
        let centralOffset = result.count
        result.append(central)

        // End of central directory.
        var eocd = Data()
        eocd.append(le32(0x06054b50))
        eocd.append(le16(0))                              // disk number
        eocd.append(le16(0))                              // disk with cd
        eocd.append(le16(UInt16(files.count)))           // entries on disk
        eocd.append(le16(UInt16(files.count)))           // total entries
        eocd.append(le32(UInt32(central.count)))         // size of central dir
        eocd.append(le32(UInt32(centralOffset)))         // offset of central dir
        eocd.append(le16(0))                             // comment length
        result.append(eocd)
        return result
    }

    private static func le16(_ v: UInt16) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
    private static func le32(_ v: UInt32) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }

    // MARK: - CRC32 (IEEE)

    private static let crcTable: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1) }
            return c
        }
    }()

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}
