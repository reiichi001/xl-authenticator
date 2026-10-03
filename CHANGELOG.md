# Changelog

AltStore shows the update notes for a version out of this file: the release
workflow extracts the section matching the release tag and writes it into that
version's `localizedDescription` in `altstore.json`. So each released version
wants a `## <version>` section here. A missing one only produces a workflow
warning and a generic note, so prose can never be what breaks a release.

## 1.0.7

Dependency bump release, plus an AltStore install fix.

The IPA published for AltStore is now shipped unsigned, which is what AltStore
needs in order to re-sign it with your own certificate at install time. It was
previously fakesigned before packaging, and iOS rejected the result during
install with "a signed resource has been added, modified, or deleted". A
fakesigned copy is still attached to the release as
`xl-authenticator-iOS-fakesigned.ipa`, for jailbroken devices.
