# Privacy Policy — Al Quran

**Al Marfa Technologies** · Effective 3 July 2026

> **Published (canonical) version:** the live policy — shared by Al Quran and
> Sharah Kitab at-Tawheed — is hosted at <https://kitabattawheed.com/privacy/>
> (source: `Al-Tawheed-Web/src/pages/privacy.astro`). **That is the URL to enter
> in the app stores.** This file is the Al-Quran-specific working draft, kept for
> reference; keep the two in sync if either changes.

Al Quran is an offline Qur'an reading app. It was built so that **your reading
stays private**: there are no accounts, no analytics, no advertising, no
trackers, and no servers of ours that your data could be sent to.

## The short version

- We collect **nothing**. No personal data leaves your device to us — we have
  no backend.
- Everything the app remembers (your last-read verse, font size, script and
  translation choices, reading-light preference) is stored **only on your
  device**.
- Your **location never leaves your device** — it is used only to calculate
  prayer times locally.
- The only network activity is the **optional audio recitation**, streamed
  from a third-party CDN when you tap play.

## What the app stores on your device

To make reading comfortable, the app keeps small preference files locally:
your last-read position, font sizes, script (Uthmani/IndoPak) and translation
choices, reading-light setting, reminder settings, and downloaded/cached
recitation audio. This data stays in the app's private storage, is never
transmitted to us or anyone else, and is deleted when you uninstall the app.

## Location (prayer times)

If you use prayer times, the app asks for your device's location. Prayer
times are calculated **entirely on your device**; your location is not sent
to any server. If you decline the permission, the rest of the app works
normally.

## Notifications & reminders

Sunnah reminders and prayer-time notifications are **local notifications**,
scheduled and shown by your device itself. On Android the app may request the
exact-alarm capability so reminders fire at the precise minute. No reminder
data leaves your device.

## Audio recitation (the one online feature)

Recitation (Mishary Rashid Alafasy) is streamed from **islamic.network**, a
free Islamic-services CDN, and cached on your device so replays work offline.
When you tap play, your device requests the audio file directly from that
CDN — like any web request, the CDN's servers see your IP address and which
verse files were requested. We receive nothing. If you never use audio, the
app makes no network requests at all.

islamic.network is operated by a third party; its own practices are described
at <https://islamic.network>.

## Sharing verses

The "share" feature hands the verse text to your device's standard share
sheet. Content goes only to the app **you** choose, and we never see it.

## What we don't do

- No analytics or crash-reporting SDKs.
- No advertising, no ad identifiers.
- No accounts, sign-ins, or cloud sync.
- No selling, sharing, or processing of personal data — we never receive any.

## Children

Al Quran is suitable for all ages. Because the app collects no data, it
collects no data from children.

## Data deletion

All app data lives on your device. Uninstalling the app removes it
completely. There is nothing to delete on our side.

## Changes to this policy

If a future version of the app changes any of the above (for example, a new
online feature), this policy will be updated and the "Effective" date revised
before that version ships.

## Contact

**Al Marfa Technologies** · <https://almarfa.co> · <hello@almarfa.co>
