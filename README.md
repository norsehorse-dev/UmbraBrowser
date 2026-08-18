# Umbra

A privacy-first web browser for iOS, built with SwiftUI and WebKit.

Umbra blocks ads and trackers, strips tracking parameters, resists
fingerprinting, and prefers encrypted connections, while staying fast and
simple to use.

## Features

- Ad and tracker blocking with configurable filter lists
- UTM and tracking-parameter stripping
- Anti-fingerprinting protections
- HTTPS-first with an HTTP warning interstitial
- DNS-over-HTTPS with a choice of providers
- Reader mode
- Userscript support
- Bookmarks, history, and session restore
- Tab switcher and a command palette
- Per-site whitelist for blocking
- SSL certificate inspection

Some advanced options are part of an optional Pro tier ("Eclipse"). See
[Monetization](#monetization) below.

## Building

Requirements:

- macOS with Xcode 15 or later
- An Apple developer account for running on a physical device

Steps:

1. Open `Umbra Browser.xcodeproj` in Xcode.
2. In the target's Signing & Capabilities tab, select your own team. The
   `DEVELOPMENT_TEAM` build setting ships blank on purpose, so you set your
   own signing identity.
3. Build and run on the simulator or a device.

### Testing in-app purchases locally

A StoreKit configuration file, `Umbra Eclipse.storekit`, is included for
local testing of the paywall. Enable it under Product > Scheme > Edit
Scheme > Run > Options > StoreKit Configuration. The internal identifiers
in that file are blanked; the product IDs are what the app requests, so
local purchase flows work without App Store Connect.

## Monetization

Umbra has an optional Pro tier gated through StoreKit. This repository is
the source; the official build on the App Store is maintained separately.
You are free to build and run your own copy under the license below.

## License

Umbra is licensed under the Mozilla Public License 2.0. See
[LICENSE](LICENSE) for the full text.

MPL-2.0 is file-level copyleft: if you modify Umbra's source files and
distribute the result, those modified files must stay open under the same
license, but you can combine them with your own separate code.

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md)
first, in particular the note on how contributions are licensed.
