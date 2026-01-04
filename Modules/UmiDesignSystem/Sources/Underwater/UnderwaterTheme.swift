import SwiftUI
import os

public struct UnderwaterThemeView<Content: View>: View {
    private let logger = Logger(subsystem: "app.umilog", category: "UnderwaterTheme")
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var t: Double = 0
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ZStack {
            // 1) Ocean backdrop (MeshGradient on iOS 18+, gradient fallback on iOS 17)
            oceanBackground
                .blur(radius: 16)
                .opacity(colorScheme == .dark ? 0.9 : 0.8)
                .animation(reduceMotion ? nil : .easeInOut(duration: 6).repeatForever(autoreverses: true), value: t)

            // 2) Caustics-like shimmering overlay - disabled with reduce motion
            if !reduceMotion {
                CausticsOverlay(amplitude: 0.25, speed: 0.25)
                    .allowsHitTesting(false)
                    .blendMode(.screen)
                    .opacity(0.22)
                    .ignoresSafeArea()
            }

            // 3) Floating bubbles - disabled with reduce motion
            if !reduceMotion {
                BubblesOverlay()
                    .allowsHitTesting(false)
                    .opacity(0.11)
                    .ignoresSafeArea()
            }

            // App content on top with glassy feel
            content
                .environment(\.waterTransitionEnabled, !reduceMotion)
        }
        .onAppear {
            logger.log("UnderwaterThemeView started, reduceMotion=\(reduceMotion)")
            // Defer animation to avoid state mutation during render
            if !reduceMotion {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation { t = 1 }
                }
            }
        }
    }
    private var oceanBackground: some View {
        Group {
            if #available(iOS 18.0, *) {
                MeshGradient(
                    width: 3, height: 3,
                    points: [
                        .init(x: 0, y: 0), .init(x: 1, y: 0), .init(x: 0, y: 1),
                        .init(x: 1, y: 1), .init(x: 0.5, y: 0.5), .init(x: 0.2, y: 0.8)
                    ],
                    colors: [
                        Color.oceanBlue,
                        Color.diveTeal,
                        Color.oceanBlue.opacity(0.8),
                        Color.diveTeal.opacity(0.6),
                        Color.oceanBlue.opacity(0.5),
                        Color.diveTeal.opacity(0.4)
                    ]
                )
                .ignoresSafeArea()
            } else {
                // Fallback: layered gradients
                ZStack {
                    LinearGradient(colors: [Color.oceanBlue, Color.diveTeal], startPoint: .topLeading, endPoint: .bottomTrailing)
                    RadialGradient(colors: [Color.diveTeal.opacity(0.3), .clear], center: .center, startRadius: 0, endRadius: 350)
                }
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Modifiers and Transitions
public extension View {
    func wateryCardStyle(cornerRadius: CGFloat = 16) -> some View {
        self
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 6)
    }

    /// Applies an underwater-themed transition, simplified when Reduce Motion is enabled
    func wateryTransition() -> some View {
        self.modifier(WateryTransitionModifier())
    }

    /// Applies subtle underwater accent styling for visual consistency across tabs
    func underwaterAccent() -> some View {
        self.tint(.oceanBlue)
    }
}

private struct WateryTransitionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content.transition(.opacity)
        } else {
            content.transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.98)).animation(.smooth(duration: 0.45)),
                removal: .move(edge: .leading).combined(with: .opacity).animation(.smooth(duration: 0.35))
            ))
        }
    }
}

// MARK: - Environment keys
private struct WaterTransitionKey: EnvironmentKey { static let defaultValue: Bool = false }
public extension EnvironmentValues { var waterTransitionEnabled: Bool { get { self[WaterTransitionKey.self] } set { self[WaterTransitionKey.self] = newValue } } }

// Provide an optional binding to control the theme from feature modules without referencing AppState
private struct UnderwaterThemeBindingKey: EnvironmentKey { static let defaultValue: Binding<Bool>? = nil }
public extension EnvironmentValues { var underwaterThemeBinding: Binding<Bool>? { get { self[UnderwaterThemeBindingKey.self] } set { self[UnderwaterThemeBindingKey.self] = newValue } } }

// MARK: - Caustics Overlay
struct CausticsOverlay: View {
    var amplitude: Double
    var speed: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30.0, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate * speed
            Canvas { ctx, size in
                // Simple caustics effect using layered sine waves
                ctx.addFilter(.blur(radius: 10))
                for i in 0..<3 {
                    var path = Path()
                    let phase = time + Double(i) * .pi / 2
                    let waveHeight = size.height / 18
                    for x in stride(from: 0.0, through: size.width, by: 6) {
                        let y = sin((x / 90.0) + phase) * waveHeight * amplitude + (size.height * (0.25 + 0.25 * Double(i)))
                        if x == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    let gradient = Gradient(colors: [Color.white.opacity(0.20), Color.white.opacity(0.02)])
                    let style = StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round)
                    ctx.stroke(path, with: .linearGradient(Gradient(colors: gradient.stops.map { $0.color }), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)), style: style)
                }
            }
        }
    }
}

// MARK: - Bubbles Overlay
struct BubblesOverlay: View {
    @State private var bubbles: [Bubble] = (0..<12).map { _ in Bubble.random() }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30.0)) { timeline in
            let _ = timeline.date
            GeometryReader { geo in
                Canvas { ctx, size in
                    for i in bubbles.indices {
                        bubbles[i].advance(in: size)
                        let bubble = bubbles[i]
                        let circle = Path(ellipseIn: CGRect(x: bubble.x, y: bubble.y, width: bubble.r, height: bubble.r))
                        ctx.fill(circle, with: .radialGradient(.init(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)]), center: CGPoint(x: bubble.x + bubble.r/3, y: bubble.y + bubble.r/3), startRadius: 0, endRadius: bubble.r))
                    }
                }
            }
        }
    }

    struct Bubble {
        var x: CGFloat
        var y: CGFloat
        var vy: CGFloat
        var drift: CGFloat
        var r: CGFloat

        mutating func advance(in size: CGSize) {
            y -= vy
            x += sin(y / 40.0) * drift
            if y + r < 0 { self = Bubble.random(size: size) }
        }
        static func random(size: CGSize = CGSize(width: 390, height: 844)) -> Bubble {
            Bubble(x: .random(in: 0...size.width), y: .random(in: size.height...(size.height*1.3)), vy: .random(in: 0.6...1.4), drift: .random(in: 0.4...1.2), r: .random(in: 6...16))
        }
    }
}
