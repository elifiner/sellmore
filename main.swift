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
                
                Button("Test") {
                    killZoomWindow()
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
            NSLog("DEBUG: SellMore app started")
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
        NSLog("DEBUG: killZoomWindow called")
        
        guard hasPermissions else {
            NSLog("DEBUG: No permissions for Zoom closing")
            checkPermissions()
            return
        }
        
        NSLog("DEBUG: Timer expired, attempting to close Zoom...")
        
        // First, let's see what Zoom processes exist
        let debugScript = """
        tell application "System Events"
            set allProcesses to name of every process
            set zoomProcesses to ""
            repeat with processName in allProcesses
                if processName contains "zoom" or processName contains "Zoom" then
                    if zoomProcesses is "" then
                        set zoomProcesses to processName
                    else
                        set zoomProcesses to zoomProcesses & ", " & processName
                    end if
                end if
            end repeat
            return zoomProcesses
        end tell
        """
        
        var error: NSDictionary?
        if let debugScriptObject = NSAppleScript(source: debugScript) {
            let result = debugScriptObject.executeAndReturnError(&error)
            NSLog("DEBUG: Found Zoom processes: \(result.stringValue ?? "none")")
            if let err = error {
                NSLog("DEBUG: Error finding processes: \(err)")
            }
        }
        
        // Force quit Zoom processes - no mercy, no dialogs
        let script = """
        tell application "System Events"
            set killedProcesses to ""
            set processCount to 0
            
            repeat with proc in (every process)
                set procName to name of proc
                if procName contains "zoom" or procName contains "Zoom" or procName is "zoom.us" then
                    try
                        set processCount to processCount + 1
                        if killedProcesses is "" then
                            set killedProcesses to procName
                        else
                            set killedProcesses to killedProcesses & ", " & procName
                        end if
                        
                        -- Force kill the process immediately
                        do shell script "kill -9 " & (unix id of proc)
                    on error killError
                        -- If kill -9 fails, try force quitting through System Events
                        try
                            set frontmost of proc to true
                            delay 0.1
                            key code 12 using {command down}
                        end try
                    end try
                end if
            end repeat
            return "Killed " & processCount & " processes: " & killedProcesses
        end tell
        """
        
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)
            NSLog("DEBUG: Script result: \(result.stringValue ?? "no result")")
            if let err = error {
                NSLog("DEBUG: Script error: \(err)")
            }
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