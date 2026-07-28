# USACO2024-Open

Solutions to the USACO 2024 US Open gold problems.

## gstack

This project uses [gstack](https://github.com/garrytan/gstack) for AI-assisted workflows.

It installs itself: `.claude/hooks/session-start.sh` runs on every session start and clones
gstack to `~/.claude/skills/gstack` if it isn't there yet. Claude Code on the web hands out a
fresh container each session, so this is what keeps the skills around. On a local machine the
hook only prints the install command — run it yourself if you want gstack there:

```bash
git clone --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack
cd ~/.claude/skills/gstack && ./setup --team
```

Skills available after install: `/office-hours`, `/spec`, `/autoplan`, `/review`,
`/investigate`, `/qa`, `/ship`, `/browse`, and ~45 more (`/gstack` lists them).
Use `/browse` for all web browsing. Use `~/.claude/skills/gstack/...` for gstack file paths.

### Sandbox notes

- Playwright's Chromium download is blocked by the web sandbox proxy. The hook aliases the
  revision gstack expects to the Chromium already in the image, so `/browse` and `/qa` work —
  just on an older Chromium than gstack pins.
- Setup runs with `GSTACK_SKIP_FONTS=1` (the font install needs apt). Emoji in `/make-pdf`
  output render as boxes.
