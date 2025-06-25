import SwiftUI
import Cocoa
import AppKit

// App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSApplication.shared.windows.first
        window?.level = .floating
        window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window?.standardWindowButton(.zoomButton)?.isHidden = true
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        window?.isMovableByWindowBackground = true
        
        checkAutomationPermissions()
    }
    
    func checkAutomationPermissions() {
        let script = "tell application \"System Events\" to return name of first process"
        var error: NSDictionary?
        
        if let scriptObject = NSAppleScript(source: script) {
            _ = scriptObject.executeAndReturnError(&error)
            if error != nil {
                DispatchQueue.main.async {
                    self.showPermissionAlert()
                }
            }
        }
    }
    
    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Permissions Needed"
        alert.informativeText = "SellMore needs accessibility permissions to close Zoom windows when the timer expires. Please allow access in the previous dialog, or go to System Preferences > Security & Privacy > Privacy > Automation to grant permissions manually."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// Main Content View
struct ContentView: View {
    @State private var timeLeft = 30 * 60 // 30 minutes in seconds
    @State private var timer: Timer?
    @State private var isRunning = false
    @State private var hasPermissions = false
    
    private var timeString: String {
        let minutes = timeLeft / 60
        let seconds = timeLeft % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var timerColor: Color {
        if timeLeft <= 60 { return .red }
        if timeLeft <= 300 { return .yellow }
        return .primary
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text(timeString)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(timerColor)
            
            HStack(spacing: 8) {
                Button(isRunning ? "Stop" : "Start") {
                    toggleTimer()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Reset") {
                    resetTimer()
                }
                .buttonStyle(.bordered)
                
                Button("+5m") {
                    addFiveMinutes()
                }
                .buttonStyle(.bordered)
            }
            
            if !hasPermissions {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("No automation access")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Fix") {
                        openSystemPreferences()
                    }
                    .font(.caption)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .onDisappear {
            timer?.invalidate()
        }
        .onAppear {
            checkPermissions()
        }
    }
    
    private func toggleTimer() {
        if isRunning {
            timer?.invalidate()
        } else {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if timeLeft > 0 {
                    timeLeft -= 1
                } else {
                    timer?.invalidate()
                    isRunning = false
                    killZoomWindow()
                }
            }
        }
        isRunning.toggle()
    }
    
    private func resetTimer() {
        timer?.invalidate()
        isRunning = false
        timeLeft = 30 * 60
    }
    
    private func addFiveMinutes() {
        timeLeft += 5 * 60
    }
    
    private func checkPermissions() {
        let script = "tell application \"System Events\" to return name of first process"
        var error: NSDictionary?
        
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            hasPermissions = (error == nil)
        }
    }
    
    private func openSystemPreferences() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
    }
    
    private func killZoomWindow() {
        guard hasPermissions else {
            checkPermissions()
            return
        }
        
        let script = """
        tell application "System Events"
            set zoomApps to (every process whose name contains "zoom")
            repeat with zoomApp in zoomApps
                try
                    set zoomWindows to (every window of zoomApp whose name contains "Zoom Meeting")
                    repeat with zoomWindow in zoomWindows
                        click (first button of zoomWindow whose description is "close button")
                    end repeat
                end try
            end repeat
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
    }
}

// Main App
@main
struct SellMoreApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
} 