//
//  AppDelegate.swift
//  betterdrag
//
//  Created by David Moreen on 10/20/25.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    // This outlet is connected in MainMenu.xib but we don't use it (menu bar app only)
    @IBOutlet weak var window: NSWindow?

    private var statusItem: NSStatusItem!
    private var windowMover: WindowMover!
    private var isEnabled = true

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        for window in NSApplication.shared.windows {
            window.close()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "hand.draw", accessibilityDescription: "BetterDrag")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }

        setupMenu()

        windowMover = WindowMover()
        windowMover.start()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        windowMover.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    private func setupMenu() {
        let menu = NSMenu()

        let enableItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enableItem.target = self
        enableItem.state = isEnabled ? .on : .off
        menu.addItem(enableItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit BetterDrag", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func statusBarButtonClicked() {
        // The menu will be shown automatically
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        windowMover.setEnabled(isEnabled)

        // Update the menu item
        if let menu = statusItem.menu,
           let enableItem = menu.item(withTitle: "Enabled") {
            enableItem.state = isEnabled ? .on : .off
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

