import Cocoa
import AppKit
import Foundation
import UniformTypeIdentifiers

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var menubarController: MenubarController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = "☁️"
            button.toolTip = "Chibisafe Uploader"
        }

        // Initialize file watcher
        menubarController = MenubarController(statusItem: statusItem!)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

// Main entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

class MenubarController: NSObject, NSMenuDelegate {
    let statusItem: NSStatusItem
    let fileWatcher: FileWatcher
    let config: Config

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem

        // Load configuration
        self.config = Config()
        guard config.isValid else {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Configuration Error"
                alert.informativeText = "Invalid or missing chibisafe_watcher.env"
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            self.fileWatcher = FileWatcher(nil)
            super.init()
            return
        }

        // Create file watcher
        self.fileWatcher = FileWatcher(config)

        super.init()

        // Set up menu
        let menu = NSMenu()

        let dashboardItem = NSMenuItem(title: "Open Dashboard", action: #selector(openDashboard), keyEquivalent: "")
        dashboardItem.target = self
        menu.addItem(dashboardItem)

        menu.addItem(NSMenuItem.separator())

        let statusLabel = NSMenuItem(title: "Status: Watching", action: nil, keyEquivalent: "")
        menu.addItem(statusLabel)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        // Start watching
        fileWatcher.delegate = self
        fileWatcher.start()
    }

    @objc func openDashboard() {
        if let url = URL(string: "https://share.lillefar.com/dashboard") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}

extension MenubarController: FileWatcherDelegate {
    func fileWatcher(_ watcher: FileWatcher, didDetectFile file: String) {
        print("File detected: \(file)")
    }

    func fileWatcher(_ watcher: FileWatcher, didSuccessfullyUpload file: String, withURL url: String) {
        // Copy URL to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)

        // Blink menubar icon
        blinkMenubarIcon()

        print("✓ Uploaded: \(url)")
    }

    func fileWatcher(_ watcher: FileWatcher, didFailUpload file: String, withError error: String) {
        print("✗ Upload failed: \(error)")
    }

    private func blinkMenubarIcon() {
        guard let button = statusItem.button else { return }

        let originalTitle = button.title

        // Change icon to 🔗 briefly to indicate link copied
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            button.title = "🔗"

            // Change back to original after 600ms
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                button.title = originalTitle
            }
        }
    }
}

protocol FileWatcherDelegate: AnyObject {
    func fileWatcher(_ watcher: FileWatcher, didDetectFile file: String)
    func fileWatcher(_ watcher: FileWatcher, didSuccessfullyUpload file: String, withURL url: String)
    func fileWatcher(_ watcher: FileWatcher, didFailUpload file: String, withError error: String)
}

class FileWatcher: NSObject {
    weak var delegate: FileWatcherDelegate?
    let config: Config?
    var monitor: FileSystemEventMonitor?

    init(_ config: Config?) {
        self.config = config
        super.init()
    }

    func start() {
        guard let config = config else {
            print("Error: Config is nil")
            return
        }

        print("Starting file watcher for: \(config.watchDirectory)")

        // Use FSEvents via shell command to fswatch
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/fswatch")
        process.arguments = ["-0", config.watchDirectory]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            print("fswatch started successfully")

            DispatchQueue.global(qos: .userInitiated).async {
                let fileHandle = pipe.fileHandleForReading

                while process.isRunning {
                    let data = fileHandle.availableData
                    if data.isEmpty {
                        Thread.sleep(forTimeInterval: 0.5)
                        continue
                    }

                    autoreleasepool {

                        if let output = String(data: data, encoding: .utf8) {
                            print("Raw fswatch output (\(data.count) bytes): \(output.debugDescription)")

                            // Split by null terminator (fswatch -0 option)
                            let files = output.split(separator: "\0", omittingEmptySubsequences: true).map(String.init)

                            for file in files {
                                let trimmed = file.trimmingCharacters(in: .whitespaces)
                                if !trimmed.isEmpty {
                                    print("File event detected: \(trimmed)")
                                    self.handleFile(trimmed)
                                }
                            }
                        }
                    }
                }
                print("fswatch stopped")
            }
        } catch {
            print("Error starting fswatch: \(error)")
        }
    }

    private func handleFile(_ filePath: String) {
        guard let config = config else {
            print("Error: Config is nil in handleFile")
            return
        }

        // Check if it's a file
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: filePath, isDirectory: &isDir),
              !isDir.boolValue else {
            print("Skipping (not a file or doesn't exist): \(filePath)")
            return
        }

        print("Valid file detected: \(filePath)")
        delegate?.fileWatcher(self, didDetectFile: filePath)

        // Upload file
        uploadFile(filePath, config: config)
    }

    private func getMimeType(for filePath: String) -> String {
        let url = URL(fileURLWithPath: filePath)
        let pathExtension = url.pathExtension.lowercased()

        // Try to get MIME type from file extension
        let mimeTypes: [String: String] = [
            "png": "image/png",
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "gif": "image/gif",
            "webp": "image/webp",
            "svg": "image/svg+xml",
            "pdf": "application/pdf",
            "mp4": "video/mp4",
            "webm": "video/webm",
            "mp3": "audio/mpeg",
            "wav": "audio/wav",
            "txt": "text/plain",
            "html": "text/html",
            "css": "text/css",
            "js": "application/javascript",
            "json": "application/json",
            "zip": "application/zip",
            "tar": "application/x-tar",
            "gz": "application/gzip"
        ]

        if let mimeType = mimeTypes[pathExtension] {
            return mimeType
        }

        // Try using UniformTypeIdentifiers
        if #available(macOS 11.0, *) {
            if let utType = UTType(filenameExtension: pathExtension) {
                if let mimeType = utType.preferredMIMEType {
                    return mimeType
                }
            }
        }

        // Default to application/octet-stream
        return "application/octet-stream"
    }

    private func uploadFile(_ filePath: String, config: Config) {
        print("Starting upload: \(filePath)")

        DispatchQueue.global().async {
            let url = config.uploadURL
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue(config.albumUUID, forHTTPHeaderField: "albumuuid")

            print("Upload URL: \(url)")
            print("API Key: \(config.apiKey.prefix(10))...")
            print("Album UUID: \(config.albumUUID)")

            // Create multipart form data
            let boundary = "----WebKitFormBoundary\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            var body = Data()

            // Add file
            if let fileData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
                let filename = URL(fileURLWithPath: filePath).lastPathComponent
                let mimeType = self.getMimeType(for: filePath)

                body.append("--\(boundary)\r\n".data(using: .utf8) ?? Data())
                body.append("Content-Disposition: form-data; name=\"file[]\"; filename=\"\(filename)\"\r\n".data(using: .utf8) ?? Data())
                body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8) ?? Data())
                body.append(fileData)
                body.append("\r\n".data(using: .utf8) ?? Data())
                body.append("--\(boundary)--\r\n".data(using: .utf8) ?? Data())

                print("File size: \(fileData.count) bytes")
                print("MIME type: \(mimeType)")
            } else {
                print("Error: Could not read file data")
                self.delegate?.fileWatcher(self, didFailUpload: filePath, withError: "Could not read file")
                return
            }

            request.httpBody = body

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Upload error: \(error.localizedDescription)")
                    self.delegate?.fileWatcher(self, didFailUpload: filePath, withError: error.localizedDescription)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Status: \(httpResponse.statusCode)")

                    if (httpResponse.statusCode == 200 || httpResponse.statusCode == 201),
                       let data = data {
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("Full response: \(responseString)")
                        }

                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            print("JSON parsed: \(json)")

                            // Try different response formats
                            var uploadedURL: String?

                            // Format 1: { "file": { "url": "..." } }
                            if let fileInfo = json["file"] as? [String: Any],
                               let url = fileInfo["url"] as? String {
                                uploadedURL = url
                            }
                            // Format 2: { "url": "..." }
                            else if let url = json["url"] as? String {
                                uploadedURL = url
                            }
                            // Format 3: { "data": { "url": "..." } }
                            else if let dataInfo = json["data"] as? [String: Any],
                                    let url = dataInfo["url"] as? String {
                                uploadedURL = url
                            }

                            if let url = uploadedURL {
                                print("Upload successful! URL: \(url)")
                                // Check if URL is already absolute
                                let publicURL = url.starts(with: "http") ? url : (config.serverBase + url)
                                self.delegate?.fileWatcher(self, didSuccessfullyUpload: filePath, withURL: publicURL)
                            } else {
                                print("Could not find URL in response")
                                self.delegate?.fileWatcher(self, didFailUpload: filePath, withError: "URL not found in response")
                            }
                        } else {
                            print("Failed to parse JSON")
                            self.delegate?.fileWatcher(self, didFailUpload: filePath, withError: "Invalid JSON response")
                        }
                    } else {
                        print("HTTP error: \(httpResponse.statusCode)")
                        self.delegate?.fileWatcher(self, didFailUpload: filePath, withError: "HTTP \(httpResponse.statusCode)")
                    }
                }
            }

            task.resume()
        }
    }
}

class Config {
    let uploadURL: URL
    let apiKey: String
    let albumUUID: String
    let watchDirectory: String
    let serverBase: String

    var isValid: Bool {
        return !apiKey.isEmpty && !albumUUID.isEmpty && !watchDirectory.isEmpty
    }

    init() {
        // Read from chibisafe_watcher.env
        let envPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Sites/tools/chibisafe-uploader/chibisafe_watcher.env")

        var uploadURLStr = "https://share.lillefar.com/api/upload"
        var apiKey = ""
        var albumUUID = ""
        var watchDir = ""
        var serverBase = "https://share.lillefar.com"

        if let content = try? String(contentsOfFile: envPath.path, encoding: .utf8) {
            for line in content.split(separator: "\n") {
                let parts = line.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else { continue }

                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)

                switch key {
                case "CHIBISAFE_REQUEST_URL":
                    uploadURLStr = value
                    serverBase = value.replacingOccurrences(of: "/api/upload", with: "")
                case "CHIBISAFE_API_KEY":
                    apiKey = value
                case "CHIBISAFE_ALBUM_UUID":
                    albumUUID = value
                case "CHIBISAFE_WATCH_DIR":
                    watchDir = value
                default:
                    break
                }
            }
        }

        self.uploadURL = URL(string: uploadURLStr) ?? URL(string: "https://share.lillefar.com/api/upload")!
        self.apiKey = apiKey
        self.albumUUID = albumUUID
        self.watchDirectory = watchDir
        self.serverBase = serverBase
    }
}

// File system event monitor using FSEvents
class FileSystemEventMonitor {
    let watchPath: String
    var stream: FSEventStreamRef?

    init(watchPath: String) {
        self.watchPath = watchPath
    }

    deinit {
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }
}
