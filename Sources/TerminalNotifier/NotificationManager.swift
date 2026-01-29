import Foundation
import UserNotifications

// MARK: - Notification Manager
class NotificationManager: NSObject {
    
    // MARK: - Properties
    private let userNotificationsManager = UserNotificationsManager()
    
    // MARK: - Public Methods
    
    /// Delivers a notification
    /// - Parameters:
    ///   - title: Notification title
    ///   - subtitle: Notification subtitle (optional)
    ///   - message: Notification message
    ///   - options: Additional notification options
    ///   - sound: Sound name (optional)
    func deliverNotification(title: String, subtitle: String?, message: String, options: [String: Any], sound: String?) {
        debugPrint("DEBUG: NotificationManager - Delivering notification - Title: \(title), Message: \(message)")
        
        // Note: We don't need to remove old notifications here.
        // UNNotificationRequest with the same identifier automatically replaces existing notifications.
        
        let delivered = userNotificationsManager.deliverNotification(title: title, subtitle: subtitle, message: message, options: options, sound: sound)
        
        // Schedule app termination
        // Wait for user interaction (30 seconds timeout)
        let timeout: TimeInterval = 30.0
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            debugPrint("DEBUG: NotificationManager - Exiting after notification delivery (delivered: \(delivered))")
            exit(0)
        }
    }
    
    /// Removes notifications with a specific group ID
    /// - Parameter groupID: The group ID to remove
    func removeNotification(groupID: String) {
        debugPrint("DEBUG: NotificationManager - Removing notifications with group ID: \(groupID)")
        
        let center = UNUserNotificationCenter.current()
        
        // The notification identifier is the groupID itself (set in scheduleNotification)
        // Remove from delivered notifications (already shown in notification center)
        center.removeDeliveredNotifications(withIdentifiers: [groupID])
        debugPrint("DEBUG: NotificationManager - Removed delivered notification with identifier: \(groupID)")
        
        // Also remove from pending notifications (scheduled but not yet shown)
        center.removePendingNotificationRequests(withIdentifiers: [groupID])
        debugPrint("DEBUG: NotificationManager - Removed pending notification with identifier: \(groupID)")
    }
    
    /// Lists notifications with a specific group ID
    /// - Parameter groupID: The group ID to list (use "ALL" for all notifications)
    func listNotifications(groupID: String) {
        debugPrint("DEBUG: NotificationManager - Listing notifications with group ID: \(groupID)")
        
        let center = UNUserNotificationCenter.current()
        let semaphore = DispatchSemaphore(value: 0)
        
        center.getDeliveredNotifications { notifications in
            var foundAny = false
            
            for notification in notifications {
                let content = notification.request.content
                if groupID == "ALL" {
                    let title = content.title
                    let message = content.body
                    let requestGroupID = content.userInfo["groupID"] as? String ?? notification.request.identifier
                    print("\(requestGroupID)\t\(title)\t\(message)")
                    foundAny = true
                } else if notification.request.identifier == groupID {
                    let title = content.title
                    let message = content.body
                    print("\(groupID)\t\(title)\t\(message)")
                    foundAny = true
                }
            }
            
            if !foundAny {
                debugPrint("DEBUG: NotificationManager - No delivered notifications found for group ID: \(groupID)")
            }
            
            semaphore.signal()
        }
        
        // Wait for async operation to complete (with timeout)
        _ = semaphore.wait(timeout: .now() + 2.0)
    }
    
    // MARK: - Helper Methods
    
    func printHelpBanner() {
        print("terminal-notifier (3.0.0) is a command-line tool to send macOS User Notifications.")
        print("")
        print("Usage: terminal-notifier -[message|list|remove] [VALUE|ID|ID] [options]")
        print("")
        print("   Either of these is required (unless message data is piped to the tool):")
        print("")
        print("       -help              Display this help banner.")
        print("       -version           Display terminal-notifier version.")
        print("       -message VALUE     The notification message.")
        print("       -remove ID         Removes a notification with the specified 'group' ID.")
        print("       -list ID           If the specified 'group' ID exists show when it was delivered,")
        print("                          or use 'ALL' as ID to see all notifications.")
        print("                          The output is a tab-separated list.")
        print("")
        print("   Optional:")
        print("")
        print("       -title VALUE       The notification title. Defaults to 'Terminal'.")
        print("       -subtitle VALUE    The notification subtitle.")
        print("       -sound NAME        The name of a sound to play when the notification appears. The names are listed")
        print("                          in Sound Preferences. Use 'default' for the default notification sound.")
        print("       -group ID          A string which identifies the group the notifications belong to.")
        print("                          Old notifications with the same ID will be removed.")
        print("       -activate ID       The bundle identifier of the application to activate when the user clicks the notification.")
        print("       -contentImage URL  The URL of an image to display attached to the notification")
        print("       -open URL          The URL of a resource to open when the user clicks the notification.")
        print("       -execute COMMAND   A shell command to perform when the user clicks the notification.")
        print("       -ignoreDnD         Send notification even if Do Not Disturb is enabled.")
        print("       --debug            Enable debug output.")
        print("")
        print("   Action Buttons (macOS 11.0+):")
        print("       -action TITLE      Add an action button with the specified title")
        print("       -action-text TITLE Add a text input action button (user can type response)")
        print("       -prompt TITLE      Alias for -action-text (user can reply to notification)")
        print("       -action-destructive TITLE  Add a destructive action button (shown in red)")
        print("       -action-icon TITLE:ICON  Add an action button with SF Symbol icon")
        print("       (Multiple actions can be specified - output format: ACTION:identifier or ACTION:identifier:text)")
        print("       (Text input responses are pipeable: ACTION:identifier:user_input_text)")
        print("When the user activates a notification, the results are logged to the system logs.")
        print("Use Console.app to view these logs.")
        print("")
        print("Note that in some circumstances the first character of a message has to be escaped in order to be recognized.")
        print("An example of this is when using an open bracket, which has to be escaped like so: '\\['.")
        print("")
        print("For more information see https://github.com/julienXX/terminal-notifier.")
    }
    
    func printVersion() {
        print("3.0.0")
    }
}
