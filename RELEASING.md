# Releasing

## Normal flow

1. Pull requests are squash-merged; the PR title (Conventional Commits) becomes
   the commit message. The title type decides the version bump of the package
   whose files changed:

   | Change | Title | Before 1.0.0 | From 1.0.0 |
   |---|---|---|---|
   | enable a lint rule, raise the minimum SDK, breaking CLI change | `feat(lints)!: …` | minor | major |
   | disable a rule, add a file, new CLI feature | `feat(…): …` | patch | minor |
   | fix, reasons, documentation | `fix(…): …` | patch | patch |
   | CI, tooling | `chore: …`, `ci: …` | no release | no release |

2. Release Please keeps one release PR per package. Merging it tags
   `<package>-vX.Y.Z` and creates a GitHub release.
3. The tag starts `publish-<package>.yml`: it checks that the tag matches
   `pubspec.yaml`, waits for approval in the `pub.dev` environment and
   publishes through pub.dev automated publishing (OIDC, no stored token).

## One-time setup

Do these in order; until step 4 the Release Please and new-lints workflows
are skipped.

1. **Verified publisher** `devimobile.pl` on pub.dev, created from the company
   Google account (DNS TXT record via Google Search Console, domain property).
2. **First release by hand**, from the `main` commit that contains 0.1.0
   (pub.dev enables automated publishing only for existing packages):

   ```sh
   (cd packages/devimobile_devkit_lints && dart pub publish)
   (cd packages/devimobile_devkit_cli && dart pub publish)
   (cd packages/devimobile_devkit_rules && dart pub publish)
   ```

   Then, on pub.dev, transfer the packages to the `devimobile.pl` publisher.
3. **Baseline for Release Please**: create a GitHub release for each 0.1.0 on
   that same commit, so Release Please starts from there instead of proposing
   0.1.x for the whole history:

   ```sh
   gh release create devimobile_devkit_lints-v0.1.0 --target <sha> --title "devimobile_devkit_lints 0.1.0" --notes "Initial release."
   gh release create devimobile_devkit_cli-v0.1.0 --target <sha> --title "devimobile_devkit_cli 0.1.0" --notes "Initial release."
   gh release create devimobile_devkit_rules-v0.1.0 --target <sha> --title "devimobile_devkit_rules 0.1.0" --notes "Initial release."
   ```

   The new tags start the publish workflows, which fail at publishing because
   0.1.0 already exists (or automated publishing is not enabled yet); that is
   expected.
4. **GitHub App** `devimobile-bot` (ADR-009 in the starter kit) installed on
   this repository, with `contents`, `pull-requests` and `issues` write. Add
   the organization variable `BOT_APP_CLIENT_ID` (the App's client ID) and the
   secret `BOT_APP_KEY` (its private key).
5. **pub.dev automated publishing**, for each package (Admin tab):
   repository `DeviMobile/devkit`, tag pattern `<package>-v{{version}}`,
   require GitHub Actions environment `pub.dev`.
6. **GitHub environment** `pub.dev` with required reviewers and deployments
   limited to tags `devimobile_devkit_*-v*`.
7. **Branch protection** on `main`: require the checks `Format, analyze,
   generated files`, `Tests (ubuntu-latest)`, `Tests (macos-latest)`,
   `Minimum Dart SDK`, `Lint catalog of the latest stable SDK`,
   `Publish dry run and pana` (every package) and `Conventional Commits title`;
   allow squash merge only, with the PR title as the commit message.
