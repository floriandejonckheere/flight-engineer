# Agent instructions

Flight Engineer is a macOS menu bar app and desktop widget that monitors
GitHub Copilot credit usage. See `README.md` for the architecture and how the
forecast works.

## Development

- `make test` runs the unit tests of `Packages/FlightEngineerKit`.
- `make install` builds a release version and installs it to `/Applications`.
- `project.yml` is the source of truth for the Xcode project; never edit
  `FlightEngineer.xcodeproj` directly. Run `make generate` after changing it.
- Keep `README.md` in sync when changing user-facing behavior, such as the
  forecast calculation.

## Releasing

Only release when asked to. Releases are published from `main` with:

```sh
bin/release <major.minor.patch>
```

The script runs the tests, tags and pushes `v<version>`, waits for the release
workflow (`.github/workflows/release.yml`) to publish the archive, and updates
the cask in `floriandejonckheere/homebrew-flight-engineer`. Commit and push all
changes before running it, as it refuses a dirty or unpushed `main`. It takes a
few minutes, so run it with a generous timeout.

If the workflow fails after the tag was pushed, fix the cause, then delete the
tag locally and remotely (`git tag -d v<version>`,
`git push origin :refs/tags/v<version>`) along with any draft release before
running the script again.
