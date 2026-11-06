# claude-project-inbox

Messages between the Claude Code sessions of different projects, even when the receiving
session is closed.

Claude Code already lets sessions on the same machine talk: `ListAgents` shows the open ones
and `SendMessage` writes to them. A message for a project with no open session, though, has
nobody to receive it. This adds an inbox per project: the message waits in a folder, and a
SessionStart hook delivers it to the first session opened on that project.

The point is that each project's session changes its own files. A session working on one
project doesn't edit another project's board or docs: it asks that project's session to.

It's a snapshot of my setup as of 2026-11-06, shared to be read and adapted rather than
installed: it's a few lines of bash and one skill.

## How it works

- **`skills/project-message/SKILL.md`** — the skill Claude follows when you ask it to tell
  another project something. Open session → `SendMessage`; closed → `inbox.sh send`, and it
  tells you, so you can open that project right away if you don't want to lose the thread.
- **`hooks/inbox.sh send <project> <sender>`** — leaves the message from stdin in
  `~/.local/state/claude-inbox/<project>/`, one Markdown file per message.
- **`hooks/inbox.sh check`** — the SessionStart hook: injects the waiting messages into the
  new session, marked as coming from another session and not from the user. The session
  handles them and deletes their files.

A project is named after the root folder of its git repo, the same name `ListAgents` gives
to its sessions. Two safety nets for wrong names: `send` warns if no Claude session was ever
opened on that name, and `check` reports, at most once a day, messages waiting for more than a
week.

## Setup

Needs bash, git and jq.

1. Copy `hooks/inbox.sh` to `~/.claude/hooks/` and `skills/project-message/` to
   `~/.claude/skills/`.
2. In `~/.claude/settings.json`, register the hook and, if you use the sandbox, let it write
   to the inbox:

   ```json
   {
     "hooks": {
       "SessionStart": [
         { "hooks": [{ "type": "command", "command": "~/.claude/hooks/inbox.sh check" }] }
       ]
     },
     "sandbox": {
       "filesystem": { "allowWrite": ["~/.local/state/claude-inbox"] }
     }
   }
   ```

## Tests

```bash
docker compose run --rm test
```

## License

[MIT](LICENSE)
