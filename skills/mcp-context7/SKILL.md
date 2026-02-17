---
name: mcp-context7
description: Look up current library documentation using Context7 MCP. Use when generating config files, scaffolding projects, or working with libraries that may have updated since training.
user-invocable: true
---

# Context7 MCP

Fetches current library documentation via the Context7 MCP server. Use this to get up-to-date API references, config patterns, and version information for libraries where your training data may be stale.

GitHub: https://github.com/upstash/context7

Package: `@upstash/context7-mcp`

## Detection

Check if the `context7` MCP is available:

```
ToolSearch query: "+context7"
```

If `mcp__context7__*` tools appear in results, the MCP is installed and available. If not, see [Installation](#installation).

## Installation

Install for the current user (pin to a specific version):

```bash
# Check latest version
npm view @upstash/context7-mcp dist-tags --json

# Install with pinned version
claude mcp add context7 -- npx -y @upstash/context7-mcp@<version>
```

This adds the server to `~/.claude.json` under `mcpServers`.

**After installing**: Claude CLI must be restarted for the MCP server to become available. Resuming an existing session after restart is sufficient — a brand new session is not required.

**Prerequisites**:
- Node.js / npm (for `npx`)

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
jq -r '.mcpServers.context7.args[] | select(startswith("@upstash/context7-mcp"))' ~/.claude.json
```

**Check the latest available version**:
```bash
npm view @upstash/context7-mcp dist-tags --json
```

**Update the pinned version**: Edit `~/.claude.json` and update the version in the command array (e.g., `@upstash/context7-mcp@2.1.1`). Claude CLI must be restarted after changes.
