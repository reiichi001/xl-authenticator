# Changelog

AltStore shows the update notes for a version out of this file: the release
workflow extracts the section matching the release tag and writes it into that
version's `localizedDescription` in `altstore.json`. So each released version
wants a `## <version>` section here. A missing one only produces a workflow
warning and a generic note, so prose can never be what breaks a release.

## 1.0.8

Fixes the two things that were wrong on the main screen, and matches the app's
colours to the logo.

The countdown bar under your OTP now tracks the code exactly: it starts full as
the code appears and empties as it expires, instead of finishing about a second
and a half early. The bar and the code both read the same clock, so they can no
longer disagree.

The "Resend to XL" button barely had a background in either mode and read as
plain text, and the progress bar was drawn in a single flat colour that made it
look frozen - both were Material 3 colour roles that the old theme never set.
Both themes are now built from a single colour, taken from the logo, so the app
bar, the button and the bar all match it in light and dark mode.

## 1.0.7

Dependency bump release, plus an AltStore install fix.

The IPA published for AltStore is now shipped unsigned, which is what AltStore
needs in order to re-sign it with your own certificate at install time. It was
previously fakesigned before packaging, and iOS rejected the result during
install with "a signed resource has been added, modified, or deleted". A
fakesigned copy is still attached to the release as
`xl-authenticator-iOS-fakesigned.ipa`, for jailbroken devices.
