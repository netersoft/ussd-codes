"""Captures the raw screens for the Play Store screenshots, in one language.

Starts from a fresh install on the shared `test-phone` emulator (1080x2400),
with SystemUI demo mode on (see README.md). The emulator has no SIM, so the
app opens on Benin, the first country of the catalog.

    python3 tool/store_screenshots/capture.py <out_dir> <lang>

Writes <out_dir>/<lang>/<screen>.png for the screens listed in config.json.
"""

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from adb_ui import adb, find, hide_keyboard, labels, ocr, screen, tap  # noqa: E402

PACKAGE = 'com.neteru.mobileussdcodex.dev'
LOCALES = {'en': 'en-US', 'fr': 'fr-FR'}
# A made-up top-up voucher, and a search word found in every country.
VOUCHER = '482719035662'
SEARCH = {'en': 'money', 'fr': 'money'}
TOP_UP = {'en': 'Top up', 'fr': 'Recharge'}    # the label of Moov Africa Benin's top-up code

# The bottom navigation bar, left to right.
NAV = {'operators': 134, 'bundles': 404, 'favorites': 674, 'phone': 944}


def type_text(text):
    for c in text:
        adb('input', 'text', c)
        time.sleep(0.06)


def capture(out, lang):
    out = Path(out) / lang
    out.mkdir(parents=True, exist_ok=True)
    t = labels(lang)

    # Start from the home screen: a sheet left open by another app (a share
    # sheet, say) would catch the taps.
    adb('input', 'keyevent', 'KEYCODE_HOME')
    adb('pm', 'clear', PACKAGE)
    adb('cmd', 'locale', 'set-app-locales', PACKAGE, '--locales', LOCALES[lang])
    adb('monkey', '-p', PACKAGE, '-c', 'android.intent.category.LAUNCHER', '1')
    find(TOP_UP[lang], 40)                     # the code list is up
    time.sleep(1)

    # 1. The countries and their operators.
    tap(230, 206, 2)                           # the country name in the app bar
    find(t['chooseCountry'])
    screen().save(out / 'countries.png')
    adb('input', 'keyevent', 'KEYCODE_BACK')
    time.sleep(1.5)

    # 2. The codes of an operator.
    screen().save(out / 'codes.png')

    # 3. A code with a parameter: the code is built as the user types.
    # Tap the code itself: its label can match its section title ("RECHARGE"
    # above "Recharge" in French), so take the lowest matching line.
    rows = [(x + w // 2, y + h // 2) for x, y, w, h, text in ocr() if text.lower() == TOP_UP[lang].lower()]
    tap(*max(rows, key=lambda p: p[1]), 2)
    find(t['dial'])                            # the sheet with its Dial button
    type_text(VOUCHER)
    time.sleep(1)
    screen().save(out / 'dial.png')
    hide_keyboard()
    adb('input', 'keyevent', 'KEYCODE_BACK')   # close the sheet
    time.sleep(1.5)

    # 4. Data bundles of every operator, cheapest per GB first.
    tap(NAV['bundles'], 2220, 2.5)
    screen().save(out / 'bundles.png')

    # 5. Codes handled by the phone itself.
    tap(NAV['phone'], 2220, 2.5)
    screen().save(out / 'device.png')

    # 6. Search across every country.
    tap(NAV['operators'], 2220, 2)
    tap(888, 206, 2)                           # search
    type_text(SEARCH[lang])
    time.sleep(2)
    hide_keyboard()
    time.sleep(1)
    screen().save(out / 'search.png')
    adb('input', 'keyevent', 'KEYCODE_BACK')


if __name__ == '__main__':
    capture(sys.argv[1], sys.argv[2])
