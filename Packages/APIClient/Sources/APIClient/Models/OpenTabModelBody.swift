import Foundation

extension OpenTabModel {
    public var multipartParts: [MultipartPart] {
        get {
            guard let d = multipartPartsJSON else { return [MultipartPart()] }
            return (try? JSONDecoder().decode([MultipartPart].self, from: d)) ?? [MultipartPart()]
        }
        set { multipartPartsJSON = try? JSONEncoder().encode(newValue) }
    }

    /// Restores a persisted `.binary(Data)` body by writing the bytes to a temp file the editor can reference.
    public func restoreBinaryBody(_ data: Data) {
        bodyType = BodyType.binary.rawValue
        binaryMimeType = ""
        do {
            binaryFilePath = try BinaryBodyFile.writeTemporary(data)
        } catch {
            binaryFilePath = ""
            lastErrorMessage = "Could not restore binary body: \(error.localizedDescription)"
        }
    }
}
