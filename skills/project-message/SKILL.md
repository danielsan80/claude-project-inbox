---
name: project-message
description: Sends a message to the Claude session of another of the user's projects — for example so that it updates a card or a document after the work done here. If a session of that project is open it uses SendMessage; if not it leaves the message in the project's inbox, which the first session opened there receives. Use when the user asks to tell, write or leave a message to another project.
---

# Message to another project

1. **Recipient**: the project's name is the name of its repo's root folder (`web-shop`,
   `notes`), the same name `ListAgents` gives to its sessions. If the user calls it
   something else and its path is in the context, for example in an index of projects, the
   name is the last part of the path: use it without asking. Ask only if you can't find the
   path.
2. **Text**: it has to stand on its own, because whoever reads it doesn't have this
   conversation. First line: who is writing and what is asked (`From web-shop: …`). Then the
   facts, with dates, and what to do over there.
3. **Is a session open?** Run `ListAgents`. Sessions are named `<project>-<n>`.
   - Just one → `SendMessage` to it, and that's it.
   - More than one → ask the user which one.
   - None → inbox, step 4.
4. **Inbox**: the session is closed, so leave the message. The sender is the name of this
   project:

   ```bash
   ~/.claude/hooks/inbox.sh send <project> <sender> <<'EOF'
   <text>
   EOF
   ```

   Then tell the user in one line: the message is waiting in the inbox, and if they don't
   want to lose the thread they can open a session on that project right away. If `send`
   warns that no session was ever opened on that name, pass it on: the name may be wrong.
   Delivery is done by the SessionStart hook `inbox.sh check`, which also reports messages
   waiting for more than a week; a message is consumed when the receiving session deletes
   its file.

If writing fails with "read-only", the inbox folder (`~/.local/state/claude-inbox`) is missing
from `sandbox.filesystem.allowWrite`: tell the user, don't leave the sandbox.
