# Release Packaging

The packaging scripts produce checksummed bootstrap artifacts. Public intern distribution additionally requires platform signing.

## Release prerequisites

1. Update `VERSION` and platform-facing version strings.
2. Run the validation suite.
3. Commit the release source with a clean working tree.
4. Create an annotated `v<version>` tag at that commit.
5. Build from that exact tag. Builders reject dirty or untagged release trees.
6. Sign artifacts and verify signatures.
7. Regenerate the `.sha256` file from the final signed/notarized artifact, then publish each asset once with its source commit.

For local packaging tests only, set `FOAD_ALLOW_UNTAGGED_BUILD=1`.

## Windows EXE

From Windows PowerShell at the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\packaging\windows\build-windows-exe.ps1
```

Outputs:

```text
dist\windows\FOAD-Dev-Setup-Windows.exe
dist\windows\FOAD-Dev-Setup-Windows.exe.sha256
```

The wrapper runs as the signed-in user; only individual vendor installers may request elevation. This preserves the intern's `$HOME`, Desktop, Claude configuration, and log location even when separate administrator credentials are required.

Sign the EXE with an Authenticode certificate and timestamp the signature before publishing. Do not instruct interns to bypass SmartScreen for an unverified build.
Because signing changes the EXE, regenerate its `.sha256` file afterward.

## macOS DMG

From macOS at the repository root:

```bash
./packaging/macos/build-mac-dmg.sh
```

Outputs:

```text
dist/macos/FOAD-Dev-Setup-macOS.dmg
dist/macos/FOAD-Dev-Setup-macOS.dmg.sha256
```

Use Developer ID signing and Apple notarization before publishing. Do not describe an unsigned artifact as safe or ask interns to bypass Gatekeeper without independent checksum verification and supervised review.
Because signing/notarization can change the DMG, regenerate its `.sha256` file afterward.

The current raw `.command` launcher is suitable only for supervised preview builds. For a warning-free public release, replace it with a proper Developer ID-signed application bundle (or signed installer package), enable hardened runtime where applicable, notarize/staple the enclosing artifact, and test it after applying quarantine.

## Publishing

Release notes must include:

- version and full Git commit;
- SHA-256 values;
- supported Windows/macOS versions and architectures;
- tested account/elevation scenarios;
- known manual fallback steps.

Do not replace release assets after publication. Publish a new version for every artifact change.
