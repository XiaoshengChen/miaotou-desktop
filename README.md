# miaotou · Desktop

**English** | [简体中文](README.zh-CN.md)

**Keep one thing you want to do in sight.**

miaotou is a minimal desktop app for side projects, writing, and things you want to make for yourself. Keep something like “Ship my first website” or “Finish my first essay” in your Mac menu bar or a floating Windows card. A little companion offers a daily idea and celebrates when you're done.

[Download the preview](https://github.com/XiaoshengChen/miaotou-desktop/releases) · [Report an issue](https://github.com/XiaoshengChen/miaotou-desktop/issues)

## What you can use it for

- Keep your own project visible while work windows fill your screen.
- Find a small next step in a suggestion from the companion.
- Focus on one thing at a time. If you replace it, the unfinished thing stays in your history.
- Celebrate finishing it with a little fireworks display, then choose what's next.

There's no list, project structure, tagging, or priority system to set up.

## What it looks like

### Mac: menu bar and pinned card

The image below is a design concept, not an actual desktop screenshot. It shows the desktop presentation on the left and a menu-bar card on the right. The current preview includes a menu-bar item, a pinned floating card, and a compact strip.

![Mac desktop and menu-bar design concept](docs/images/mac-concept.png)

Actual native interface renders:

<p><img src="docs/images/mac-card.png" alt="Native render of the miaotou Mac card" width="360" /></p>
<p><img src="docs/images/mac-strip.png" alt="The compact strip with the companion and one thing" width="280" /></p>

### Windows: always-on-top card and system tray

The image below is a Windows design concept. The card can stay above ordinary work windows or collapse into a strip. If you hide it, you can bring it back from the system tray.

![Windows floating-card and compact-strip design concept](docs/images/windows-concept.png)

## Getting started

### Mac

Requires macOS 14 or later. Supports Apple silicon and Intel Macs.

1. Download and unzip the Mac preview from [Releases](https://github.com/XiaoshengChen/miaotou-desktop/releases), then move `小苗头.app` to Applications.
2. Open the app, enter one thing from the menu bar, and select **Save this**.
3. Use the pin to keep the card on your desktop. Use the minus button to collapse it into a strip.
4. Select **Done** when you finish, enjoy the celebration, and write your next thing.

The interface defaults to English. Switch to Simplified Chinese in More → Preferences. The preview is locally signed, has not been notarized with Developer ID, and is not available on the Mac App Store. It is a preview rather than a fully signed distribution; developers can also build it from source.

### Windows

The current preview targets Windows 11 x64 and includes its runtime. No separate .NET installation is needed to use it.

1. Download and unzip the Windows preview from [Releases](https://github.com/XiaoshengChen/miaotou-desktop/releases).
2. Run `Miaotou.exe` and write down one thing.
3. Drag the card to position it. Click the thing to reveal **Done**, or use the minus button to collapse the card into a strip.
4. Use the companion in the system tray to restore the card. Right-click it to open history, preferences, or quit.

The Windows preview is not code-signed. Core record logic and compilation have been checked; window behavior, the tray, and multiple-display use still need more testing on real Windows machines.

## Where the companion's ideas come from

On a Mac that supports Apple Intelligence, miaotou tries to generate short ideas locally when the on-device model is available and supports the selected language. Otherwise, it uses built-in offline content. Windows currently uses offline content. The message changes with the local date. No cloud AI service or API key is required.

A message can be a practical suggestion, a useful question, or a lighthearted reminder. It does not invent quotations from famous people. The quality of on-device generation still needs continued testing on compatible devices.

## Records and privacy

- No account, ads, analytics tracking, or cloud data uploads.
- Things, history, and preferences are stored on the current computer.
- **Mac, Windows, and phone records do not automatically sync yet.** The desktop apps can export and import JSON records. Existing records are backed up before an import replaces them.
- Open at login is an option you enable in preferences.
- This repository contains application source, generic examples, and necessary images. It does not include actual personal records, developer account details, certificates, or API keys.

## Building from source

### Mac

Requires Xcode 26 or later with the Foundation Models API, plus Python 3. The app falls back to offline content on devices that cannot run the model.

```sh
swift test --package-path Mac
zsh Mac/build-app.sh
```

The universal app and ZIP are written to `dist/`. Builds use a generic public bundle identifier by default. Configure your own distribution identity locally, and keep signing materials out of the repository.

### Windows

Requires the .NET 10 SDK. Run in Windows PowerShell:

```powershell
dotnet run --project Windows/Smoke/Smoke.csproj
powershell -File Windows/build.ps1
```

The application is written to `dist/windows-x64/`. You can also cross-compile on Mac or Linux; this does not replace interaction testing on a real Windows machine.

## Project structure

```text
Mac/                       SwiftUI / AppKit app and core tests
Windows/                   WPF app, tray entry, and core checks
docs/images/               Design concepts and native interface renders
scripts/                   Sensitive-information checks before publication
.github/workflows/         Mac / Windows build checks
```

The current version focuses on one thing, keeping it visible, a daily idea, and a celebration when it's done. Use Issues to share a specific use case or a reproducible problem.
