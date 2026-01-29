import Foundation
import UserNotifications
import Cocoa

// MARK: - UserNotifications Manager
class UserNotificationsManager: NSObject, UNUserNotificationCenterDelegate {
    
    // MARK: - Properties
    private let center = UNUserNotificationCenter.current()
    
    // MARK: - Initialization
    override init() {
        super.init()
        center.delegate = self
    }
    
    // MARK: - Public Methods
    
    /// Attempts to deliver a notification
    /// - Parameters:
    ///   - title: Notification title
    ///   - subtitle: Notification subtitle (optional)
    ///   - message: Notification message
    ///   - options: Additional notification options
    ///   - sound: Sound name (optional)
    /// - Returns: True if notification was scheduled successfully, false otherwise
    func deliverNotification(title: String, subtitle: String?, message: String, options: [String: Any], sound: String?) -> Bool {
        debugPrint("DEBUG: UserNotificationsManager - Attempting to deliver notification")
        
        // Check for features not supported
        if options["ignoreDnD"] as? Bool == true {
            debugPrint("DEBUG: UserNotificationsManager - ignoreDnD not supported")
            return false
        }
        
        // Check authorization status
        let semaphore = DispatchSemaphore(value: 0)
        var isAuthorized = false
        var shouldSchedule = false
        
        center.getNotificationSettings { settings in
            let status = settings.authorizationStatus
            debugPrint("DEBUG: UserNotificationsManager - Authorization status: \(status.rawValue) (\(status))")
            
            if status == .authorized {
                debugPrint("DEBUG: UserNotificationsManager - Already authorized")
                isAuthorized = true
                shouldSchedule = true
            } else if status == .notDetermined {
                debugPrint("DEBUG: UserNotificationsManager - Requesting permission...")
                // Request permission with timeout
                DispatchQueue.main.async {
                    self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                        if let error = error {
                            debugPrint("DEBUG: UserNotificationsManager - Permission request error: \(error)")
                            debugPrint("DEBUG: UserNotificationsManager - Error domain: \(error.localizedDescription)")
                            debugPrint("DEBUG: UserNotificationsManager - Error code: \((error as NSError).code)")
                            debugPrint("DEBUG: UserNotificationsManager - Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")")
                            debugPrint("DEBUG: UserNotificationsManager - Bundle path: \(Bundle.main.bundlePath)")
                        } else if granted {
                            debugPrint("DEBUG: UserNotificationsManager - Permission granted")
                            isAuthorized = true
                            shouldSchedule = true
                        } else {
                            debugPrint("DEBUG: UserNotificationsManager - Permission denied")
                        }
                        semaphore.signal()
                    }
                }
            } else {
                debugPrint("DEBUG: UserNotificationsManager - Not authorized (status: \(status.rawValue) - \(status))")
            }
            semaphore.signal()
        }
        
        // Wait for authorization with timeout (3 seconds)
        let result = semaphore.wait(timeout: .now() + 3.0)
        if result == .timedOut {
            debugPrint("DEBUG: UserNotificationsManager - Authorization request timed out")
            return false
        }
        
        if !isAuthorized || !shouldSchedule {
            debugPrint("DEBUG: UserNotificationsManager - Not authorized, cannot deliver notification")
            return false
        }
        
        // Schedule the notification
        return scheduleNotification(title: title, subtitle: subtitle, message: message, options: options, sound: sound)
    }
    
    /// Creates notification actions from options
    @available(macOS 10.14, *)
    private func createActions(from options: [String: Any]) -> [UNNotificationAction]? {
        guard let actionsData = options["actions"] as? [[String: String]], !actionsData.isEmpty else {
            return nil
        }
        
        var notificationActions: [UNNotificationAction] = []
        
        for (index, actionData) in actionsData.enumerated() {
            guard let title = actionData["title"] else { continue }
            let type = actionData["type"] ?? "default"
            let identifier = actionData["identifier"] ?? "action_\(index)"
            
            var action: UNNotificationAction?
            
            if type == "text" {
                // Text input action
                if #available(macOS 11.0, *) {
                    action = UNTextInputNotificationAction(
                        identifier: identifier,
                        title: title,
                        options: [],
                        textInputButtonTitle: "Send",
                        textInputPlaceholder: "Type here..."
                    )
                }
            } else {
                // Regular or destructive action
                var actionOptions: UNNotificationActionOptions = []
                if type == "destructive" {
                    actionOptions.insert(.destructive)
                }
                
                if #available(macOS 12.0, *), let iconName = actionData["icon"] {
                    // Action with icon (requires macOS 12.0+)
                    let icon = UNNotificationActionIcon(systemImageName: iconName)
                    action = UNNotificationAction(
                        identifier: identifier,
                        title: title,
                        options: actionOptions,
                        icon: icon
                    )
                } else {
                    // Action without icon
                    action = UNNotificationAction(
                        identifier: identifier,
                        title: title,
                        options: actionOptions
                    )
                }
            }
            
            if let action = action {
                notificationActions.append(action)
            }
        }
        
        return notificationActions.isEmpty ? nil : notificationActions
    }
    
    /// Creates and registers a notification category with actions
    private func registerCategory(with identifier: String, actions: [UNNotificationAction]) {
        let category = UNNotificationCategory(
            identifier: identifier,
            actions: actions,
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([category])
        debugPrint("DEBUG: UserNotificationsManager - Registered category '\(identifier)' with \(actions.count) actions")
    }
    
    /// Schedules a notification using UserNotifications
    private func scheduleNotification(title: String, subtitle: String?, message: String, options: [String: Any], sound: String?) -> Bool {
        debugPrint("DEBUG: UserNotificationsManager - Scheduling notification")
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        
        if let subtitle = subtitle {
            content.subtitle = subtitle
        }
        
        // Set sound
        if let sound = sound {
            if sound == "default" {
                content.sound = UNNotificationSound.default
            } else {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
            }
        }
        
        // Set user info
        var userInfo: [String: Any] = [:]
        
        // Store options in userInfo
        if let bundleID = options["bundleID"] as? String {
            userInfo["bundleID"] = bundleID
        }
        if let openURL = options["open"] as? String {
            userInfo["open"] = openURL
        }
        if let command = options["command"] as? String {
            userInfo["command"] = command
        }
        if let groupID = options["groupID"] as? String {
            userInfo["groupID"] = groupID
        }
        
        content.userInfo = userInfo
        
        // Handle action buttons
        if let actions = createActions(from: options) {
            let categoryIdentifier = options["groupID"] as? String ?? UUID().uuidString
            registerCategory(with: categoryIdentifier, actions: actions)
            content.categoryIdentifier = categoryIdentifier
            debugPrint("DEBUG: UserNotificationsManager - Added \(actions.count) action buttons to notification")
        }
        
        // Handle content image
        if let contentImageURL = options["contentImage"] as? String {
            if let attachment = createAttachment(from: contentImageURL) {
                content.attachments = [attachment]
                debugPrint("DEBUG: UserNotificationsManager - Content image attachment created")
            } else {
                debugPrint("DEBUG: UserNotificationsManager - Failed to create content image attachment")
            }
        }
        
        // Create notification request
        let identifier = options["groupID"] as? String ?? UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        // Schedule notification
        center.add(request) { error in
            if let error = error {
                debugPrint("DEBUG: UserNotificationsManager - Error scheduling notification: \(error)")
            } else {
                debugPrint("DEBUG: UserNotificationsManager - Notification scheduled successfully")
            }
        }
        
        return true
    }
    
    /// Creates an attachment from an image URL
    private func createAttachment(from urlString: String) -> UNNotificationAttachment? {
        guard let url = URL(string: urlString) else {
            debugPrint("DEBUG: UserNotificationsManager - Invalid URL: \(urlString)")
            return nil
        }
        
        do {
            var data: Data
            var fileExtension: String
            
            // Check if it's a local file path or a remote URL
            if url.scheme == "file" || url.scheme == nil {
                // Local file - handle special cases
                let pathExtension = url.pathExtension.lowercased()
                
                if pathExtension == "icns" {
                    // Convert ICNS to PNG for UserNotifications compatibility
                    if let image = NSImage(contentsOfFile: url.path) {
                        // Resize image to a reasonable size for notifications (64x64)
                        let targetSize = NSSize(width: 64, height: 64)
                        let resizedImage = NSImage(size: targetSize)
                        resizedImage.lockFocus()
                        image.draw(in: NSRect(origin: .zero, size: targetSize), from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1.0)
                        resizedImage.unlockFocus()
                        
                        if let cgImage = resizedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                            let rep = NSBitmapImageRep(cgImage: cgImage)
                            if let pngData = rep.representation(using: .png, properties: [:]) {
                                data = pngData
                                fileExtension = "png"
                                debugPrint("DEBUG: UserNotificationsManager - Converted ICNS to PNG (64x64)")
                            } else {
                                debugPrint("DEBUG: UserNotificationsManager - Failed to convert ICNS to PNG - no PNG data")
                                return nil
                            }
                        } else {
                            debugPrint("DEBUG: UserNotificationsManager - Failed to convert ICNS to PNG - no CGImage")
                            return nil
                        }
                    } else {
                        debugPrint("DEBUG: UserNotificationsManager - Failed to load ICNS file")
                        return nil
                    }
                } else {
                    // Regular image file
                    data = try Data(contentsOf: url)
                    fileExtension = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
                }
            } else {
                // Remote URL - download first
                data = try Data(contentsOf: url)
                // For remote URLs, try to detect image type from data or use jpg as default
                if url.pathExtension.isEmpty {
                    // Try to detect image type from data
                    if data.starts(with: [0xFF, 0xD8, 0xFF]) {
                        fileExtension = "jpg"
                    } else if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
                        fileExtension = "png"
                    } else if data.starts(with: [0x47, 0x49, 0x46]) {
                        fileExtension = "gif"
                    } else {
                        fileExtension = "jpg" // Default fallback
                    }
                } else {
                    fileExtension = url.pathExtension
                }
            }
            
            // Create temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
            
            try data.write(to: tempFile)
            
            // Create attachment
            let attachment = try UNNotificationAttachment(identifier: "image", url: tempFile, options: nil)
            debugPrint("DEBUG: UserNotificationsManager - Attachment created successfully")
            return attachment
            
        } catch {
            debugPrint("DEBUG: UserNotificationsManager - Error creating attachment: \(error)")
            return nil
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionIdentifier = response.actionIdentifier
        
        // Check if it's a user action (not dismissed)
        if actionIdentifier != UNNotificationDefaultActionIdentifier && actionIdentifier != UNNotificationDismissActionIdentifier {
            if let textInputResponse = response as? UNTextInputNotificationResponse {
                // Text input action
                print("ACTION:\(actionIdentifier):\(textInputResponse.userText)")
                debugPrint("DEBUG: UserNotificationsManager - Text input action '\(actionIdentifier)' with text: '\(textInputResponse.userText)'")
            } else {
                // Regular action
                print("ACTION:\(actionIdentifier)")
                debugPrint("DEBUG: UserNotificationsManager - Action '\(actionIdentifier)' triggered")
            }
            
            // Exit to allow scripts to capture the output
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                exit(0)
            }
            completionHandler()
            return
        }
        
        // Handle default notification click behavior (body click)
        debugPrint("DEBUG: UserNotificationsManager - didReceive response (default click)")
        
        // Output to stdout so callers can detect body clicks
        print("CLICKED")
        
        let userInfo = response.notification.request.content.userInfo
        
        // Handle app activation
        if let bundleID = userInfo["bundleID"] as? String {
            activateApp(bundleID: bundleID)
        }
        
        // Handle URL opening
        if let urlString = userInfo["open"] as? String,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
        
        // Handle command execution
        if let command = userInfo["command"] as? String {
            executeShellCommand(command)
        }
        
        // Exit to allow scripts to capture the output
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            exit(0)
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        debugPrint("DEBUG: UserNotificationsManager - willPresent notification")
        completionHandler([.alert, .sound, .badge])
    }
    
    // MARK: - Helper Methods
    
    private func activateApp(bundleID: String) {
        debugPrint("DEBUG: UserNotificationsManager - Activating app: \(bundleID)")
        NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleID, options: [], additionalEventParamDescriptor: nil, launchIdentifier: nil)
    }
    
    private func executeShellCommand(_ command: String) {
        debugPrint("DEBUG: UserNotificationsManager - Executing command: \(command)")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", command]
        try? task.run()
    }
}