# StatCappy かわいい

> A tiny capybara that keeps an eye on your Mac.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111111?logo=apple)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![Native SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0A84FF)

StatCappy is a native macOS menu-bar system monitor with configurable Desktop widgets. It puts the information you care about most—especially temperature—one click away without keeping a full dashboard open.

## Highlights

- 🌡️ Live temperature in Fahrenheit from Apple-silicon HID die sensors or Intel AppleSMC keys
- 🧠 CPU and memory usage
- 💽 Disk usage and free space
- 🔋 Battery level and charging state
- ↕️ Live network throughput
- ⏱️ System uptime and macOS thermal-pressure state
- 🫧 Native **Liquid Glass** appearance on supported macOS releases
- 🌸 Optional high-contrast **Kawaii** appearance with vector capybaras and Japanese accents
- 🧩 Small and medium Desktop widgets with an appearance setting independent of the menu-bar app
- ⚡ Five-second default sampling, throttled widget reloads, and no animated or bitmap assets

Everything is measured locally. StatCappy contains no analytics, accounts, ads, or network services.

## Install and run

StatCappy currently builds from source:

1. Clone this repository and open `StatCappy.xcodeproj` in Xcode.
2. Select the **StatCappy** app target, open **Signing & Capabilities**, and choose your Development Team.
3. Do the same for **StatCappyWidget**.
4. Ensure both targets use the App Group `group.com.statcappy.app`.
5. Select the **StatCappy** scheme and press **Run**.

StatCappy is a menu-bar utility, so it intentionally does not appear in the Dock. You can enable **Launch at Login** from its settings.

### Requirements

- macOS 14 or later
- Xcode 26 or later for native Liquid Glass compilation
- A free or paid Apple Developer identity for signing the app and widget

## Add and style the widget

1. Run StatCappy at least once.
2. Control-click the Desktop and choose **Edit Widgets**.
3. Search for **StatCappy** and add the small or medium widget.
4. Control-click the placed widget and choose **Edit StatCappy**.
5. Set **Appearance** to **Liquid Glass** or **Kawaii**.

The widget theme is independent. For example, the menu-bar dashboard can remain Kawaii while the Desktop widget uses Liquid Glass.

The app writes every menu-bar sample to the shared App Group and immediately requests a WidgetKit reload. WidgetKit controls the final rendering schedule, so macOS may defer a visible update. The widget always labels the time of its latest shared snapshot.

## Appearance

Liquid Glass is the default. On macOS versions with the native API, the popover uses a fully clear, dark-mode window with clear-glass metric surfaces. Older supported releases use a lightweight system-material fallback.

Kawaii mode uses pale cream and blush surfaces, dark cocoa text, deep raspberry accents, and SwiftUI-drawn capybaras. It avoids image decoding and animation timers to keep idle overhead low.

Switch the menu-bar appearance under **Settings → Appearance**.

## Temperature support

macOS does not provide a public universal API for raw CPU temperature, and sensor sources vary by model. StatCappy uses a best-effort local reader:

- **Apple silicon:** averages valid `PMU tdie` temperature events exposed by the HID event system.
- **Intel:** checks common CPU temperature keys exposed by AppleSMC.
- **Fallback:** displays Apple's supported thermal-pressure state—`Nominal`, `Warm`, `Hot`, or `Critical`—when a trustworthy raw value is unavailable.

StatCappy never fabricates a temperature and does not require administrator privileges. Raw readings may be unavailable on some hardware or future macOS releases.

## Development

The project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen), though the generated Xcode project is committed for convenience.

```bash
brew install xcodegen
xcodegen generate
xcodebuild \
  -project StatCappy.xcodeproj \
  -scheme StatCappy \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Project layout:

```text
StatCappy/          Menu-bar app and settings
StatCappyWidget/    Configurable WidgetKit extension
Shared/             Models, sampling, formatting, and themes
SensorBridge/       Apple silicon HID and Intel SMC temperature bridge
project.yml         XcodeGen project definition
```

## Privacy

System readings remain on your Mac. The only persisted data is the latest widget snapshot, chosen appearance, refresh interval, and launch-at-login preference. The app performs no outbound network requests.

## About

Created with care by **Zach Bohl (Cappy)**.

- [GitHub — @zach1020](https://github.com/zach1020)
- [zachbohl.com](https://zachbohl.com)

## Status

StatCappy is an early native macOS project. Hardware reports are welcome—especially temperature availability across different Mac models.
