
### 🚀 Improvements
- **Always-Visible Home Widgets**: Both **Tasks & Notes** and **Finances** widgets now stay live and visible on your home screen even when App Lock or Lock Finances Tab is active (matching Google Keep and WhatsApp), while opening the app still requires authentication.
- **Refined Tasks & Notes Widget Layout**: Replaced heavy header dividers with airy spacing, refined header pill proportions, and styled task items as rounded tonal cards.

### 🐛 Fixes
- **Instant Checklist Switching & Edge-to-Edge Picker**: Fixed checklist rows not responding to taps in the `Select Checklist` dialog, eliminated black bars around the dim scrim, and replaced the sideways slide with a smooth fade-and-scale modal transition.
- **Reliable Task & Checkbox Taps on Android 12–16**: Switched inline `RemoteCollectionItems` to `PendingIntentTemplate` + fill-in intents so checking off tasks and opening notes from the widget work reliably across Android 12–16.
- **Finance Widget Cold-Start Sync**: Fixed Finance widgets showing as locked or disabled after changing lock settings or on cold launcher refreshes.

