# Game Jam Publisher & itch.io Submission Checklist

A battle-tested blueprint for packaging, optimizing, and releasing Godot 4 web games to itch.io with zero last-minute panic.


## 1. itch.io Game Page Embed Settings

When configuring your game page on itch.io under **Edit Game**:

**Kind of project** - `HTML` This ensures the in-browser player iframe activates.
Upload your .ZIP game file.
Check the `This file will be played in the browser` box.  This prevents it from being downloaded and loads **THIS** zip file into the iframe to be played as you can have multiple files uploaded.

**Pricing**, select `$0 or donate` or `No Payments`. 
	- The Tip Jar only shows for downloads, never on web playable games.  Jam games should be `No Payments`.

Under Embed Options:

** Embed in Page ** - `Manually Set Size`

**Viewport dimensions** - `1280` width × `720` height.  This matches standard 16:9 widescreen layout without letterboxing and what the template uses by default.  Change to your resolution if different.

**Frame options** Check `Fullscreen button` as this allows players to expand to full monitor with one click.


## 2. Storefront Visual Assets & Dimensions

First impressions determine whether jam raters click your submission.

**Cover Image / Thumbnail**: `630 × 500 px` (5:4 aspect ratio) or `315 × 250 px`.
	HIGHLY Suggested with high contrast, large legible title, and no tiny unreadable text. 
	A `.png` under 2MB significantly increases click-through rate.
**Banner Image**: `960 × 400 px` 
	Optional, but it causes players to scroll down the page to get to game, so I'd skip it for jams.
**Screenshots**: At least 3 to 5 in-game action screenshots captured at `1280 × 720` or higher.
	Highly Suggested as they show up in the Jam Submission feed and can bring in players.


## 3. Web Export Safeguards (The "Why is my game broken?" FAQ)

### A. The Web AudioContext Lock
**The Problem**: Modern browsers (Chrome, Safari, Edge, Firefox) block all audio until the user has performed a direct user interaction (pointer click or keypress) inside the iframe.
**The Fix**: This kit includes `scenes/menus/click_to_start.tscn` as the main project scene. It captures the initial click, cleanly unlocks browser audio, and transitions into `main_menu.tscn`.

### B. SharedArrayBuffer & Cross-Origin Isolation (CORS)
**The Problem**: If your game exports with multi-threading enabled, browsers require 
`Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` HTTP headers. 
Without them, the game crashes on load with a black screen and `SharedArrayBuffer` errors in the developer console.
**The Fix**: In `export_presets.cfg`, `variant/thread_support=false` is set. Single-threaded export runs seamlessly on itch.io without requiring special server headers!

### C. ZIP Structure
When zipping your web build, ensure `index.html` is at the **root of the ZIP archive**, not inside a nested subdirectory:
  ```
  my_game_web.zip
  ├── index.html        <-- MUST BE AT ROOT
  ├── index.js
  ├── index.pck
  └── index.wasm
  ```

## 4. Audio Ear-Safety & Sound Mix Audit

**Master Bus Ceiling**:
`default_bus_layout.tres` sets Master bus to `-6.0 dB` by default.
Never ship a jam game at `0 dB` or boosted master, as it causes painful headphone blast when players click into your page.

**SFX Limiting**:
Verify that rapid projectile impacts or multi-enemy explosions do not stack audio volumes exponentially.
`AudioManager.gd` includes an automatic 45ms concurrency limiter.


## 5. The 60-Minute Pre-Submission Triage
Complete this checklist at least 1 hour before the jam deadline:

[ ] **Quick Restart Test**: Press `R` in the middle of gameplay to verify instant level reload without memory leaks or missing node crashes.
[ ] **Quit Button Visibility**: Verify that the "Quit" button is hidden when running in the browser.
[ ] **Credits Check**: Confirm your team names, third-party asset licenses, font credits, and jam name are listed in `credits.txt`.
[ ] **How-To-Play Guide**: Ensure controls are accessible directly from the pause menu and main menu.


## 6. Post-Jam Devlog & Community Retention

**Write a Post-Mortem**: Publish a devlog on itch (or YouTube) within 48 hours detailing:
   - What went right
   - What broke 
   - What features were cut
   `This is more for your own reflection and learning from the Jam.`

**Rate 10+ Jam Entries**: Leaving constructive, thoughtful feedback on other jammers' games is the #1 organic driver of ratings and visits back to your submission.

**Link Your Video Series**: Add a clear link in your game description to your YouTube devlog or tutorial series covering how you built the systems. This is how you start to build an audience.
