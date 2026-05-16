import Foundation

/// Reads a UTF-8 text file from inside the app sandbox.
///
/// CLI agents get `read_file` for free against the whole filesystem. On iOS the
/// app sandbox is the only thing the process can see, so this tool restricts
/// access to Documents/ and Caches/ — the two directories user content normally
/// lives in. Paths are resolved relative to the chosen root and any traversal
/// outside it (`..`, absolute paths, symlinks pointing out) is rejected.
public struct ReadSandboxFileTool: ToolProtocol {
    public let name = "read_sandbox_file"
    public let description = """
        Reads a UTF-8 text file from the app sandbox. \
        `root` is either "documents" (default) or "caches". \
        `path` is relative to that root, e.g. "notes/today.md". \
        Returns the file contents, or an error if the file is missing, \
        binary, larger than maxBytes, or resolves outside the chosen root.
        """

    public var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "Relative path inside the chosen root.",
                ],
                "root": [
                    "type": "string",
                    "enum": ["documents", "caches"],
                    "description": "Sandbox root to resolve `path` against. Defaults to documents.",
                ],
                "maxBytes": [
                    "type": "integer",
                    "description": "Refuse to read files larger than this. Defaults to 65536.",
                ],
            ],
            "required": ["path"],
        ]
    }

    private let defaultMaxBytes: Int

    public init(defaultMaxBytes: Int = 64 * 1024) {
        self.defaultMaxBytes = defaultMaxBytes
    }

    public func execute(input: [String: Any]) async throws -> String {
        guard let path = input["path"] as? String, !path.isEmpty else {
            return "Error: missing required argument `path`."
        }
        let rootName = (input["root"] as? String)?.lowercased() ?? "documents"
        let maxBytes = (input["maxBytes"] as? Int) ?? defaultMaxBytes

        let rootURL: URL
        switch rootName {
        case "documents":
            rootURL = try directory(.documentDirectory)
        case "caches":
            rootURL = try directory(.cachesDirectory)
        default:
            return "Error: `root` must be \"documents\" or \"caches\", got \"\(rootName)\"."
        }

        let candidate = URL(fileURLWithPath: path, relativeTo: rootURL).standardizedFileURL
        let resolvedRoot = rootURL.standardizedFileURL

        guard candidate.path.hasPrefix(resolvedRoot.path + "/") || candidate.path == resolvedRoot.path else {
            return "Error: path escapes \(rootName) root."
        }

        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: candidate.path, isDirectory: &isDir) else {
            return "Error: file not found at \(rootName):/\(path)."
        }
        if isDir.boolValue {
            return "Error: \(rootName):/\(path) is a directory."
        }

        let attrs = try fm.attributesOfItem(atPath: candidate.path)
        let size = (attrs[.size] as? Int) ?? 0
        if size > maxBytes {
            return "Error: file is \(size) bytes, exceeds maxBytes=\(maxBytes)."
        }

        let data = try Data(contentsOf: candidate)
        guard let text = String(data: data, encoding: .utf8) else {
            return "Error: file is not valid UTF-8 text."
        }
        return text
    }

    private func directory(_ kind: FileManager.SearchPathDirectory) throws -> URL {
        guard let url = FileManager.default.urls(for: kind, in: .userDomainMask).first else {
            throw CocoaError(.fileReadUnknown)
        }
        return url
    }
}
