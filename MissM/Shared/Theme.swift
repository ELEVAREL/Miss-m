import SwiftUI

// MARK: - Miss M Design System

struct Theme {

    // MARK: Colors
    struct Colors {
        static let rosePrimary    = Color(hex: "#E91E8C")
        static let roseDeep       = Color(hex: "#C2185B")
        static let roseDark       = Color(hex: "#880E4F")
        static let roseMid        = Color(hex: "#F06292")
        static let roseLight      = Color(hex: "#F8BBD9")
        static let rosePale       = Color(hex: "#FCE4EC")
        static let roseUltra      = Color(hex: "#FFF0F8")
        static let gold           = Color(hex: "#D4AF7A")
        static let goldLight      = Color(hex: "#F5E6C8")
        static let textPrimary    = Color(hex: "#1A0A10")
        static let textMedium     = Color(hex: "#5C3049")
        static let textSoft       = Color(hex: "#9A6B80")
        static let textXSoft      = Color(hex: "#C4A0B2")
        static let glassWhite     = Color.white.opacity(0.62)
        static let glassBorder    = Color.white.opacity(0.82)
        static let shadow         = Color(hex: "#C2185B").opacity(0.13)
    }

    // MARK: Gradients
    struct Gradients {
        static let rosePrimary = LinearGradient(
            colors: [Colors.rosePrimary, Colors.roseDeep],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        static let roseDeep = LinearGradient(
            colors: [Colors.roseDeep, Colors.roseDark],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        static let background = LinearGradient(
            colors: [Colors.roseUltra, Colors.rosePale, Colors.roseLight, Color(hex: "#FDE8F3")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        static let heroCard = LinearGradient(
            colors: [Colors.rosePrimary, Colors.roseDeep, Colors.roseDark],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // MARK: Typography
    struct Fonts {
        // Display — Playfair Display italic for large headings
        static func display(_ size: CGFloat, italic: Bool = true) -> Font {
            italic ? .custom("PlayfairDisplay-Italic", size: size)
                   : .custom("PlayfairDisplay-Regular", size: size)
        }
        static func displayBold(_ size: CGFloat) -> Font {
            .custom("PlayfairDisplay-BoldItalic", size: size)
        }
        // Heading — Cormorant Garamond for labels
        static func heading(_ size: CGFloat) -> Font {
            .custom("CormorantGaramond-SemiBold", size: size)
        }
        // Body — DM Sans for UI
        static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .default)
        }
    }

    // MARK: Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
    }

    // MARK: Corner Radius
    struct Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let full: CGFloat = 999
    }
}

// MARK: - Glass Card Modifier
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = Theme.Radius.md
    var padding: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.Colors.glassWhite)
            .background(.ultraThinMaterial)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Theme.Colors.glassBorder, lineWidth: 1)
            )
            .shadow(color: Theme.Colors.shadow, radius: 10, x: 0, y: 4)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = Theme.Radius.md, padding: CGFloat = 14) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Rose Button Style
struct RoseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Theme.Gradients.rosePrimary)
            .foregroundColor(.white)
            .cornerRadius(Theme.Radius.sm)
            .shadow(color: Theme.Colors.rosePrimary.opacity(0.35), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Animation Presets
extension Theme {
    struct Animations {
        static let springBounce = Animation.spring(response: 0.4, dampingFraction: 0.65)
        static let springSnap = Animation.spring(response: 0.3, dampingFraction: 0.8)
        static let smoothEase = Animation.easeInOut(duration: 0.35)
        static let quickFade = Animation.easeOut(duration: 0.2)
    }
}

// MARK: - Shimmer Loading Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.4),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * geo.size.width * 1.6 - geo.size.width * 0.3)
                }
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Pulse Glow Effect
struct PulseGlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(isPulsing ? 0.6 : 0.15), radius: isPulsing ? radius : radius * 0.4)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Staggered Appear
struct StaggeredAppearModifier: ViewModifier {
    let index: Int
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 12)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4).delay(Double(index) * 0.08)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Animated Counter
struct AnimatedCounter: View {
    let value: Int
    let font: Font
    let color: Color
    @State private var displayValue: Int = 0

    var body: some View {
        Text("\(displayValue)")
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText(value: Double(displayValue)))
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    displayValue = value
                }
            }
            .onChange(of: value) { _, newVal in
                withAnimation(.easeOut(duration: 0.5)) {
                    displayValue = newVal
                }
            }
    }
}

// MARK: - Skeleton Placeholder
struct SkeletonView: View {
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Theme.Colors.rosePale)
            .frame(height: height)
            .modifier(ShimmerModifier())
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
    func pulseGlow(_ color: Color = Theme.Colors.rosePrimary, radius: CGFloat = 12) -> some View {
        modifier(PulseGlowModifier(color: color, radius: radius))
    }
    func staggerAppear(index: Int) -> some View { modifier(StaggeredAppearModifier(index: index)) }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
