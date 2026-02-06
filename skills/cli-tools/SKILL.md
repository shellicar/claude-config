---
name: cli-tools
description: Conventions for running CLI commands via the Bash tool. Apply when executing shell commands, using az rest, gh, or other CLI tools.
user-invocable: false
---

# CLI Tool Conventions

Guidelines for how to execute commands via the Bash tool.

## Tool Restrictions

- **Do NOT use** `python`, `jq`, or other data processing tools to construct, transform, or format data
- Construct all JSON directly using the Write tool
- Reference saved files using the CLI tool's file input syntax instead of inline JSON or piping:
  - `az rest --body @file.json`
  - `curl -d @file.json`
  - `gh api --input file.json`

## Temp Files

When saving data to temp files:

- Use **meaningful names** that describe the contents, not generic names like `body.json` or `data.json`
- Examples:
  - `/tmp/ado-columns-with-parent.json` — column config including Parent column
  - `/tmp/ado-columns-without-parent.json` — column config without Parent column
  - `/tmp/ado-columns-body.json` — combined PATCH body for all categories

## Command Comments

Before each command, add a **comment explaining what it does**:

```bash
# Portfolio Team - Initiative: without-parent, Epic/Feature/PBI: with-parent
az rest --method PATCH ...
```

This is especially important when running the same command template against multiple targets (teams, resources, etc.).

## Command Descriptions

Always provide a clear `description` parameter when using the Bash tool, so the user can understand each command at a glance.
