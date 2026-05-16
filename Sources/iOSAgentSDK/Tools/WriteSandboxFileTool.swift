import Foundation

/// Writes a UTF-8 text file inside the app sandbox.
///
/// Symmetric with ``ReadSandboxFileTool``. Confines writes to Documents/ or
/// Caches/, rejects path traversal, and defaults to a non-clobbering "create"
/// mode so the model can't silently overwrite user data.
///
/// Note: unlike on a Mac CLI, there is no system-level "are you sure?" prompt
/// for sandbox writes — the host app is the only thing that can confirm. If
/// you want a human-in-the-loop UX, gate this tool's registration on a
/// user-visible toggle, or wrap it in a host-side approval flow.
public struct WriteSandboxFileTool: ToolProtocol {
    public let name = "write_sandbox_file"
    public let description = """
        Writes UTF-8 text to a file inside the app sandbox. \
        `root` is "documents" (default) or "caches". \
        `path` is relative to that root, e.g. "notes/today.md". \
        `mode` is "create" (default; fails if file exists), "overwrite", or "append". \
        Intermediate directories under the root are created automatically. \
        Returns a one-line status summary, or an error if `content` exceeds maxBytes, \
        the path escapes the chosen root, or mode=="create" and the file already exists.
        """

    public var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "Relative path inside the chosen root.",
                ],
                "content": [
                    "type": "string",
                    "description": "UTF-8 text to write.",
                ],
                "root": [
                    "type": "string",
                    "enum": ["documents", "caches"],
                    "description": "Sandbox root. Defaults to documents.",
                ],
                "mode": [
                    "type": "string",
                    "enum": ["create", "overwrite", "append"],
                    "description": "Write mode. Defaults to create (fails if file exists).",
                ],
                "maxBytes": [
                    "type": "integer",
                    "description": "Refuse to write more than this many bytes. Defaults to 1048576 (1 MB).",
                ],
            ],
            "required": ["path", "content"],
        ]
    }

    public var isReadOnly: Bool { false }

    private let defaultMaxBytes: Int

    public init(defaultMaxBytes: Int = 1 * 1024 * 1024) {
        self.defaultMaxBytes = defaultMaxBytes
    }

    public func execute(input: [String: Any]) async throws -> String {
        guard let path = input["path"] as? String, !path.isEmpty else {
            return "Error: missing required argument `path`."
        }
        guard let content = input["content"] as? String else {
            return "Error: missing required argument `content` (must be a string)."
        }
        let rootName = (input["root"] as? String)?.lowercased() ?? "documents"
        let modeName = (input["mode"] as? String)?.lowercased() ?? "create"
        let maxBytes = (input["maxBytes"] as? Int) ?? defaultMaxBytes

        let data = Data(content.utf8)
        if data.count > maxBytes {
            return "Error: content is \(data.count) bytes, exceeds maxBytes=\(maxBytes)."
        }

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
        guard candidate.path.hasPrefix(resolvedRoot.path + "/") else {
            return "Error: path escapes \(rootName) root."
        }

        let fm = FileManager.default
        var existsIsDir: ObjCBool = false
        let exists = fm.fileExists(atPath: candidate.path, isDirectory: &existsIsDir)
        if exists && existsIsDir.boolValue {
            return "Error: \(rootName):/\(path) is an existing directory."
        }

        try fm.createDirectory(
            at: candidate.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        switch modeName {
        case "create":
            if exists {
                return "Error: \(rootName):/\(path) already exists (use mode=\"overwrite\" to replace)."
            }
            try data.write(to: candidate, options: .atomic)
            return "Created \(rootName):/\(path) (\(data.count) bytes)."

        case "overwrite":
            try data.write(to: candidate, options: .atomic)
            return "\(exists ? "Overwrote" : "Created") \(rootName):/\(path) (\(data.count) bytes)."

        case "append":
            if exists {
                let handle = try FileHandle(forWritingTo: candidate)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                return "Appended \(data.count) bytes to \(rootName):/\(path)."
            } else {
                try data.write(to: candidate, options: .atomic)
                return "Created \(rootName):/\(path) (\(data.count) bytes)."
            }

        default:
            return "Error: `mode` must be \"create\", \"overwrite\", or \"append\", got \"\(modeName)\"."
        }
    }

    private func directory(_ kind: FileManager.SearchPathDirectory) throws -> URL {
        guard let url = FileManager.default.urls(for: kind, in: .userDomainMask).first else {
            throw CocoaError(.fileWriteUnknown)
        }
        return url
    }
}
