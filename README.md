# KeyThock

A private, local macOS menu-bar prototype that turns keyboard presses into mechanical-keyboard sounds from the included `SoundPacks` WAV files.

## Install

Once KeyThock is published, install it with Homebrew:

```sh
brew install --cask adhi5308/tap/keythock
```

Then:

1. Open **KeyThock** from Applications. It lives in the menu bar.
2. Grant **System Settings → Privacy & Security → Accessibility** permission when macOS asks.
3. Choose a sound under the `⌨` menu-bar item. KeyThock keeps running until you quit it or press Command-Q.

The Homebrew installation contains the app and all its sound packs. Users do not need this source repository, Swift, or Xcode.

## Run

In Terminal, from this folder:

```sh
swift run
```

Click the keyboard icon in the menu bar, choose **Grant Accessibility permission…**, approve the prompt in **System Settings → Privacy & Security → Accessibility**, then restart `swift run` if macOS asks you to.

## Use it without Terminal

Build a standalone app once:

```sh
./Scripts/build-app.sh
```

Then double-click `KeyThock.app` in Finder. It keeps running as a menu-bar app even after Terminal closes. Quit it from the `⌨` menu or press Command-Q. The standalone app needs its own one-time Accessibility approval.

## Release to Homebrew

This follows the same Homebrew-cask pattern as Helm. First create two public GitHub repositories:

- `adhi5308/keythock` — this app and its GitHub Releases
- `adhi5308/homebrew-tap` — your Homebrew tap, containing `Casks/keythock.rb`

For each release, run:

```sh
./Scripts/release.sh 0.1.0 adhi5308/keythock
```

This creates `dist/KeyThock-0.1.0.zip` and `dist/keythock.rb`.

1. Create a GitHub Release tagged `v0.1.0` in the `keythock` repository and upload `dist/KeyThock-0.1.0.zip`.
2. Copy `dist/keythock.rb` to `Casks/keythock.rb` in `homebrew-tap`, then commit and push it.
3. Anyone can install it with `brew install --cask adhi5308/tap/keythock`.

## What “hardness” means

Apple's built-in keyboards do not make physical key-pressure measurements available to applications. KeyThock estimates it from inter-key timing: fast, continuous typing selects harder samples (`soft`, `medium`, `hard`, and `slam`); slower typing selects gentler samples. Adjust this under **Hardness sensitivity**.

All sound is synthesized on-device. No keystrokes, audio, or other data are recorded or sent anywhere.
