# SnapLedger legal documents

Canonical (editable) copies of public legal pages live in this folder:

- [privacy.html](privacy.html) — Privacy Policy
- [terms.html](terms.html) — Terms & Conditions

The app opens the **hosted** versions via in-app Safari:

- Privacy: `https://cgokul06.github.io/snapledger-legal/privacy.html`
- Terms: `https://cgokul06.github.io/snapledger-legal/terms.html`

URLs are defined in `src/Xpnse/Legal/LegalDocument.swift`.

## Why a separate public repo?

The main SnapLedger app repository is private. GitHub Pages for private repos requires a paid plan, so legal pages are published from the public repo [`cgokul06/snapledger-legal`](https://github.com/cgokul06/snapledger-legal).

Local working copy of that site (if present): `~/Desktop/snapledger-legal`

## How to update and republish

1. Edit `docs/privacy.html` and/or `docs/terms.html` in this repo (source of truth).
2. Copy the updated files into the public site repo:

```bash
cp docs/privacy.html docs/terms.html ~/Desktop/snapledger-legal/
```

3. Commit and push the public site:

```bash
cd ~/Desktop/snapledger-legal
git add privacy.html terms.html
git commit -m "Update legal documents."
git push origin main
```

4. Wait a minute for GitHub Pages to rebuild, then verify the live URLs.
5. Commit the same HTML changes in this app repo so history stays in sync.

If you later move to a custom domain, update the pages and `LegalDocument.swift` URLs together.
