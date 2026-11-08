import AppKit

enum BatteryTint {
    case normal, charging, lowPower, critical

    static func select(percentage: Int?, lowPowerMode: Bool, isCharging: Bool = false) -> BatteryTint {
        guard let percentage else { return .normal }
        if percentage <= 10 { return .critical }
        if lowPowerMode { return .lowPower }
        return isCharging ? .charging : .normal
    }
}

@MainActor
enum DuoStatusIcon {
    static func make(_ snapshot: BatterySnapshot, powerChange: PowerChange? = nil, progress: CGFloat = 1,
                     lowPowerMode: Bool = false, wifi: WiFiSnapshot = .unavailable,
                     networkProgress: CGFloat? = nil, memoryPercentage: Int? = nil,
                     menuClickProgress: CGFloat? = nil) -> NSImage {
        let tint = BatteryTint.select(
            percentage: snapshot.percentage, lowPowerMode: lowPowerMode,
            isCharging: snapshot.state == .charging
        )
        let neutral: NSColor = tint == .normal ? .black : .labelColor
        let image = NSImage(size: NSSize(width: 22, height: 22))
        image.lockFocus()
        let center = NSPoint(x: 11, y: 10.5)
        let radius: CGFloat = 8.3
        let click = menuClickProgress.map { min(1, max(0, $0)) }
        func smooth(_ value: CGFloat) -> CGFloat { value * value * (3 - 2 * value) }
        // First hold each arc's leading end while its tail catches up. Then
        // sweep around the circle and grow back, preserving each fill ratio.
        let contraction: CGFloat
        let rotation: CGFloat
        if let click, click < 0.35 {
            contraction = 1 - 0.82 * smooth(click / 0.35)
            rotation = 0
        } else if let click {
            let expansion = smooth((click - 0.35) / 0.65)
            contraction = 0.18 + 0.82 * expansion
            rotation = -360 * expansion
        } else {
            contraction = 1
            rotation = 0
        }
        let batteryEnd = -30 + rotation
        let batteryStart = batteryEnd + 240 * contraction
        let memoryStart = 234 + rotation
        let memoryEnd = memoryStart + 72 * contraction

        func arc(from start: CGFloat, to end: CGFloat, width: CGFloat) {
            guard start > end else { return }
            let path = NSBezierPath()
            path.lineWidth = width
            path.lineCapStyle = .round
            path.appendArc(withCenter: center, radius: radius,
                           startAngle: start, endAngle: end, clockwise: true)
            path.stroke()
        }

        neutral.withAlphaComponent(0.22).setStroke()
        arc(from: batteryStart, to: batteryEnd, width: 1.8)
        switch tint {
        case .normal: neutral.setStroke()
        case .charging: NSColor.systemGreen.setStroke()
        case .lowPower: NSColor.systemYellow.setStroke()
        case .critical: NSColor.systemRed.setStroke()
        }
        if let percentage = snapshot.percentage, percentage > 0 {
            arc(from: batteryStart, to: batteryStart - 240 * contraction * CGFloat(percentage) / 100, width: 1.8)
        }

        // A brief center animation replaces Wi-Fi only when external power changes.
        neutral.setStroke()
        neutral.setFill()
        if let powerChange {
            NSGraphicsContext.saveGraphicsState()
            let placement = NSAffineTransform()
            placement.translateX(by: 11, yBy: 10)
            placement.scale(by: 0.7 + 0.3 * min(1, max(0, progress)))
            placement.concat()
            let bolt = NSBezierPath()
            bolt.move(to: NSPoint(x: 1.6, y: 5.2))
            for point in [NSPoint(x: -3.1, y: -0.5), NSPoint(x: -0.6, y: -0.5),
                          NSPoint(x: -1.5, y: -5.1), NSPoint(x: 3.2, y: 0.8), NSPoint(x: 0.5, y: 0.8)] {
                bolt.line(to: point)
            }
            bolt.close()
            bolt.fill()
            if powerChange == .disconnected {
                let slash = NSBezierPath()
                slash.lineWidth = 1.2
                slash.lineCapStyle = .round
                slash.move(to: NSPoint(x: -3.5, y: 4))
                slash.line(to: NSPoint(x: 3.5, y: -4))
                slash.stroke()
            }
            NSGraphicsContext.restoreGraphicsState()
        } else {
            NSGraphicsContext.saveGraphicsState()
            if let click {
                let pulse = NSAffineTransform()
                pulse.translateX(by: 11, yBy: 10)
                pulse.scale(by: 1 + 0.08 * sin(.pi * click))
                pulse.translateX(by: -11, yBy: -10)
                pulse.concat()
            }
            if let networkProgress {
                let scale = 0.7 + 0.3 * min(1, max(0, networkProgress))
                let placement = NSAffineTransform()
                placement.translateX(by: 11, yBy: 10)
                placement.scale(by: scale)
                placement.translateX(by: -11, yBy: -10)
                placement.concat()
            }
            let opacity: CGFloat = wifi.state == .connected ? 1 : 0.38
            neutral.withAlphaComponent(opacity).setStroke()
            neutral.withAlphaComponent(opacity).setFill()
            let networkCenter = NSPoint(x: 11, y: 7.5)
            for networkRadius: CGFloat in [5, 2.8] {
                let band = NSBezierPath()
                band.lineWidth = 1.4
                band.lineCapStyle = .round
                band.appendArc(withCenter: networkCenter, radius: networkRadius, startAngle: 135, endAngle: 45, clockwise: true)
                band.stroke()
            }
            NSBezierPath(ovalIn: NSRect(x: 10.25, y: 6.75, width: 1.5, height: 1.5)).fill()
            if wifi.state == .off || wifi.state == .disconnected {
                let slash = NSBezierPath()
                slash.lineWidth = 1.4
                slash.lineCapStyle = .round
                slash.move(to: NSPoint(x: 6.8, y: 14.2))
                slash.line(to: NSPoint(x: 15.2, y: 5.8))
                slash.stroke()
            }
            NSGraphicsContext.restoreGraphicsState()
        }
        // Memory fills the lower arc from left to right, without an animation.
        neutral.withAlphaComponent(0.38).setStroke()
        arc(from: memoryEnd, to: memoryStart, width: 1.8)
        if let percentage = memoryPercentage, percentage > 0 {
            neutral.setStroke()
            let memory = NSBezierPath()
            memory.lineWidth = 1.8
            memory.lineCapStyle = .round
            memory.appendArc(withCenter: center, radius: radius, startAngle: memoryStart,
                             endAngle: memoryStart + 72 * contraction * CGFloat(min(100, percentage)) / 100, clockwise: false)
            memory.stroke()
        }

        image.unlockFocus()
        image.isTemplate = tint == .normal
        let memoryText = memoryPercentage.map { "内存估算 \($0)%" } ?? "内存暂不可用"
        image.accessibilityDescription = "电量 \(snapshot.percentageText)，\(snapshot.statusText)；\(wifi.statusText)；\(memoryText)"
        return image
    }
}
