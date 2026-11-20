<div align="center">
  <img src="images/veil-icon.png" width="128" height="128" alt="Veil icon">

  <h1>Veil</h1>

  <p><b>A native, privacy-first Telegram client for macOS.</b><br>
  Read, listen and watch without leaving a trace.</p>

  <p>
    <a href="https://github.com/mahmudulashev/veil-mac/releases/latest"><img src="https://img.shields.io/github/v/release/mahmudulashev/veil-mac?label=download&color=111111" alt="Latest release"></a>
    <img src="https://img.shields.io/badge/macOS-12%2B-111111" alt="macOS 12+">
    <img src="https://img.shields.io/badge/Apple%20Silicon-native-111111" alt="Apple Silicon">
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPLv2-111111" alt="GPLv2"></a>
  </p>
</div>

---

Veil is a fork of the official [Telegram for macOS](https://github.com/overtake/TelegramSwift) app. It keeps everything
Telegram does, adds a **Ghost Mode** and a set of client-side extras, and wraps it in a cleaner, lighter design.
Everything Veil adds runs on your Mac only: no extra servers, no analytics.

> Veil is an unofficial client and is not affiliated with Telegram.

## Features

### Ghost Mode
Turn it on with one click from the chat list pill or with <kbd>⌘</kbd><kbd>⇧</kbd><kbd>G</kbd>.

| | What stays hidden |
|---|---|
| **Read receipts** | Messages you read don't get the double check |
| **Online status** | You always appear offline |
| **Typing** | "Typing…" and "recording voice…" are never sent |
| **Listened & watched** | Opening voice and video messages stays hidden |
| **Story views** | You don't appear in story viewer lists |
| **Read on reply** | Optional: sending a message marks the earlier ones as read |

### Message archive
- **Deleted messages** stay in your chat history, marked as deleted, even after the other side removes them
- **Edit history** keeps the text from before every edit, one click away in the message menu

Both work even when Ghost Mode is off and are stored only on your Mac.

### Beyond Telegram's limits
- **Unlimited pins**: pin more chats than the server allows; the extra pins live on this Mac and survive syncs
- **Unlimited folders**: folders over the server limit stay local-only and keep working
- **Chat Stats**: per-chat activity by hour, reply times, busiest day, streaks, media and top emoji, computed locally
- **Archive in Settings**: archived chats move out of the chat list, with their unread count on the Settings row

### Design
A light, airy interface with glass surfaces, pill tabs, round switches and a calmer chat screen.

## Install

1. Download `Veil.dmg` from the [latest release](https://github.com/mahmudulashev/veil-mac/releases/latest).
2. Open it and drag **Veil** into **Applications**.
3. Veil is not notarized by Apple, so the first launch needs one extra step:
   right-click **Veil** in Applications, choose **Open**, then **Open** again.
   On macOS 15 and newer, open **System Settings → Privacy & Security** and click **Open Anyway**.

   If macOS says the app is damaged, run this once:
   ```sh
   xattr -dr com.apple.quarantine /Applications/Veil.app
   ```

### Your own API keys
Telegram requires every third-party client to use its own API credentials. On first launch Veil asks for them:

1. Sign in to [my.telegram.org/apps](https://my.telegram.org/apps) with your phone number.
2. Click **Create application** and fill in any name.
3. Paste the **api_id** and **api_hash** into Veil.

The keys are stored only on your Mac and are never sent anywhere except to Telegram.

## Good to know
- Telegram may still show you online for a few seconds right after you send a message.
- Ghost Mode, the message archive, local pins and local folders exist only on this Mac. Your phone and other devices
  behave as usual.
- Using an unofficial client is at your own risk. Veil only changes what your own app sends; it can't unlock anything
  the server keeps locked.

## Build from source

Veil builds exactly like Telegram for macOS. Requirements, setup and troubleshooting are in [INSTALL.md](INSTALL.md).

```sh
git clone --recurse-submodules https://github.com/mahmudulashev/veil-mac.git
cd veil-mac
sh scripts/setup_build_env.sh --build
open Telegram-Mac.xcworkspace
```

Build the `Telegram` scheme. Veil's changes to the shared Telegram-iOS code live in
[`scripts/telegram-ios-macos.patch`](scripts/telegram-ios-macos.patch) and are applied by
`scripts/prepare-telegram-ios.sh`.

## License

Veil is licensed under the GNU General Public License, version 2.0, like the Telegram for macOS source it is based on.
See [LICENSE](LICENSE).

Telegram is a trademark of Telegram FZ-LLC. Veil uses its own name, icon and API credentials, as the
[Telegram API terms](https://core.telegram.org/api/terms) ask of forks.
