# Contributing to Umbra

Thanks for your interest in improving Umbra. This guide covers how to
submit changes and, importantly, how contributions are licensed.

## Before you start

- Open an issue for anything larger than a small fix, so we can agree on
  the approach before you spend time on it.
- Keep pull requests focused. One change per PR is easier to review.
- Match the existing code style. This is a SwiftUI and WebKit codebase.

## Building and testing

See the Building section in the [README](README.md). Please confirm the
app builds and runs on a current iOS simulator before opening a PR.

## How contributions are licensed

This is the load-bearing part, so please read it.

Umbra is released under the Mozilla Public License 2.0. By submitting a
contribution, you agree that:

1. Your contribution is your own original work, or you have the right to
   submit it.
2. Your contribution is licensed under the MPL-2.0, the same license as
   the rest of the project.
3. You grant the maintainer (NorseHorse) a perpetual, worldwide,
   non-exclusive, royalty-free right to also distribute your contribution
   under other license terms, including as part of the official closed
   builds of Umbra distributed through the App Store.

Point 3 keeps it possible to ship an official App Store build and to
offer paid tiers, without needing to track down every contributor for
permission later. If you are not comfortable granting that, please do not
submit a contribution.

## Developer Certificate of Origin

Sign off your commits to certify the above. Add the `-s` flag when you
commit:

```
git commit -s -m "Your message"
```

This appends a `Signed-off-by` line using your git name and email, which
records your agreement to the Developer Certificate of Origin
(https://developercertificate.org/).

## Security issues

Please do not open a public issue for a security vulnerability. Report it
privately to the maintainer first, so it can be fixed before details are
public.
