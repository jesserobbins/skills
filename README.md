# skills

Jesse Robbins' public Claude Code skills marketplace.

A registry of standalone Claude Code skills and plugins. Each entry points to its own repository - this repo holds the catalog (`.claude-plugin/marketplace.json`), not the skills themselves.

## Add this marketplace

```sh
/plugin marketplace add jesserobbins/skills
```

Then browse and install plugins with `/plugin`.

## What's here

- `x-twitter-scraper` - Xquik workflow guidance for X/Twitter research, monitoring, REST API, and remote MCP setup.

## Adding a plugin (maintainer notes)

Each plugin lives in its own repo and is referenced by an entry in `.claude-plugin/marketplace.json`:

```json
{
  "name": "example",
  "source": { "source": "url", "url": "https://github.com/jesserobbins/example.git" },
  "description": "One line on what it does."
}
```

Bump `metadata.version` when the catalog changes. See Claude Code's plugin marketplace documentation for the full schema.

## License

[MIT](./LICENSE)
