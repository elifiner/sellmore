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
    @State private var timeLeft = 30 * 60 // 30 minutes in seconds
    @State private var timer: Timer?
    @State private var isRunning = false
    @State private var hasPermissions = false
    @State private var showTenMinuteWarning = false
    @State private var hasShownTenMinuteWarning = false
    @State private var warningOpacity: Double = 1.0
    @State private var blinkCount = 0
    @State private var editableMinutes = "30"
    @State private var editableSeconds = "00"
    
    private var timeString: String {
        let minutes = timeLeft / 60
        let seconds = timeLeft % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var timerColor: Color {
        if timeLeft <= 1 * 60 { return .red }    // 1 minute
        if timeLeft <= 5 * 60 { return .yellow } // 5 minutes
        return .primary
    }
    
    var body: some View {
        VStack(spacing: 12) {
            if isRunning {
                Text(timeString)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(timerColor)
                    .fixedSize()
            } else {
                HStack(spacing: 0) {
                    TextField("", text: $editableMinutes)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(timerColor)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .textFieldStyle(.plain)
                        .onSubmit { updateTimeFromInput() }
                        .onChange(of: editableMinutes) { _ in 
                            validateAndFormatMinutes()
                        }
                    
                    Text(":")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(timerColor)
                    
                    TextField("", text: $editableSeconds)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(timerColor)
                        .multilineTextAlignment(.leading)
                        .frame(width: 60)
                        .textFieldStyle(.plain)
                        .onSubmit { updateTimeFromInput() }
                        .onChange(of: editableSeconds) { _ in 
                            validateAndFormatSeconds()
                        }
                }
                .fixedSize()
            }
            
            if showTenMinuteWarning {
                HStack(spacing: 8) {
                    Text("10 minutes left")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .opacity(warningOpacity)
                    
                    Button("✔︎") {
                        showTenMinuteWarning = false
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                .padding(.vertical, 4)
                .transition(.opacity)
            }
            
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
                
                // Button("Test") {
                //     killZoomWindow()
                // }
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
            updateEditableFields()
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
                    
                    // Check for 10 minute warning
                    if timeLeft == 10 * 60 && !hasShownTenMinuteWarning {
                        showTenMinuteWarning = true
                        hasShownTenMinuteWarning = true
                        startBlinking()
                    }
                    
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
        showTenMinuteWarning = false
        hasShownTenMinuteWarning = false
        warningOpacity = 1.0
        blinkCount = 0
        updateEditableFields()
    }
    
    private func addFiveMinutes() {
        timeLeft += 5 * 60
        updateEditableFields()
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
        
        // Force quit Zoom processes - no mercy, no dialogs
        let script = """
        tell application "System Events"
            set killedProcesses to ""
            set processCount to 0
            
            repeat with proc in (every process)
                set procName to name of proc
                if procName contains "zoom" or procName contains "Zoom" or procName is "zoom.us" then
                    do shell script "kill " & (unix id of proc)
                end if
            end repeat
            return "Killed " & processCount & " processes: " & killedProcesses
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
    }
    
    private func startBlinking() {
        blinkCount = 0
        performBlink()
    }
    
    private func performBlink() {
        withAnimation(.easeInOut(duration: 0.3)) {
            warningOpacity = 0.2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.warningOpacity = 1.0
            }
            
            self.blinkCount += 1
            if self.blinkCount < 3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.performBlink()
                }
            }
        }
    }
    
    private func updateTimeFromInput() {
        let minutes = Int(editableMinutes) ?? 0
        let seconds = Int(editableSeconds) ?? 0
        timeLeft = minutes * 60 + seconds
        hasShownTenMinuteWarning = false
    }
    
    private func updateEditableFields() {
        let minutes = timeLeft / 60
        let seconds = timeLeft % 60
        editableMinutes = String(format: "%02d", minutes)
        editableSeconds = String(format: "%02d", seconds)
    }
    
    private func validateAndFormatMinutes() {
        let filtered = editableMinutes.filter { $0.isNumber }
        if let value = Int(filtered), value >= 0 {
            editableMinutes = String(format: "%02d", min(value, 99))
        } else {
            editableMinutes = "00"
        }
        updateTimeFromInput()
    }
    
    private func validateAndFormatSeconds() {
        let filtered = editableSeconds.filter { $0.isNumber }
        if let value = Int(filtered), value >= 0 {
            editableSeconds = String(format: "%02d", min(value, 59))
        } else {
            editableSeconds = "00"
        }
        updateTimeFromInput()
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