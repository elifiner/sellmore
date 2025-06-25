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
        // Just trigger the permission request, no alert needed
        let script = "tell application \"System Events\" to return name of first process"
        var error: NSDictionary?
        
        if let scriptObject = NSAppleScript(source: script) {
            _ = scriptObject.executeAndReturnError(&error)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// Main Content View
struct ContentView: View {
    // @State private var timeLeft = 30 * 60 // 30 minutes in seconds
    @State private var timeLeft = 15
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
                .fixedSize()
            
            HStack(spacing: 8) {
                Button(isRunning ? "Stop" : "Start") {
                    toggleTimer()
                }
                .buttonStyle(.borderedProminent)
                .fixedSize()
                
                Button("Reset") {
                    resetTimer()
                }
                .buttonStyle(.bordered)
                .fixedSize()
                
                Button("+5m") {
                    addFiveMinutes()
                }
                .buttonStyle(.bordered)
                .fixedSize()
            }
            
            if !hasPermissions {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Missing permissions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Fix") {
                        openSystemPreferences()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                .padding(.top, 6)
            }
        }
        .padding(16)
        .fixedSize()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .onDisappear {
            timer?.invalidate()
        }
        .onAppear {
            checkPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
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
                    // Check permissions every 10 seconds while running
                    if timeLeft % 10 == 0 {
                        checkPermissions()
                    }
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
        .defaultSize(width: 200, height: 120)
    }
} 