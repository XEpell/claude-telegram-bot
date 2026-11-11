# Claude Telegram Business Bot

[Русский](README.md) · **English**

A modification of the official Telegram plugin for [Claude Code](https://claude.com/claude-code).
The bot connects to your **personal** Telegram account (Telegram Business → Chatbots) and helps
you answer people: it replies on its own to simple small talk and asks you to approve everything else.

> Unofficial project. Based on `telegram@claude-plugins-official` v0.0.7 (Apache-2.0, see `plugin/LICENSE`).
> All changes are listed below and in `patches/`.

## Features

- **Auto-replies to small talk** ("hi", "how are you", "thanks") in the owner's tone.
- **Circles** ("Friends", "Work", "Family"; a person can be in several) and short style notes:
  the owner's general style, each circle's style and a card per contact. The bot writes them itself
  (one chat at a time, when chats are quiet); the owner can view and edit them via `/circles` and `/contacts`.
  A reply uses these notes plus only the last 10 messages — no re-reading of whole histories; if the contact
  refers to something older, the bot searches that one chat.
- **Everything else** goes to the owner as a draft with "✅ Send / ❌ Don't send" buttons.
- **New contacts**: the bot asks the owner "Allow / Deny". Until decided, at most 5 auto-replies
  (the counter resets when the owner writes themselves). Allowed contacts: no cap. Denied: ignored.
- **Local chat history** per contact (JSONL + downloaded media).
- **Deleted message alerts**: if a contact deletes a message, the owner gets its text and media.
- **Google Calendar**: when a chat agrees on (or cancels) a meeting, the bot proposes adding/removing
  the event — nothing changes until the owner taps "✅" (requires the Google Calendar connector in claude.ai).
- **`/contacts` command** — contact list; tap a person to see their card, circles and status.
  "📦 Archive" hides a person but keeps their history and card; they come back if they write again.
- **Reminders** — tell the bot "remind me tomorrow at 10 to call the bank"; `/reminders` lists them.
  Stored on disk, so they survive restarts; so do pending drafts and calendar proposals.
- **Automatic memory reset**: when the Claude Code context grows (~120k tokens by default), the bot restarts
  the session at a quiet moment (`hotkey/run-bot.ps1`), so each message doesn't drag the whole past along.
  Threshold: `memoryResetTokens` in `business-settings.json` (0 = off).
- **Voice and video-note transcription** — local Whisper model (`whisper/install.ps1`), audio never leaves
  the computer. The bot understands contacts' voice messages (also in channel comments), and the owner can
  give the bot commands by voice.
- **Owner's channels** (`/channels`): add the bot as an admin of your channel and of its comment chat.
  The bot answers comments under posts (simple ones itself, the rest as drafts for the owner, with an
  "ignore this person" button), and on the owner's request ("publish to the channel: …") prepares a post that
  goes out only after the "✅ Publish" button. Channels the bot was added to by anyone else are left immediately.
- **`/stats` command** — tokens used by the bot's session today, over 7 days and per day.
  Read from Claude Code transcripts and accumulated in `usage-stats.json` / `usage-stats.csv`
  (kept even after Claude Code deletes old transcripts). Default launch folder is `~/claude-telegram`;
  set another one via `"usageDir"` in `business-settings.json`.
- Status notices: 🟢 started / 🔴 stopped / ⚠️ not receiving messages.
- Windows helpers: start Claude Code at login and on **Alt+Win+F5** (`hotkey/`).

## Screenshots

| New contact | Started | Stopped |
|---|---|---|
| <img src="docs/screenshots/new-contact.png" width="300"> | <img src="docs/screenshots/started.png" width="300"> | <img src="docs/screenshots/stopped.png" width="300"> |

## Looking for feedback

This is a young project — ideas, reviews and pull requests are very welcome, see [CONTRIBUTING.md](CONTRIBUTING.md).
Especially useful:

- **security review** — the bot reads private chats, so any hole matters;
- autostart for **macOS / Linux** (Windows only for now);
- **tests** for the server logic (limits, history, drafts);
- an easier way to re-apply the patch to **new plugin versions**.

> The code was written together with Claude (Claude Code). There are no automated tests yet — it has been checked by hand on one account.

## Security model

Contacts' messages are treated as **untrusted**:

- the server — not the model — decides whether a reply may skip approval:
  ≤ 200 chars, no links, @mentions, phone numbers, codes or times;
- per-contact limits plus a bot-to-bot loop guard (≥ 20 s apart, ≤ 15 per hour per chat);
- the only path to a contact without those checks is the owner's button;
- if the contact edits or deletes their message before "Send" is tapped, the reply is not sent;
- only the Claude Code session started with `--channels` receives messages.

**No personal data lives in this repository.** The bot token, owner ID, contact list, history and media
stay on the owner's machine in `~/.claude/channels/telegram/` and are excluded via `.gitignore`.
This code grants nobody access to someone else's bot or Claude subscription — you need **your own**
bot, token and subscription.

## Setup (Windows)

1. Install [Claude Code](https://claude.com/claude-code) and [Bun](https://bun.sh).
2. In Claude Code, install the official plugin and configure your bot:
   ```
   /plugin install telegram@claude-plugins-official
   /telegram:configure <token from @BotFather>
   ```
3. Replace the plugin's `server.ts` with `plugin/server.ts`
   (usually `~/.claude/plugins/cache/claude-plugins-official/telegram/0.0.7/`)
   or apply `patches/telegram-0.0.7-business.patch`.
4. In @BotFather enable **Secretary Mode** (Business Mode) for the bot.
5. Copy `config-examples/business-settings.example.json` to `~/.claude/channels/telegram/business-settings.json`.
6. Start Claude Code with the channel:
   ```
   claude --channels plugin:telegram@claude-plugins-official
   ```
   DM the bot, pair with `/telegram:access pair <code>`, then `/telegram:access policy allowlist`.
7. Telegram → Settings → Telegram Business → Chatbots → add the bot and allow "Reply to messages".
8. (Optional) autostart and Alt+Win+F5: `powershell -ExecutionPolicy Bypass -File hotkey\install.ps1`.

> Updating the official plugin overwrites `server.ts` — re-apply the patch afterwards.

## License

Apache-2.0, same as the original plugin. Changed code is marked with `[custom]` comments.
