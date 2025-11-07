import Cocoa
import AppKit
import Foundation
import UniformTypeIdentifiers

struct RecentUpload: Codable {
    let filename: String
    let url: String
    let timestamp: Date
}

class RecentUploadsManager {
    private let maxUploads = 10
    private let userDefaultsKey = "RecentUploads"

    func addUpload(filename: String, url: String) {
        var uploads = getRecentUploads()

        // Add new upload at the beginning
        let newUpload = RecentUpload(filename: filename, url: url, timestamp: Date())
        uploads.insert(newUpload, at: 0)

        // Keep only last 10
        if uploads.count > maxUploads {
            uploads = Array(uploads.prefix(maxUploads))
        }

        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(uploads) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    func getRecentUploads() -> [RecentUpload] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let uploads = try? JSONDecoder().decode([RecentUpload].self, from: data) else {
            return []
        }
        return uploads
    }

    func clearAll() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}

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
    var cleanupManager: FileCleanupManager?
    var cleanupTimer: Timer?
    let recentUploadsManager = RecentUploadsManager()

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

        // Create cleanup manager
        self.cleanupManager = FileCleanupManager(config: config)

        super.init()

        // Set up menu with delegate for dynamic updates
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        // Build initial menu
        buildMenu()

        // Start watching
        fileWatcher.delegate = self
        fileWatcher.start()

        // Start scheduled cleanup if enabled
        if config.cleanupEnabled {
            startScheduledCleanup()
        }
    }

    func buildMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()

        // Dashboard
        let dashboardItem = NSMenuItem(title: "Open Dashboard", action: #selector(openDashboard), keyEquivalent: "")
        dashboardItem.target = self
        menu.addItem(dashboardItem)

        menu.addItem(NSMenuItem.separator())

        // Recent uploads section
        let recentUploads = recentUploadsManager.getRecentUploads()
        if !recentUploads.isEmpty {
            let recentHeader = NSMenuItem(title: "Recent Uploads", action: nil, keyEquivalent: "")
            recentHeader.isEnabled = false
            menu.addItem(recentHeader)

            for upload in recentUploads {
                let uploadItem = NSMenuItem(title: "  \(upload.filename)", action: #selector(openUploadURL(_:)), keyEquivalent: "")
                uploadItem.target = self
                uploadItem.representedObject = upload.url
                uploadItem.toolTip = upload.url
                menu.addItem(uploadItem)
            }

            menu.addItem(NSMenuItem.separator())
        }

        // Status
        let statusLabel = NSMenuItem(title: "Status: Watching", action: nil, keyEquivalent: "")
        menu.addItem(statusLabel)

        menu.addItem(NSMenuItem.separator())

        // Cleanup menu item
        let cleanupItem = NSMenuItem(title: "Clean Old Files Now", action: #selector(triggerCleanup), keyEquivalent: "")
        cleanupItem.target = self
        menu.addItem(cleanupItem)

        // Show cleanup status
        let cleanupStatus = config.cleanupEnabled ? "Auto-cleanup: Enabled (\(config.cleanupAgeDays) days)" : "Auto-cleanup: Disabled"
        let cleanupStatusItem = NSMenuItem(title: cleanupStatus, action: nil, keyEquivalent: "")
        menu.addItem(cleanupStatusItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // NSMenuDelegate method - called when menu is about to open
    func menuNeedsUpdate(_ menu: NSMenu) {
        buildMenu()
    }

    @objc func openDashboard() {
        if let url = URL(string: "https://share.lillefar.com/dashboard") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openUploadURL(_ sender: NSMenuItem) {
        if let urlString = sender.representedObject as? String,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func triggerCleanup() {
        print("🧹 Manual cleanup triggered")
        cleanupManager?.performCleanup { deletedCount, error in
            DispatchQueue.main.async {
                if let error = error {
                    let alert = NSAlert()
                    alert.messageText = "Cleanup Error"
                    alert.informativeText = error.localizedDescription
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                } else if deletedCount > 0 {
                    let alert = NSAlert()
                    alert.messageText = "Cleanup Complete"
                    alert.informativeText = "Deleted \(deletedCount) old files"
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                } else {
                    let alert = NSAlert()
                    alert.messageText = "Cleanup Complete"
                    alert.informativeText = "No old files found"
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }

    func startScheduledCleanup() {
        print("⏰ Scheduled cleanup enabled - runs daily")

        // Run cleanup immediately on start
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
            self.cleanupManager?.performCleanup { _, _ in }
        }

        // Schedule daily cleanup (24 hours)
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            self?.cleanupManager?.performCleanup { _, _ in }
        }
    }

    @objc func quit() {
        cleanupTimer?.invalidate()
        NSApplication.shared.terminate(nil)
    }
}

extension MenubarController: FileWatcherDelegate {
    func fileWatcher(_ watcher: FileWatcher, didDetectFile file: String) {
        print("File detected: \(file)")
    }

    func fileWatcher(_ watcher: FileWatcher, didSuccessfullyUpload file: String, withURL url: String) {
        // Get filename from path
        let filename = URL(fileURLWithPath: file).lastPathComponent

        // Save to recent uploads
        recentUploadsManager.addUpload(filename: filename, url: url)

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

        // Check if it's a .DS_Store file
        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        if fileName == ".DS_Store" {
            print("Skipping .DS_Store file: \(filePath)")
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

class FileCleanupManager {
    let config: Config

    init(config: Config) {
        self.config = config
    }

    func performCleanup(completion: @escaping (Int, Error?) -> Void) {
        print("🧹 Starting file cleanup for album: \(config.albumUUID)")
        print("📅 Removing files older than \(config.cleanupAgeDays) days")

        // Fetch album files
        fetchAlbumFiles { [weak self] files, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ Error fetching album files: \(error.localizedDescription)")
                completion(0, error)
                return
            }

            guard let files = files else {
                completion(0, nil)
                return
            }

            // Filter old files
            let oldFiles = self.filterOldFiles(files)

            if oldFiles.isEmpty {
                print("✓ No files older than \(self.config.cleanupAgeDays) days found")
                completion(0, nil)
                return
            }

            print("🗑️ Found \(oldFiles.count) old files to delete")

            // Delete old files
            self.deleteFiles(oldFiles) { deletedCount, error in
                if let error = error {
                    print("❌ Error during deletion: \(error.localizedDescription)")
                    completion(deletedCount, error)
                } else {
                    print("✓ Successfully deleted \(deletedCount) old files")
                    completion(deletedCount, nil)
                }
            }
        }
    }

    private func fetchAlbumFiles(completion: @escaping ([[String: Any]]?, Error?) -> Void) {
        let urlString = "\(config.serverBase)/api/album/\(config.albumUUID)"
        guard let url = URL(string: urlString) else {
            completion(nil, NSError(domain: "FileCleanup", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }

            guard let data = data else {
                completion(nil, NSError(domain: "FileCleanup", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Try different response formats
                    var files: [[String: Any]]? = nil

                    // Format 1: { "files": [...] }
                    if let filesArray = json["files"] as? [[String: Any]] {
                        files = filesArray
                    }
                    // Format 2: { "data": { "files": [...] } }
                    else if let dataDict = json["data"] as? [String: Any],
                            let filesArray = dataDict["files"] as? [[String: Any]] {
                        files = filesArray
                    }

                    completion(files, nil)
                } else {
                    completion(nil, NSError(domain: "FileCleanup", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"]))
                }
            } catch {
                completion(nil, error)
            }
        }

        task.resume()
    }

    private func filterOldFiles(_ files: [[String: Any]]) -> [String] {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -config.cleanupAgeDays, to: Date()) ?? Date()

        var oldFileUUIDs: [String] = []

        for file in files {
            guard let uuid = file["uuid"] as? String,
                  let createdAtStr = file["createdAt"] as? String else {
                continue
            }

            // Parse ISO 8601 date
            let dateFormatter = ISO8601DateFormatter()
            if let createdAt = dateFormatter.date(from: createdAtStr) {
                if createdAt < cutoffDate {
                    let fileName = file["name"] as? String ?? "unknown"
                    print("  📁 Old file: \(fileName) (created: \(createdAtStr))")
                    oldFileUUIDs.append(uuid)
                }
            }
        }

        return oldFileUUIDs
    }

    private func deleteFiles(_ uuids: [String], completion: @escaping (Int, Error?) -> Void) {
        let urlString = "\(config.serverBase)/api/admin/files/delete"
        guard let url = URL(string: urlString) else {
            completion(0, NSError(domain: "FileCleanup", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["uuids": uuids]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(0, error)
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(0, error)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                    completion(uuids.count, nil)
                } else {
                    let errorMsg = "HTTP \(httpResponse.statusCode)"
                    completion(0, NSError(domain: "FileCleanup", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg]))
                }
            }
        }

        task.resume()
    }
}

class Config {
    let uploadURL: URL
    let apiKey: String
    let albumUUID: String
    let watchDirectory: String
    let serverBase: String
    let cleanupEnabled: Bool
    let cleanupAgeDays: Int

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
        var cleanupEnabled = false
        var cleanupAgeDays = 180  // Default: 6 months

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
                case "CHIBISAFE_CLEANUP_ENABLED":
                    cleanupEnabled = (value.lowercased() == "true" || value == "1")
                case "CHIBISAFE_CLEANUP_AGE_DAYS":
                    cleanupAgeDays = Int(value) ?? 180
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
        self.cleanupEnabled = cleanupEnabled
        self.cleanupAgeDays = cleanupAgeDays
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
