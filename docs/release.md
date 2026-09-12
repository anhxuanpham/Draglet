# Release procedure

[scripts/draglet.sh](../scripts/draglet.sh) owns building, universal Release architectures, packaging, signing, notarization, verification, and checksums. [project.yml](../project.yml) owns the minimum OS, bundle identifier, version, and Hardened Runtime configuration. Keep generated [Draglet.xcodeproj](../Draglet.xcodeproj) in sync with the manifest.

Run tests, inspect the native workflow, and review the [manual acceptance requirements](manual-testing.md) before distributing a release. A green build alone does not satisfy those requirements.

`bash scripts/draglet.sh package` produces an ad-hoc-signed local ZIP and DMG. The `-local` filename is deliberate: this is a development artifact and is not Apple-notarized. The script verifies archive integrity and code-signature consistency, which is different from Gatekeeper distribution approval.

For distribution, install your **Developer ID Application** certificate in Keychain, then create a named `notarytool` keychain profile using Apple's credential-storage workflow. Credentials must stay outside this repository. Use the actual identity and stored profile name:

```sh
bash scripts/draglet.sh release 'Developer ID Application: YOUR NAME (TEAMID)' 'YOUR_NOTARY_PROFILE'
```

The script stops unless Apple returns **Accepted**, staples and validates tickets, and checks the signed app with Gatekeeper. It writes submission results next to the packages. It never uploads artifacts to a public hosting service.

An Apple Development identity is sufficient for local development but is not a replacement for Developer ID distribution. If no Developer ID identity/profile is available, leave notarization and public release pending.

App-icon artwork is reproducible with `bash scripts/draglet.sh icon`; the rendered assets are included so building does not depend on icon generation.
