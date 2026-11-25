# Publishing the web demo on Cloudflare Pages

The portfolio demo is the **Flutter web build** of this app, hosted on
**Cloudflare Pages only** — not Render, not Vercel.

> Do not deploy from this repo's CI or from a script here. The publish step
> is done by the owner in the Cloudflare dashboard (see below). This file
> only documents the exact build so the publish is a copy-paste job.

## 1. Build the web version

```bash
flutter build web --release
```

Exact output directory: **`build/web/`**

That folder is a complete static site (`index.html` + `main.dart.js` +
assets). It is the only thing Cloudflare needs — no server, no functions.

Verify locally before publishing:

```bash
cd build/web && python3 -m http.server 8000
# open http://localhost:8000 — the login screen appears with
# "Try the demo — no password needed"
```

On the web build, screen time and focus lock show clearly-labelled demo
data (a browser cannot read Android UsageStats), and the demo button is
the intended entry point — no real account needed.

## 2. Create the Pages project (dashboard, one time)

1. Cloudflare dashboard → Workers & Pages → Create → Pages → Upload assets
   (or connect the GitHub repo — see §3).
2. Project name: `self-improvement-app` (the demo will live at
   `https://self-improvement-app.pages.dev`).
3. Upload the contents of `build/web/` (or point the project at that
   folder if connecting git).

## 3. If connecting GitHub (recommended for updates)

- Build command: `flutter build web --release`
- Build output directory: `build/web`
- Root directory: `/` (repo root)
- The repo has no build system configured for Pages yet — the Flutter SDK
  must be available in the build image. If Cloudflare's image lacks
  Flutter, keep using **direct uploads** (§2) instead: build locally, drag
  the `build/web/` folder into the dashboard. That is the reliable path
  until a Pages build image with Flutter is set up.

## 4. SPA fallback (deep links)

Flutter web is a single-page app: every route serves `index.html`.
This repo ships `web/_redirects`, which Flutter copies into `build/web/`:

```
/*  /index.html  200
```

Cloudflare Pages honours `_redirects`, so refreshing on any route still
loads the app instead of a 404.

## 5. After publishing

- The demo link goes on the portfolio next to the GitHub link.
- Rebuild + re-upload `build/web/` whenever v1 changes; there is no
  auto-deploy until §3's git connection is set up.
- The demo is read-only by construction (see `SECURITY.md` §5) — visitors
  cannot change any real data from the public link.
