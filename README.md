# AgriLink Mobile

**The Android app for [AgriLink Sri Lanka](https://github.com/Razni-Ahamed/AgriLink_SriLanka),** built with Flutter.

It connects to the same backend API as the AgriLink website, so farmers and buyers see the same accounts, farms, advisories and marketplace on their phone as on the web.

> © 2026 the AgriLink authors. All rights reserved. This repository is public for viewing only — see [Licence](#licence).

---

## ⚠️ Status: setting up

**No app code has been written yet.** Right now every team member is setting up their computer with the steps below. Coding starts only after **everyone's `flutter doctor` shows no errors** (see [Step 7](#step-7--check-everything-with-flutter-doctor)).

---

## Contents

- [The plan](#the-plan)
- [Setup from scratch (Windows)](#setup-from-scratch-windows)
- [Troubleshooting](#troubleshooting)
- [How we work together](#how-we-work-together)
- [Backend API](#backend-api)
- [Authors](#authors)
- [Licence](#licence)

---

## The plan

The app is built in four phases, one owner each. **Phase 1 must be merged first**, because every other screen depends on it. After that, phases 2, 3 and 4 run in parallel.

| Phase | Owner | What it covers |
|---|---|---|
| **1. Foundation** | _TBD_ | Project setup, theme (same colours as the website), English / Sinhala / Tamil translations, API connection, login, registration, staying signed in, navigation shell, profile screen |
| **2. Farms & crops** | _TBD_ | Farms, fields and crops (list, add, edit), crop activity log |
| **3. Crop issues & advice** | _TBD_ | Report an issue with camera or gallery photos, my issues, advisory details, notification pop-ups |
| **4. Marketplace & orders** | _TBD_ | Browse harvests, my listings, purchase requests (sent and received), orders, buyer screens |

Version 1 focuses on **Farmers**, with buyer screens in phase 4. Officers and admins keep using the website.

---

## Setup from scratch (Windows)

Follow the steps **in order**. Setup takes about 1–2 hours, mostly downloads. You need about **15 GB of free disk space** and ideally **16 GB of RAM** or more for the emulator.

### Versions everyone must use

The whole team must use the **same Flutter version**. Different versions cause build errors that only happen on one person's computer.

| Tool | Version |
|---|---|
| **Flutter** | **3.47.5** (stable) — comes with Dart 3.13.4 |
| Android Studio | latest stable |
| Android SDK Platform | Android 16 (API 36) or newer |
| Java (JDK) | the one bundled with Android Studio (JDK 21), so no separate install |
| Git | latest |
| VS Code | latest, with the Flutter extension |

### Step 1 — Install Git

1. Download Git from https://git-scm.com/download/win and install it with the default options.
2. Tell Git who you are, **using the same email as your GitHub account**. Your commits count towards your share of the team work, and GitHub only credits them to you if the email matches.

   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "the-email-on-your-github-account@example.com"
   ```

### Step 2 — Install the Flutter SDK

1. Choose a folder **with no spaces in its path**, for example `C:\Users\<you>\flutter` or `C:\src\flutter`. Don't use `C:\Program Files\` (that path has a space and needs admin rights).
2. Open **Git Bash** or **PowerShell** in the parent folder and download Flutter at our exact version:

   ```bash
   git clone -b 3.47.5 https://github.com/flutter/flutter.git flutter
   ```

   (If Git is slow, you can instead download the zip from the [Flutter SDK archive](https://docs.flutter.dev/install/archive): pick **Windows → Stable → 3.47.5** and extract it to the same kind of folder.)

3. **Add Flutter to your PATH**, so the `flutter` command works in any terminal:
   1. Press **Start**, search for **"Edit environment variables for your account"** and open it.
   2. Under **User variables**, select **Path** → **Edit** → **New**.
   3. Add the `bin` folder inside Flutter, for example `C:\Users\<you>\flutter\bin`.
   4. Click **OK** on every window, then **close and reopen** all terminals and VS Code.
4. Check it works. The first run downloads more tools and takes a few minutes.

   ```bash
   flutter --version
   ```

   It must say **Flutter 3.47.5**.

### Step 3 — Install Android Studio

We only use Android Studio for the Android SDK and the emulator. The coding itself happens in VS Code.

1. Download it from https://developer.android.com/studio and install it with the default options.
2. Open it and complete the **Setup Wizard** with the **Standard** setup. This downloads the Android SDK, the emulator and the build tools.

### Step 4 — Add the Android SDK command-line tools

Flutter needs these, and the setup wizard doesn't install them.

1. In Android Studio's welcome screen, open **More Actions → SDK Manager**. If a project is open, use **Settings → Languages & Frameworks → Android SDK** instead.
2. On the **SDK Platforms** tab, make sure **Android 16 (API 36)** or a newer version is ticked.
3. On the **SDK Tools** tab, tick:
   - ✅ **Android SDK Command-line Tools (latest)**
   - ✅ **Android SDK Build-Tools**
   - ✅ **Android SDK Platform-Tools**
   - ✅ **Android Emulator**
4. Click **Apply** and wait for the downloads to finish.

### Step 5 — Accept the Android licences

In a **new** terminal, run the command below and type `y` for every licence:

```bash
flutter doctor --android-licenses
```

### Step 6 — Set up a device to run the app

You need at least one of these.

**Option A — Emulator (a virtual phone on your computer)**
1. In Android Studio, open **More Actions → Virtual Device Manager**.
2. Click **+ (Create Virtual Device)**, pick a phone (e.g. **Pixel 8**), click **Next**, choose an **API 36 or newer** system image (download it if asked), then **Finish**.
3. Press ▶ to start it once and check that it boots.

**Option B — Your own Android phone**
1. On the phone, go to **Settings → About phone** and tap **Build number** 7 times to enable Developer options.
2. Go to **Settings → System → Developer options** and turn on **USB debugging**.
3. Connect the phone with a USB cable and accept the **"Allow USB debugging?"** prompt on the phone.
4. `flutter devices` should now list your phone.

Testing on a real phone is worth doing at least once, especially for the **camera** and for **Sinhala and Tamil text**, which can render differently from the emulator.

### Step 7 — Check everything with `flutter doctor`

```bash
flutter doctor
```

Start your emulator first (or plug in your phone), so it shows up as a connected device. These lines **must** have a green ✓:

```
[√] Flutter (Channel stable, 3.47.5, on Microsoft Windows ...)
[√] Windows Version (Windows 11 or higher ...)
[√] Android toolchain - develop for Android devices (Android SDK version 36...)
[√] Connected device (... available)
[√] Network resources
```

`flutter doctor -v` should list your emulator (e.g. `sdk gphone64 x86 64 • emulator-5554 • android-x64`) or your phone under **Connected device**. Without one running, only Windows and the browsers are listed.

It's fine if these show ✗ or ! — **we don't build for them**:
- **Chrome** (web)
- **Visual Studio** (Windows desktop apps). This is *Visual Studio*, not VS Code.

Flutter 3.47 no longer checks Android Studio or VS Code in `flutter doctor`, so don't worry that they aren't listed.

If anything else has a ✗ or !, see [Troubleshooting](#troubleshooting). Also run `flutter doctor -v` for details, and post a screenshot in the team chat if you're stuck.

### Step 8 — Set up VS Code

1. Install VS Code from https://code.visualstudio.com/ if you don't have it.
2. Open the **Extensions** panel (`Ctrl+Shift+X`), search for **Flutter** (by Dart Code) and install it. This installs the **Dart** extension too.
3. Restart VS Code. Open the Command Palette (`Ctrl+Shift+P`), run **"Flutter: Run Flutter Doctor"**, and check that it matches Step 7.

### Step 9 — Clone this repository

```bash
git clone https://github.com/Razni-Ahamed/AgriLink_Mobile.git
cd AgriLink_Mobile
```

Once phase 1 has added the Flutter project, you'll also run:

```bash
flutter pub get      # download the app's packages
flutter run          # build and start the app on your emulator or phone
```

### ✅ You're done when…

- `flutter --version` shows **3.47.5**
- `flutter doctor` has green ✓ for Flutter, Windows Version, Android toolchain, Connected device and Network resources
- with your emulator running (or phone connected), it shows up in `flutter devices`
- VS Code has the **Flutter** and **Dart** extensions installed
- `git config user.email` matches your GitHub account's email

Tell the team when you've reached this point. When everyone is ready, phase 1 starts.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `'flutter' is not recognized as an internal or external command` | Flutter's `bin` folder isn't on your PATH, or the terminal was open before you added it. Recheck [Step 2.3](#step-2--install-the-flutter-sdk), then **close and reopen** the terminal (or restart the PC). |
| `cmdline-tools component is missing` | Install **Android SDK Command-line Tools** ([Step 4](#step-4--add-the-android-sdk-command-line-tools)). |
| `Android license status unknown` | Run `flutter doctor --android-licenses` and accept all ([Step 5](#step-5--accept-the-android-licences)). |
| `Unable to locate Android SDK` | Run `flutter config --android-sdk "C:\Users\<you>\AppData\Local\Android\Sdk"` (your SDK path is shown in Android Studio's SDK Manager). |
| Emulator is very slow or won't start | Enable virtualization (**Intel VT-x / AMD-V / SVM**) in your BIOS, and turn on **Windows Hypervisor Platform** under *Control Panel → Programs → Turn Windows features on or off*, then restart. |
| The first `flutter run` takes forever | Normal. The first build downloads Gradle and Android dependencies, which can take 5–10 minutes. Later builds are much faster. |
| Flutter shows the wrong version | You cloned a different branch. In the Flutter folder, run `git fetch --tags` then `git checkout 3.47.5`, then `flutter --version`. |
| Builds are very slow on Windows | Antivirus scanning can slow builds a lot. You may add your Flutter folder and project folder to Windows Security's exclusions. |
| Flutter path contains spaces | Move Flutter to a folder with no spaces (e.g. `C:\src\flutter`) and update PATH. |

---

## How we work together

- **Never commit directly to `main`.** Each phase gets its own branch, e.g. `feature/phase-1-foundation`, and a **pull request** into `main`.
- **Commit from your own computer and your own GitHub account.** Your commits are the record of your contribution.
- Make **small, clear commits** ("Add the login screen", not "update").
- Pull the latest `main` before starting work and before opening a pull request.
- Another member should look at each pull request before it's merged.
- Don't upgrade Flutter or add packages on your own. Agree as a team first, and update the version table above if it changes.

---

## Backend API

The app talks to the same API as the AgriLink website. No backend code lives in this repository. It's in [AgriLink_SriLanka](https://github.com/Razni-Ahamed/AgriLink_SriLanka).

| | URL |
|---|---|
| Live API | https://agrilink-api-sl.azurewebsites.net |
| API docs (Swagger) | https://agrilink-api-sl.azurewebsites.net/swagger |
| Website | https://green-glacier-04e1ebf00.1.azurestaticapps.net |

- The API is on a free hosting tier, so **the first request after it has been idle can take several seconds**. That's why the app needs proper loading states.
- To use a backend running on your own computer from the **emulator**, use `http://10.0.2.2:5266`, not `localhost`. Inside the emulator, `localhost` means the emulator itself.
- Photo uploads are limited to **5 MB** and **JPEG, PNG or WebP**. The app shrinks photos before uploading them.

---

## Authors

- **Razni Ahamed M. R.**
- **Gayathri M. G. K.**
- **Jayaweera A. D. J.**
- **Fernando C. P. H. A. C.**

---

## Licence

**Copyright © 2026 Razni Ahamed M. R., Gayathri M. G. K., Jayaweera A. D. J. and Fernando C. P. H. A. C. All rights reserved.**

This is **not** open-source software. The repository is public so that it can be viewed. No permission is granted to copy, modify, distribute or publish the code or the app, or to present any part of it as your own work. That includes submitting it for any academic assessment. See [`LICENSE`](LICENSE) for the full terms.
