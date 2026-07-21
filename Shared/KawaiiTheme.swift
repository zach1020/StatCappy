import SwiftUI

enum KawaiiTheme {
    /// Deep enough to meet readable contrast on the pale surfaces below.
    static let pink = Color(red: 0.68, green: 0.12, blue: 0.32)
    static let softPink = Color(red: 1.00, green: 0.92, blue: 0.95)
    static let blush = Color(red: 1.00, green: 0.68, blue: 0.76)
    static let cocoa = Color(red: 0.46, green: 0.29, blue: 0.22)
    static let cream = Color(red: 1.00, green: 0.97, blue: 0.93)
    static let ink = Color(red: 0.20, green: 0.12, blue: 0.14)
    static let mutedInk = Color(red: 0.40, green: 0.30, blue: 0.32)
}

/// A tiny vector capybara face. Keeping this in SwiftUI avoids image decoding,
/// animation timers, and extra asset memory in both the app and widget.
struct CapybaraFace: View {
    var size: CGFloat = 44
    var mood: Mood = .happy

    enum Mood { case happy, cozy }

    var body: some View {
        ZStack {
            Circle()
                .fill(KawaiiTheme.cocoa.opacity(0.92))
                .frame(width: size * 0.24, height: size * 0.24)
                .offset(x: -size * 0.31, y: -size * 0.29)
            Circle()
                .fill(KawaiiTheme.cocoa.opacity(0.92))
                .frame(width: size * 0.24, height: size * 0.24)
                .offset(x: size * 0.31, y: -size * 0.29)
            RoundedRectangle(cornerRadius: size * 0.34)
                .fill(KawaiiTheme.cocoa)
                .frame(width: size * 0.88, height: size * 0.72)
            HStack(spacing: size * 0.27) {
                eye
                eye
            }
            .offset(y: -size * 0.08)
            HStack(spacing: size * 0.42) {
                Circle().fill(KawaiiTheme.blush).frame(width: size * 0.13, height: size * 0.08)
                Circle().fill(KawaiiTheme.blush).frame(width: size * 0.13, height: size * 0.08)
            }
            .offset(y: size * 0.10)
            RoundedRectangle(cornerRadius: size * 0.1)
                .fill(KawaiiTheme.cream)
                .frame(width: size * 0.30, height: size * 0.20)
                .offset(y: size * 0.10)
            Circle()
                .fill(.black.opacity(0.75))
                .frame(width: size * 0.10, height: size * 0.07)
                .offset(y: size * 0.055)
            if mood == .happy {
                Text("⌣")
                    .font(.system(size: size * 0.16, weight: .bold))
                    .foregroundStyle(.black.opacity(0.68))
                    .offset(y: size * 0.14)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var eye: some View {
        Group {
            if mood == .cozy {
                Capsule().fill(.black.opacity(0.72)).frame(width: size * 0.12, height: size * 0.035)
            } else {
                Circle().fill(.black.opacity(0.72)).frame(width: size * 0.075, height: size * 0.075)
            }
        }
    }
}

struct KawaiiCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(KawaiiTheme.softPink, in: RoundedRectangle(cornerRadius: 15))
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .stroke(KawaiiTheme.pink.opacity(0.22), lineWidth: 1)
            }
    }
}

extension View {
    func kawaiiCard() -> some View { modifier(KawaiiCardModifier()) }
}

struct ThemedCardModifier: ViewModifier {
    let theme: StatCappyTheme

    @ViewBuilder
    func body(content: Content) -> some View {
        if theme == .kawaii {
            content.kawaiiCard()
        } else if #available(macOS 26.0, *) {
            content.glassEffect(.clear.tint(.cyan.opacity(0.035)), in: .rect(cornerRadius: 14))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.20), lineWidth: 0.5)
                }
        }
    }
}

extension View {
    func themedCard(_ theme: StatCappyTheme) -> some View {
        modifier(ThemedCardModifier(theme: theme))
    }
}
