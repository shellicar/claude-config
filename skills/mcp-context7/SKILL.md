---
name: mcp-context7
description: Look up current library documentation using Context7 MCP. Use when generating config files, scaffolding projects, or working with libraries that may have updated since training.
user-invocable: true
---

# Context7 MCP

Fetches current library documentation via the Context7 MCP server. Use this to get up-to-date API references, config patterns, and version information for libraries where your training data may be stale.

GitHub: https://github.com/upstash/context7

Package: `@upstash/context7-mcp`

## When to Use

- Generating configuration files (vite, biome, eslint, tsconfig, etc.)
- Scaffolding new projects with specific library versions
- Working with libraries that release frequently (build tools, linters, frameworks)
- When the user asks for "latest" or "current" versions/patterns

## How to Use

Two-step flow:

1. **Resolve the library ID**:
   ```
   ToolSearch query: "select:mcp__context7__resolve-library-id"
   mcp__context7__resolve-library-id(libraryName: "vite")
   ```

2. **Query the docs**:
   ```
   ToolSearch query: "select:mcp__context7__query-docs"
   mcp__context7__query-docs(context7CompatibleLibraryID: "/vercel/next.js", topic: "configuration")
   ```

Look up docs **before** generating config or scaffold files — not after.

## Version Management

The MCP server is configured in `~/.claude.json` under `mcpServers.context7`.

**Check the pinned version**:
```bash
# Read the command from ~/.claude.json to see the pinned version
grep -A5 '"context7"' ~/.claude.json
```

**Check the latest available version**:
```bash
npm view @upstash/context7-mcp version
```

**Update the pinned version**: Edit `~/.claude.json` and update the version in the command array (e.g., `@upstash/context7-mcp@2.1.1`). Claude CLI must be restarted after changes.
