import SwiftUI

// MARK: - Progress Ring View

/// A circular progress indicator showing goal completion.
/// Animates smoothly and supports custom colors and sizes.
struct ProgressRingView: View {
    @Environment(\.colorScheme) private var colorScheme

    let progress: Double
    let goal: String?
    let current: String
    let unit: String
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat

    init(
        progress: Double,
        current: String,
        unit: String = "",
        goal: String? = nil,
        color: Color = .hubPrimary,
        size: CGFloat = 120,
        lineWidth: CGFloat = 10
    ) {
        self.progress = min(max(progress, 0), 1)
        self.current = current
        self.unit = unit
        self.goal = goal
        self.color = color
        self.size = size
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(
                    AdaptiveColors.surfaceSecondary(for: colorScheme),
                    lineWidth: lineWidth
                )

            // Progress arc
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    progressGradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)

            // Center content
            VStack(spacing: 2) {
                Text(current)
                    .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: size * 0.1, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                if let goal {
                    Text("of \(goal)")
                        .font(.system(size: size * 0.09, weight: .medium))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }
        }
        .frame(width: size, height: size)
    }

    private var progressGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [color, color.opacity(0.7)]),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * progress)
        )
    }
}

// MARK: - Compact Progress Ring

/// A smaller inline progress ring without center text.
struct CompactProgressRing: View {
    @Environment(\.colorScheme) private var colorScheme

    let progress: Double
    let color: Color
    let size: CGFloat

    init(progress: Double, color: Color = .hubPrimary, size: CGFloat = 24) {
        self.progress = min(max(progress, 0), 1)
        self.color = color
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: size * 0.15)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.15, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}
