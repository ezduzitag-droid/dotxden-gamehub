# Hard Time III — Floating Developer Menu: Implementation Handoff

**Date:** November 5, 2026  
**Purpose:** Transfer the exact menu design, build history, behavioral contract, Android integration risks, and a staged implementation plan to the separate ChatGPT session modifying the existing Hard Time III APK.  
**Status:** The floating menu exists as one functional **visual-only HTML file** in GitHub. **It has not yet been injected, compiled, or verified inside the game APK.**  
**Next milestone:** An **inert but working, draggable, transparent, in-game floating menu** over the playable CP004 build, without breaking Unity gameplay, touch controls or app startup.

> **IMPORTANT FOR THE RECEIVING SESSION:** Do not redesign this as a fullscreen dashboard. Do not treat the HTML demonstration values as real in-game state. Do not claim it works inside Unity IL2CPP until it has actually been integrated and tested. Read the current GitHub file first, preserve the original Lua, and continue from the existing CP004 playable APK baseline.

## 1. Source-of-truth files

| Resource | Exact location | Usage |
|---|---|---|
| **Current HTML — authoritative UI** | https://github.com/ezduzitag-droid/dotxden-gamehub/blob/main/data/ht3-control-studio.html | The single editable HTML source, with its CSS/JS/SVG inline. Keep updating this same file path rather than creating variants. |
| **Raw HTML** | https://raw.githubusercontent.com/ezduzitag-droid/dotxden-gamehub/main/data/ht3-control-studio.html | Fetch exact HTML asset bytes to embed in APK. |
| **Original GG script** | https://github.com/ezduzitag-droid/dotxden-gamehub/blob/main/data/node_6f2e9a.lua | Original GameGuardian developer menu **v2.1.1**; authoritative for behavior, field names and existing memory research. The script was NOT changed. |
| **This handoff** | https://github.com/ezduzitag-droid/dotxden-gamehub/blob/main/data/HT3_FLOATING_MENU_IMPLEMENTATION_HANDOFF.md | Integration instructions. |
| **Existing playable APK checkpoint** | Previously saved file named **HT3_CP004_2026-11-05_PLAYABLE_STARTUP_DEBUGGING_HANDOFF.md** | Read it in the other session for exact install/signing/backup and startup constraints. This document supplements, not replaces, CP004. |

Repository: **ezduzitag-droid/dotxden-gamehub**, branch **main**.

Source version hashes at the time of this handoff:
- HTML Git blob SHA: **014b3216b5eedf6701250cb58f0f78f614641cba**
- Original Lua Git blob SHA: **8cafcf9cbf2c8a97a46310054caa331d58c86a66**

Re-fetch the latest HTML before packaging an APK to avoid using a stale revision.

## 2. What the menu actually is

It is a **compact GameGuardian-style in-game interface prototype**, not a separate Android app. When embedded properly, only a draggable floating **III** icon should appear above the running game. Tapping the icon opens a narrow menu containing the original GG feature groups. The panel is black with glossy yellow-gold/brown accents, rounded rows, icons, translucent material, short labels and a small scrollable list.

**Everything outside the icon and menu is intentionally hollow and transparent.** The fake black gameplay mockup, HUD, joystick, reticle, simulated phone frame, title/watermark and decorative background were **removed** in the latest revision. The actual Unity game should be visible behind the icon.

The entire presentation is **one HTML file** using inline:
- CSS: styling, colors, panel, icon, responsive constraints, transparency.
- JavaScript: click handling, draggable icon, navigation, numeric sample editors, history and draft preservation.
- SVG symbols: all icons. No image URLs or graphics that must be separately supplied.
- Browser localStorage: optional persistence of sample values and menu page state.

**Not included:** Android Activity/WebView host code, APK/smali/Dex modification, game hooks, IL2CPP functions, JNI bridge, GameGuardian execution, real memory scanning/writing, spawning, production mod features, or actual Unity input routing. The HTML cannot simply execute inside **libil2cpp.so**. A renderer and native host integration are necessary.

### Seven GG top-level entries

1. **SETUP / RE-SCAN** — source Lua binding/validation status; HTML says NOT CONNECTED.
2. **EDIT HEALTH** — active player's live health (not the separate stored character health).
3. **EDIT SPIRIT / INJURY** — active actor state.
4. **EDIT ATTRIBUTES** — Reputation, Strength, Skill, Agility, Stamina, Attitude.
5. **EDIT MONEY** — Progress bank.
6. **EDIT SENTENCE / DAY / CLOCK / ALLOWANCE** — sentence days, day, hours, minutes, allowance.
7. **EXIT** — collapse back to floating icon.

The current HTML has **15 editable demo values** (1 health + 2 player-state + 6 attributes + 1 money + 5 progress). It also shows the sample health limit for context. These are **not actual game data**.

## 3. Required interaction contract

The final APK must reproduce these behaviors:

- Game starts into real landscape gameplay, with **only the small floating III icon** on top.
- Icon can be dragged; tapping it opens the same compact panel.
- Choosing a category opens its submenu; choosing a value opens a numeric editor.
- **Closing by tapping outside, tapping ×, tapping the icon or choosing EXIT must not reset the current page.**
- Reopening must return directly to the exact previous submenu or editor, NOT the main page.
- Any **unsubmitted numeric text** in an editor must be retained when the menu closes and reopens.
- Applying a value must leave the same editor open, so reopening returns to that editor.
- Back navigation differs from closing: editor → category → main.
- Menu is scrollable and constrained within landscape view bounds.
- The game behind the overlay remains visible, touchable and playable outside the interactive UI.
- Input tests must include joystick/action multi-touch and entering numbers with the soft keyboard.

**Concrete acceptance example:** Open Health → Live health → type 456 without applying → tap outside → tap floating icon → **the Live health editor reappears with 456 still typed**. This applies to every category/field, not just Health.

**Implementation warning:** The HTML already implements this behavior within JavaScript. However, when a native overlay routes touches outside the WebView, the Android host must call the close/dismiss action and not accidentally reset/recreate the HTML. A full-screen transparent WebView alone does NOT guarantee touch pass-through.

## 4. How we built it — chronological history

### Phase 1: Read original GG Lua

Reviewed **data/node_6f2e9a.lua** (GameGuardian Developer Controls v2.1.1). Identified the exact menu hierarchy and important distinction between **live actor health** and stored Character health. Catalogued Spirit, Injury, six Character.stat entries, money and Progress fields. The original Lua stayed unchanged.

### Phase 2: First glossy HTML dashboard

Created **data/ht3-control-studio.html** as a single GitHub file. The original visual direction referenced polished Apple-style glass surfaces and Instagram-like rounded controls and gradients. This first dashboard had side navigation, charts, panel views and sample values. It looked good but was **not appropriate for an in-APK floating menu**, because it resembled a separate full-screen application.

### Phase 3: Replace dashboard with GG-style floating design

Rebuilt that **same GitHub file** into a landscape prototype with:
- A draggable III icon, modeled after GG's floating tool bubble.
- A small menu next to the icon.
- Category rows / nested value editors / back / close / exit.
- Black, gold/yellow and brown glossy styling (replacing the pink/purple dashboard).
- A temporary black game mockup to check layout scale.

This still included decorative, fake game UI that might confuse future agents into thinking it was part of the intended APK overlay.

### Phase 4: Remove fake game scene and preserve state

At the user's request, modified the same HTML file again:

- Removed the entire fake game frame, gameplay background, joystick, reticle, fake HUD and decorative text.
- Made **html/body and overlay root transparent**. Only the floating icon and menu are permanent visible UI.
- Used **pointer-events: none** on the root and **pointer-events: auto** on icon/menu. This is DOM hit testing **only**, not guaranteed Android-level pass-through.
- Removed the previous instruction that reset the page to main whenever openMenu() ran.
- Added state retention of page, current field, unfinished numeric draft, and menu scroll position.
- Preserved the current editor after pressing Apply preview.
- Added optional **localStorage** persistence, so the browser can restore values/view state if configured.
- Exposed a small host-facing JS API for opening/closing menu, but NOT for controlling game memory.
- Re-fetched the final GitHub file and checked transparent markup, main groups, single-file assets, original Lua SHA and JS syntax.

GitHub milestones (commits):
- Initial dashboard HTML: **1c249c6980437c8edeeb0a80df92e746d9facb5e**
- GG-style floating redesign: **c0b203d9e532a09dcc00d035245331ae3155cab9**
- Follow-up HUD/layout correction: **acd2b187e02f026bd0a1e910458859b528d9a870**
- Transparent and page-preserving revision: **6f8ffa6da43486c2dd09c5df83981089745f9e2e**

The current GitHub **main** version supersedes all these earlier visual versions.

## 5. How the HTML code is organized

### Elements and CSS

| ID/class | Purpose |
|---|---|
| **#device / .overlay-root** | Fully transparent viewport-sized root; no game imagery inside it. |
| **#float / .float-icon** | Draggable III icon; tap to toggle menu; touch actions limited to it. |
| **#menu / .menu** | Compact overlay; rounded panel, gold trim, independent scrolling region. |
| **#menu-content** | Dynamic list of setup, categories, fields and numeric forms. |
| **#back, #close** | Back through navigation versus collapse menu. |
| **#menu-title** | Changes with current page. |
| **#toast** | Small transient status label for demo actions. Not a game HUD. |

Note: **#toast** is the only optional transient label outside the icon/menu. For an absolutely strict two-element production UI, move notices inside the menu or omit the toast; no external graphic replacement is involved.

### JavaScript state and persistence

| Variable | Meaning |
|---|---|
| **current** | Current page: main, setup, health, state, attributes, money, progress, edit. |
| **editing** | Which numeric field's editor is open. |
| **draftValue** | Text in editor not yet committed with Apply. |
| **lastScroll** | Menu scroll position. |
| **opened** | Panel visibility state. |
| **data** | Local **mock values only**, not Unity values. |
| **controls/groups** | Field labels, ranges, category mappings and navigation. |

Storage keys:
- **ht3-floating-control-studio-v1** — demo data.
- **ht3-floating-control-studio-v1-view** — page/field/draft/scroll.

Storage may be unavailable in a WebView or lost when data is cleared or an Activity is recreated. Keep a stable local asset origin, enable DOM storage if needed, and test the lifecycle. In-session state is maintained in JS, but **persistence across process death is not proven**.

### Current exported JS API

~~~javascript
window.HT3Overlay.open();       // open current page, not reset
window.HT3Overlay.close();      // close, preserve page and draft
window.HT3Overlay.toggle();     // toggle icon/menu
window.HT3Overlay.dismiss();    // same as close
window.HT3Overlay.getView();    // {page, field, draft, open}
window.HT3Overlay.getDemoValues(); // demo data only
~~~

The Android host can call these through WebView.evaluateJavascript() on the UI thread. There is **no game/native bridge** yet, and no exported method for actually changing Unity game values or spawning objects.

## 6. Actual APK project context — CP004 baseline

The following current APK facts were reported and verified in the **separate CP004 handoff**, not in the HTML-building session:

| Property | Baseline |
|---|---|
| APK game | **Hard Time III 1.1.8**, package **com.MDickie.HardTimeIII** |
| Runtime | **Unity 6000.3.25f1**, **ARM64 IL2CPP**, metadata v39. Not a Mono/Assembly-CSharp.dll mod. |
| Android activity | **com.unity3d.player.UnityPlayerGameActivity** (GameActivity variant; do NOT assume UnityPlayerActivity). |
| Package structure | **base.apk** (DEX/Android startup) + **split_0.apk** (UnityDataAssetPack) + **split_1.apk** (ARM64 native/config). |
| Playable checkpoint | **CP004**, a **development-signed, diagnostic no-ads** candidate. On physical Moto G Power 5G (2023), Android 14 ARM64, user confirmed entering actual gameplay, moving and interacting. |
| CP004 base.apk SHA-256 | **56cb395cf5c4dfcddb609e0a18d1f07b96b51cef31399d171ef2aed49f46c188** |
| split_0.apk SHA-256 | **33714f494c912ba82b4a4708312e04c27d6ea969f4f4742ca2cfe925b6c964c0** |
| split_1.apk SHA-256 | **b84a4766f4b5c2efa3d3db611044508b9df2208040c6f95305bb84d447c8d401** |
| Menu inside that playable APK? | **No.** The game boot and movement are verified, but no in-APK floating menu is integrated. |
| Important limitation | CP004 changed mediation initialization for **development-only startup diagnostics**; it is not a production ad setup. |

**Hard constraints for the next session:** Preserve the currently working CP004 build and original files; work on a separate copy; keep all **three split APKs**; sign consistently with the **development certificate**; do not install development-signed packages over mismatched Play/LDPlayer installs; do not create/clone more LDPlayer instances or repeat the old Stage 14.1/Pairip/Houdini crash workflow. The verified physical ARM64 device is the preferred test target.

The earlier GG pointer offsets, token validations and item-spawn native research live in CP001/earlier handoffs. Do not redetermine them from the HTML, which is only a front end.

## 7. Unity IL2CPP — actual runtime expectations

**Boundary:** Unity IL2CPP uses native compiled game code including **libil2cpp.so**; this HTML is **not** compiled native code. It requires an embedded **Android WebView** (or a fully native implementation of the visuals). Since the user wants to preserve these exact visuals without having to replace artwork, a **same-app WebView overlay in the APK** is the preferred first integration experiment, not another app and not a new standalone launcher.

Proposed architecture:

~~~text
Existing playable CP004 3-split APK (COPY)
  base.apk
    existing UnityPlayerGameActivity / DEX bootstrap [PRESERVE]
    new minimal Android overlay host [NOT YET IMPLEMENTED]
       transparent WebView above real Unity surface
       view bounds and native touch-routing management
       lifecycle handling and same-asset origin
       loads assets/ht3-control-studio.html [AUTHORITATIVE HTML]
          III floating icon
          GG-like panel
          sample editors / persistence
  split_0.apk [PRESERVE Unity content]
  split_1.apk [PRESERVE ARM64 native libs including libil2cpp.so]

After UI-only milestone is proved:
  UI action -> Android/JNI bridge -> carefully validated IL2CPP game action
  [game-native bridge, pointer resolver, actual stat edits and spawning PENDING]
~~~

### Potential interactions, risks and design decisions

**Visual alpha:** Transparent CSS alone does not make the Android WebView transparent. The native host must also set its WebView/window/surface backgrounds to transparent and ensure the Unity surface is underneath. The game must show through everywhere except the icon and panel.

**Touch routing — highest integration risk:** A full-screen transparent WebView can still eat every tap/multitouch gesture, even where DOM has pointer-events:none. Use an Android-native implementation that restricts the UI's touchable bounds to the icon/menu or carefully routes out-of-region touch events back to Unity. The host must still recognize an outside tap as a dismiss request. Do not globally mark the interactive window FLAG_NOT_TOUCHABLE; then the menu itself cannot be clicked. The Android 12+ untrusted-overlay rules also matter for cross-app windows; prefer a same-app view hierarchy instead of SYSTEM_ALERT_WINDOW / TYPE_APPLICATION_OVERLAY without need.

**Focus, keyboard, orientation:** Landscape numeric input may summon the soft keyboard, steal Unity focus, or resize the viewport. Test opening, typing, applying, closing, rotation/Activity recreation and resume. Test a mobile GPU renderer; browser-only appearance is insufficient.

**UI layering:** Attach after the game surface is created and keep it above the Unity view across resume/recreation. Avoid modifying the Unity engine initialization or forcing a new launcher Activity.

**Performance:** Static HTML is relatively simple, but one full-screen WebView can still affect memory and composition. Test on the physical ARM64 target and keep JavaScript idle when not used.

**Native game features:** No IL2CPP functionality exists in this HTML. Later native operations should be modeled on validated class/object pointers, loaded-library offsets, ASLR, field types, actor identity, game update/thread rules and real gameplay effects. A simulated change or memory readback is **not** proof of live health or item spawning.

### Official documentation to consult

- Unity 6 Android Activity guidance: https://docs.unity.com/en-us/engine/6000.5/manual/platform-specific/android/developing/application-entries/activity/unity-player-activity
- Android WebView/JavaScript: https://developer.android.com/develop/ui/views/layout/webapps/webview
- Android WebView reference (loadUrl, evaluateJavascript): https://developer.android.com/reference/android/webkit/WebView
- Android 12+ untrusted touch-through rules: https://developer.android.com/about/versions/12/behavior-changes-all
- Android WindowManager flags / touchability: https://developer.android.com/reference/android/view/WindowManager.LayoutParams

## 8. Staged implementation procedure for the receiving session

**Stage 0 — Freeze and verify the playable build.**
1. Make a separate CP004 working copy and record base/split hashes; preserve backups and user saves.
2. Verify the actual installed launcher Activity/manifest, DEX/smali structure, Unity view/surface and development signing.
3. Select a minimal integration point that does not change the verified CP004 boot sequence.
4. **Gate:** Untouched copy still launches actual gameplay; do not revisit already-solved startup crashes.

**Stage 1 — Embed the one HTML asset.**
1. Fetch current raw HTML from GitHub.
2. Put it into **base.apk assets**, suggested path **assets/ht3-control-studio.html**.
3. Do not change its SVG/CSS/JavaScript into different graphics or invent extra assets.
4. **Gate:** The asset is packaged intact, and only the intended base changes; Unity content/native splits remain unchanged.

**Stage 2 — Add minimal transparent Android host.**
1. Use Java/DEX/Smali in the existing APK's Android layer. The entry point is reported to be **UnityPlayerGameActivity**, so preserve its correct GameActivity lifecycle rather than assuming UnityPlayerActivity.
2. Create a WebView on the Android main/UI thread, give it a **transparent native background**, enable JavaScript and DOM storage as appropriate, and load the local HTML asset through a stable origin.
3. Attach it above the real Unity rendering surface. Only the III icon is initially visible.
4. Implement real **native input pass-through / constrained hit regions**. Test dragging icon and interacting with the game's joystick, action buttons and multitouch while the menu is closed/open.
5. Implement lifecycle cleanup and prevent duplicate views or focus lockout.
6. **Gate:** Real game is visible behind floating icon; menu opens; gameplay remains fully playable.

**Possible host APIs (illustrative, not a drop-in complete integration):**

~~~java
webView.setBackgroundColor(android.graphics.Color.TRANSPARENT);
webView.getSettings().setJavaScriptEnabled(true);
webView.getSettings().setDomStorageEnabled(true);
webView.loadUrl("file:///android_asset/ht3-control-studio.html");
// Native host still MUST handle Activity lifecycle, view placement,
// touch pass-through, focus, keyboard and Unity rendering order.
// On UI thread, when appropriate:
webView.evaluateJavascript("window.HT3Overlay.dismiss()", null);
~~~

**Stage 3 — Validate all UI behaviors in the actual APK.**
1. Main menu has seven GG entries.
2. All 15 demo editors render and accept valid sample values.
3. Health → Live health → type draft → close/tap outside → reopen shows same editor/draft.
4. Attributes → Agility → Apply → close/reopen stays on same editor with revised sample.
5. Progress → Minutes → Back → close/reopen stays on Progress.
6. Drag icon to screen edges; check clipping and landscape scaling.
7. Verify outside tap dismiss and normal game touch continuation.
8. Resume Activity, open keyboard, test joystick/action multitouch; confirm no crashes, ANRs, duplicate WebViews or lost UI.
9. **Gate:** Every navigation/persistence/touch test passes in gameplay. Until this point, report **UI integration pending or failed**, not complete.

**Stage 4 — Separate native game-action bridge only after UI works.**
1. Design a small, testable Android ↔ native/IL2CPP command contract. Current window.HT3Overlay API is visual control **only**.
2. Reuse verified GG Lua/CP001 native research; don't treat HTML demo values as real addresses.
3. Surface green availability only after real pointer/class/actor validation.
4. Implement first real game feature with reproducible gameplay verification; then extend to money/attributes/progress and separately researched item spawning.
5. **Gate:** Confirm an actual observed game effect. HTML sample edits and memory readback alone do not count as functional modifications.

## 9. Common failure modes and corrective priorities

| Symptom | Probable issue | Required outcome |
|---|---|---|
| Opaque black/brown rectangle obscures game | Native WebView/surface background opaque | Actual game visible except UI chrome |
| Draggable icon works but game cannot move | WebView overlay intercepting all Android touches | Native hit regions or correct touch routing |
| Menu appears behind game | Unity SurfaceView/z-order or lifecycle problem | Menu over running game after resume |
| Reopen always goes to main | Host reload/reset or reintroduced current=main on open | Exact page/editor and draft restored |
| Edits vanish | DOM storage config/reload or lost draft | Draft/state persists appropriately |
| Menu reappears duplicated | Multiple overlay host additions on Activity recreation | Exactly one icon and one panel |
| Menu works cosmetically but nothing changes in game | Intentional; no native bridge yet | Label as visual preview, not native success |
| Unity startup breaks | Android startup patch regression or split mismatch | Roll back to verified CP004 copy and investigate log |
| Tap outside never closes | Native off-region touches never reach DOM | Host invokes dismiss and preserves Unity input |
| Different device/emulator behaves unexpectedly | ABI, WebView renderer, signer or Houdini differences | Verify on actual physical ARM64 CP004 target |

## 10. Acceptance checklist — do not infer completion

- [ ] CP004 base, both splits and game saves preserved; exact source hashes recorded.
- [ ] Development signing and all 3-split installation remain valid.
- [ ] HTML fetched from the **same permanent GitHub file**, inserted without artwork substitutions.
- [ ] Real Hard Time III gameplay boots; movement and interaction independently observed.
- [ ] Only III icon visible when closed; **no fake game scene or full-screen opaque overlay**.
- [ ] Icon drags; menu opens/closes; all seven original GG options available.
- [ ] Numeric editor screens keep existing sample values.
- [ ] **Current page/editor/unsaved input preserved after clicking outside**.
- [ ] Touches, joystick and action buttons still work outside menu (including multitouch).
- [ ] Landscape, keyboard, pause/resume and Activity recreation do not break UI.
- [ ] No new Android crash, native SIGSEGV or Unity startup regression.
- [ ] Inert overlay reported as **UI-only milestone** until native feature bridge is actually demonstrated.
- [ ] Live health and actual spawning remain marked unimplemented until validated in gameplay.

## 11. Immediate assignment for the other ChatGPT session

**Use the existing CP004 playable three-split build (on a safe copy) and insert the exact current GitHub HTML into the base APK, with a minimal transparent Android WebView host above Unity. Keep the original activity startup and game splits intact. Focus exclusively on the first inert UI integration gate: visible floating icon, compact menu, saved screen/editor state, normal Unity gameplay touches, physical ARM64 test, and repeatable startup. Do not yet combine this test with game-memory mutation or item spawning.**

**Return these proofs:** candidate base/split hashes, exact files/classes changed, installation and gameplay result, screenshot/recording of menu over the real game, native touch routing result, navigation/draft retention result, and logcat/Unity error summary. A screenshot of a browser outside the game is not sufficient.

---

## Provenance and current limits

This document is based on the directly inspected GitHub Lua and current HTML plus separately saved CP004 checkpoint facts. The HTML file passed static source/JavaScript checks; **no Android WebView/APK runtime test was performed in the UI-building session**. The references above describe how the platform is supposed to work; they do not establish that this existing APK supports a drop-in overlay without native work.

**Single-source rule:** Future cosmetic menu revisions update **data/ht3-control-studio.html** in GitHub. This Markdown is a separate handoff, not a replacement for the original Lua or APK checkpoint history.
