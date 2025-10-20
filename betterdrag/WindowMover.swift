//
//  WindowMover.swift
//  betterdrag
//
//  Created by David Moreen on 10/20/25.
//

import Cocoa
import ApplicationServices

class WindowMover {
    private var eventMonitor: Any?
    private var draggedWindow: AXUIElement?
    private var dragStartMouseLocation: CGPoint = .zero
    private var dragStartWindowPosition: CGPoint = .zero
    private var isDragging = false
    private var isEnabled = true

    func start() {
        // Request accessibility permissions if not granted
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
        }

        setupEventMonitor()
    }

    func stop() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    private func setupEventMonitor() {
        let eventMask: NSEvent.EventTypeMask = [
            .leftMouseDown,
            .leftMouseDragged,
            .leftMouseUp,
            .flagsChanged
        ]

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] event in
            self?.handleEvent(event)
        }
    }

    private func handleEvent(_ event: NSEvent) {
        guard isEnabled else { return }

        switch event.type {
        case .leftMouseDown:
            if event.modifierFlags.contains(.command) {
                handleMouseDown(at: event.locationInWindow)
            }

        case .leftMouseDragged:
            if isDragging {
                handleMouseDragged(to: NSEvent.mouseLocation)
            }

        case .leftMouseUp:
            if isDragging {
                handleMouseUp()
            }

        case .flagsChanged:
            // If command key is released while dragging, stop dragging
            if isDragging && !event.modifierFlags.contains(.command) {
                handleMouseUp()
            }

        default:
            break
        }
    }

    private func handleMouseDown(at location: CGPoint) {
        let mouseLocation = NSEvent.mouseLocation

        // Get the window under the cursor
        guard let windowElement = getWindowAtPoint(mouseLocation) else { return }

        // Get the current window position
        guard let windowPosition = getWindowPosition(windowElement) else { return }

        // Start dragging
        draggedWindow = windowElement
        dragStartMouseLocation = mouseLocation
        dragStartWindowPosition = windowPosition
        isDragging = true

        // Change cursor to closed hand using Core Graphics
        setCursor(.closedHand)
    }

    private func handleMouseDragged(to location: CGPoint) {
        guard let window = draggedWindow else { return }

        // Calculate the new position
        let deltaX = location.x - dragStartMouseLocation.x
        let deltaY = location.y - dragStartMouseLocation.y

        // Note: Y-axis is flipped in macOS (screen coordinates vs window coordinates)
        let newPosition = CGPoint(
            x: dragStartWindowPosition.x + deltaX,
            y: dragStartWindowPosition.y - deltaY
        )

        // Move the window
        setWindowPosition(window, to: newPosition)
    }

    private func handleMouseUp() {
        isDragging = false
        draggedWindow = nil

        // Reset cursor to arrow
        setCursor(.arrow)
    }

    private func getWindowAtPoint(_ point: CGPoint) -> AXUIElement? {
        // Get the system-wide element
        let systemWide = AXUIElementCreateSystemWide()

        // Get the element at the point
        var elementRef: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &elementRef)

        guard result == .success, let foundElement = elementRef else {
            return nil
        }

        var currentElement = foundElement

        // Traverse up the hierarchy to find the first standard window
        for _ in 0..<10 {
            var role: CFTypeRef?
            if AXUIElementCopyAttributeValue(currentElement, kAXRoleAttribute as CFString, &role) == .success,
               let roleString = role as? String {

                // Check if this is a window
                if roleString == kAXWindowRole as String {
                    // Verify it's a standard window (not a sheet, dialog, etc.)
                    if isStandardWindow(currentElement) {
                        return currentElement
                    }
                }
            }

            // Try to get the parent window attribute first (faster path)
            var windowRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(currentElement, kAXWindowAttribute as CFString, &windowRef) == .success,
               let window = windowRef {
                let windowElement = (window as! AXUIElement)
                if isStandardWindow(windowElement) {
                    return windowElement
                }
            }

            // Try to get the parent element
            var parent: CFTypeRef?
            if AXUIElementCopyAttributeValue(currentElement, kAXParentAttribute as CFString, &parent) == .success,
               let parentElement = parent {
                currentElement = (parentElement as! AXUIElement)
            } else {
                break
            }
        }

        return nil
    }

    private func isStandardWindow(_ window: AXUIElement) -> Bool {
        // Check if the window has a subrole that indicates it's not a standard window
        var subrole: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subrole) == .success,
           let subroleString = subrole as? String {
            // Exclude dialogs, sheets, system dialogs, etc.
            if subroleString == kAXDialogSubrole as String ||
               subroleString == kAXSystemDialogSubrole as String ||
               subroleString == "AXSheet" {
                return false
            }
        }

        // Check if the window is movable
        var movable: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, "AXModal" as CFString, &movable) == .success,
           let isModal = movable as? Bool,
           isModal {
            // Allow modal windows but check if they're movable
            var canMove: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, "AXWindow" as CFString, &canMove) == .success {
                return true
            }
        }

        return true
    }

    private func getWindowPosition(_ window: AXUIElement) -> CGPoint? {
        var positionRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef)

        guard result == .success, let position = positionRef else {
            return nil
        }

        var point = CGPoint.zero
        if AXValueGetValue(position as! AXValue, .cgPoint, &point) {
            return point
        }

        return nil
    }

    private func setWindowPosition(_ window: AXUIElement, to position: CGPoint) {
        var point = position
        if let value = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }
    }

    private func setCursor(_ cursor: NSCursor) {
        // We need to use Core Graphics to set the cursor since we're using global event monitors
        DispatchQueue.main.async {
            cursor.set()
        }
    }
}
