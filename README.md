# Release v6.9.55

This branch contains the release of version **v6.9.55**.

## Contents

- **original_bundle.zip** – a copy of the original bundle archive.  Keeping this file makes it easy to inspect the initial state of the project for any historical debugging.
- **diff-6.9.54-to-6.9.55.patch** – a unified diff showing all changes made between v6.9.54 and v6.9.55.  This allows for quick review of the upgrade without digging through Git history.
- **v6.9.55.sh** – the script used to perform this upgrade.  Having the script alongside the changes makes it easier to reproduce or debug the process.
- **cleanup_report_v6.9.55.txt** – records every file removed or renamed during the upgrade.
- **lint_report_v6.9.55.txt** – output from the linting pass on Python and shell scripts.
- **21-policies_v6.9.55.txt** – defines the policies enforced during this upgrade.

## Summary

This branch was created from the previous version tag `v6.9.54`.  All version strings were updated to `6.9.55`, duplicate artefacts were removed, and new artefacts were suffixed with `_6.9.55`.  A fresh lint was run, and the upgrade script committed the changes on this branch and pushed both the branch and the tag `v6.9.55` to the remote.  See `diff-6.9.54-to-6.9.55.patch` for the exact code changes.
