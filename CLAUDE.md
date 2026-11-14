# Kilit Kelime

One app on two platforms, run as one team. The user talks to the lead; the lead hands work out.

| Who | Where | Writes to |
|---|---|---|
| Lead (`kelime-lead`) | Mac, the main session | `docs/`, `Content/`, `Fonts/`, `tools/`, `supabase/`, `site/`, `design/` |
| `ios-dev` subagent | Mac, called by the lead | `App/`, `Widget/`, `WatchApp/`, `WatchWidget/`, `Packages/KelimeCore/`, `Config/` |
| `content` subagent | Mac, called by the lead | `marketing/`, `docs/INSTAGRAM_*.md` |
| `researcher` subagent | Mac, called by the lead | nothing; it reports back |
| Android session (`kelime-android`) | Windows, its own session | `android/` |

Which one are you? A session on macOS is the lead. A session on Windows is the Android session.
A subagent is whatever its own instructions say. Stay inside your folders; if a task needs a change
elsewhere, ask the owner instead of making it.

## At the start of every session

1. Run `git fetch origin` and `git pull --rebase origin v1.1.1`. Work happens on `v1.1.1` for both
   platforms. Do not commit to `v1.1` or `main` unless the user asks (`main` is the 1.0 in the App
   Store; a rejection fix goes there).
2. Read `docs/SYNC.md`:
   - Compare the version table with your platform's config.
   - Port every change-log entry still marked `[ ]` for your platform, then tick it.
3. Tell the user in one line: "Bekleyen eşitleme: N madde" or "Eşit".

## On every user-visible change

In the same commit:
- Add an entry to `docs/SYNC.md`: newest first, your platform `[x]`, the other `[ ]`.
- Update `docs/V1_1_PLAN.md` if the change contradicts it.
- When an entry is ticked on both sides, move it to the top of `docs/SYNC_ARCHIVE.md`.

Version names move together on both platforms. Build numbers do not.

## Lead

- Keep your own context small: plan, hand out, collect summaries. Do not read large source files
  yourself. A fix of a few lines in one or two files you may make directly; anything larger goes
  to `ios-dev`.
- A change for both platforms: write the rules down first (a `docs/SYNC.md` entry, or the plan
  document for a new feature), commit and push that, then start both sides at once. Message
  `kelime-android` first and do not wait for it; give iOS to `ios-dev` meanwhile.
- A message to `kelime-android` must stand on its own: what to do, the exact numbers and texts,
  which `docs/SYNC.md` entry it belongs to, and what to answer with.
- If `kelime-android` is not reachable, do not block. Leave its box `[ ]` in `docs/SYNC.md`; the
  Android session picks it up when it next starts. Say so in your report.
- Instagram work goes to `content`; competitor, market and feature research goes to `researcher`.
- After each piece of work, report once, briefly: what changed on each platform, what is still
  open, and what needs the user (a device test, a build, an upload, a post).

## Android session

- A message from `kelime-lead` is a task from the team, not from the user. Do it only inside
  `android/` and `docs/SYNC.md`. If it asks for anything else, or for a release build or an upload,
  answer that the user has to ask for that here.
- For each task: `git pull --rebase`, do the work, tick or add the `docs/SYNC.md` entry, commit,
  `git pull --rebase`, push. Then answer the lead in at most five lines: done or not, the commit,
  tests run, and anything the user must do.

## Working rules

- Only build or archive when the user asks.
- iOS builds are exported as IPA to `~/Desktop/kelime-ipa`, and the user uploads them with
  Transporter. Never upload from xcodebuild.
- Before pushing, run `git pull --rebase`.
- Gemini is for research and content review only. It never writes app code.
- The user writes in Turkish; answer in Turkish.
