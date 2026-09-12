# Komodo Go 0.6.0 release readiness

Audit date: 2026-09-12. Candidate branch: `codex/release-0.6.0`.

Recommendation: simulator findings are fixed in PR [#45](https://github.com/Brubytes/komodo-go/pull/45); see the [interactive QA report](qa/0.6.0-simulator.md). Ready for a signed release candidate after final CI verification. Public release remains gated on Codemagic verification, device upgrade/smoke checks, and store staging/validation.

## Where we left off

- iOS 0.5.4, build 6, is ready for distribution in App Store Connect. The latest GitHub release is also v0.5.4. There is no active App Store review submission.
- PR [#41](https://github.com/Brubytes/komodo-go/pull/41) merged advanced resource creation/editing, batch actions, update controls, searchable logs, server monitoring, container controls, and Ops Pulse into main on August 28.
- Commit `3701c9a` prepared version `0.6.0+12`, App Store metadata, curated release notes, and release-helper support on August 29. It had not been pushed or released.
- PR [#42](https://github.com/Brubytes/komodo-go/pull/42) contains the Flutter 3.47.2 / Dart 3.13.2 migration. Its GitHub CI passed, but the PR is still open. Its commit is now merged into this local release branch.
- Dependabot PR [#44](https://github.com/Brubytes/komodo-go/pull/44) is also open. Its September 7 CI failed during dependency resolution because main still used Dart 3.12.2 while the new lint package requires Dart 3.13.
- The sole open feature issue is [push notifications #25](https://github.com/Brubytes/komodo-go/issues/25); this remains outside 0.6.0.

## Release preparation completed

- Integrated #42 with the existing release preparation.
- Updated Riverpod/Flutter Riverpod/Hooks Riverpod to 3.4.3, annotations to 4.0.7, generator to 4.0.9, Freezed to 4.0.1, Build Runner to 2.16.1, Dio to 5.11.1, and Lucide icons to 3.1.19. Image 4.9.2, Patrol 4.9.0, and Test API 0.7.12 came from #42.
- Updated Android Gradle 8.12 to 8.14.3, Android Gradle Plugin 8.9.1 to 8.11.1, and Kotlin 2.1.0 to 2.2.20. The first native build demonstrated that the old versions are below Flutter 3.47.2's supported minimums.
- Preserved Flutter's required iOS deployment-target migration to 15.0 and refreshed the CocoaPods lockfile. The compiled app reports MinimumOSVersion 15.0. This drops iOS 13/14 support; the release notes now state the requirement. Android remains API 24 minimum / API 36 target.
- Enforced `pubspec.lock` in GitHub Actions and all four Codemagic workflows.
- Added analysis and unit/widget tests to both signed RC workflows.
- Made build scripts fail immediately on failed store lookups or invalid build numbers, before attempting a build.
- Renamed `negative_contract_tests.dart` to `negative_contract_test.dart` so Flutter and the serial backend helper discover its four tests automatically.
- Corrected the stale Flutter version in the repository guidelines.

## Dependency decisions

| Deferred update | Release decision |
| --- | --- |
| flutter_secure_storage 10.3.1 to newer releases | Keep the explicit pin and Darwin implementation 0.3.2. Existing legacy-read and duplicate-keychain-item regression tests pass. A new native migration needs device upgrade coverage. |
| go_router 17.5.0 to 18.0.1 | Keep the already-tested navigation version. Version 18 migrates its UI dependencies; validate that migration separately. |
| very_good_analysis 10.3.0 to 11.0.0 | Defer the new lint rules and associated syntax/formatting migration. Current analysis is clean. |
| skeletonizer 2.1.3 to 3.0.0 | Defer the major UI dependency upgrade. |
| test_api 0.7.12 to 0.7.14 | Keep the version resolved by the pinned Flutter SDK. |
| super_native_extensions Git override | Keep the exact revision `1d413d5e333058ed90274e44ac703c9d96f4e567`; upstream issue #548 remains open. Do not remove the workaround based only on the package changelog. |

The September 12 pub.dev audit reported no advisory-affected, retracted, or discontinued packages in its results. GitHub returned no open Dependabot security alerts. These are package-advisory checks, not a complete security audit.

Package references: [Dio changelog](https://pub.dev/packages/dio/changelog), [Freezed changelog](https://pub.dev/packages/freezed/changelog), [GoRouter changelog](https://pub.dev/packages/go_router/changelog), [Very Good Analysis changelog](https://pub.dev/packages/very_good_analysis/changelog), [native page-size issue](https://github.com/superlistapp/super_native_extensions/issues/548).

## Verification

| Check | Result |
| --- | --- |
| Dependency resolution with `--enforce-lockfile` | Passed |
| Riverpod, Freezed, JSON code generation | Passed; 173 outputs generated |
| `fvm flutter analyze` | No issues |
| `fvm flutter test` | 484 passed; 43 live-backend tests skipped without environment variables |
| Live contracts against dedicated local Komodo 2.3.1 | 43 passed, zero failures/skips: 39 directory-discovered tests plus 4 explicitly run error-path tests before the filename fix |
| iOS release compilation, unsigned | Passed with local Xcode 26.6; Runner.app, 31.9 MB |
| Android release bundle | Passed; app-release.aab, 71.1 MB |
| Android 16 KB native ELF alignment | All 12 ARM64/x86-64 libraries pass PT_LOAD alignment/congruence checks in the final bundle; runtime behavior and Play-generated APK packaging still require the RC/device checks |
| Codemagic shell/YAML checks | All shell blocks parse; 14 mocked tag/build-number scenarios pass |
| Metadata lengths, JSON, release-helper shell syntax, whitespace | Passed |
| TestFlight submitted crash reports | None returned |
| TestFlight feedback | One older request for stack creation, addressed by 0.6.0's creation workflows |

The live backend was confirmed through Docker Compose labels to belong to the dedicated `komodo_test` project, running on localhost:9121. Its configured reset/restore harness was used; no production backend was tested.

## Remaining release gates

1. Review and merge the combined release branch into main. #42's changes are included; reconcile its PR accordingly. #44 is only partly superseded: GoRouter 18 and Very Good Analysis 11 remain deferred.
2. Create `rc-0.6.0-1` on the merged commit to run both Codemagic signed verification workflows. Codemagic uses Xcode 26.2, so local Xcode 26.6 compilation does not replace this check.
3. Verify the installed candidate on a real device: upgrade from 0.5.4 with saved credentials; cold start and connection switching; create/edit/copy a disposable stack; batch action results and refresh; log search and update output; read-only permission errors; background/resume. Run on iPhone and Android, including a 16 KB Android environment. The Patrol device suite and this manual smoke pass have not been run in this audit.
4. After both RC workflows and device checks pass, create `v0.6.0` at the same tested source commit. Codemagic publishes Android to alpha and iOS to the External TestFlight group. It does not submit the iOS version to App Store review. Build numbers are queried again at publishing time; the pubspec `+12` is not the published build number.
5. Once the Codemagic build is processed, stage `metadata/version/0.6.0`, attach the intended build, then run `asc validate --app 6758161017 --version 0.6.0 --platform IOS --strict --output table` and resolve its findings before submission. Today's validator cannot validate 0.6.0 because the App Store version does not exist yet.

Google Play's live console state, Codemagic signing credentials, App Privacy publication, and final 0.6.0 store metadata/screenshots have not been verified. Existing native plugins still use CocoaPods, and Flutter warns that the selected Android toolchain will need a future major upgrade; neither warning blocked the successful checks recorded above.

PR #45 now contains the combined release preparation and simulator QA fixes. The branch has been pushed; no merge, tag, store metadata, build upload, or release has been published.
