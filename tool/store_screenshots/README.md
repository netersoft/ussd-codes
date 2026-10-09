# Play Store screenshots

`store/screenshots/<lang>/` holds the 6 phone screenshots of the store listing, one set per
app language: 1080×1920 (9:16) 24-bit PNGs, a white title over the app's green gradient and a
light-theme capture in a phone frame.

Operators appear by name only, as in the app (no logos). The top-up voucher number in the
third screenshot is made up.

## Regenerate them

1. Start the shared emulator (`test-phone`, 1080×2400) and install a fresh build:

   ```bash
   flutter build apk --profile --flavor dev
   adb install -r build/app/outputs/flutter-apk/app-dev-profile.apk
   ```

   The emulator has no SIM, so the app opens on Benin, the catalog's first country.

2. Clean status bar (10:00, full battery and Wi-Fi, no notifications):

   ```bash
   adb shell settings put global sysui_demo_allowed 1
   adb shell am broadcast -a com.android.systemui.demo -e command enter
   adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1000
   adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
   adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 -e fully true
   adb shell am broadcast -a com.android.systemui.demo -e command network -e mobile hide
   adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
   ```

3. In Gboard's settings (Text correction), turn off the suggestion strip and auto-correction;
   turn them back on afterwards.

4. Capture each language, then build the images:

   ```bash
   for lang in en fr; do python3 tool/store_screenshots/capture.py /tmp/captures $lang; done
   python3 tool/store_screenshots/compose.py /tmp/captures
   ```

5. Look at every image before uploading them, then exit demo mode
   (`adb shell am broadcast -a com.android.systemui.demo -e command exit`).

## How it works

- `config.json`: screen order, titles in each language, colors.
- `capture.py` drives the app with `adb`. Labels that move with the language are found by
  their text, read with macOS Vision (`ocr.swift`) and matched against
  `assets/i18n/<lang>.i18n.json`.
- `adb_ui.py`: taps, typing, keyboard detection and text lookup.
- `compose.py` builds the final images.
