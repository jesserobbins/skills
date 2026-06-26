# skills

Jesse Robbins' public Claude Code skills marketplace.

A registry of standalone Claude Code skills and plugins. Each entry points to its own repository — this repo holds the catalog (`.claude-plugin/marketplace.json`), not the skills themselves.

## Add this marketplace

```sh
/plugin marketplace add jesserobbins/skills
```

Then browse and install plugins with `/plugin`.

## What's here

- **[greenroom](https://github.com/jesserobbins/greenroom)** — keeps your private design docs, drafts, and review notes in a private repo right beside the public code, so you do high-quality work in the open without leaking your raw thinking. The public repo is the stage; the private repo is the green room. *(`0.1.8-alpha`)*
- **[refine-and-polish](https://github.com/jesserobbins/refine-and-polish)** — keeps a long [roborev](https://roborev.io) refine loop honest: a private ledger that tracks every finding across iterations and reviewers, so you can tell a regression from a repeat from a loop, defend a deliberate design call, and decide when to stop. *(`0.0.1-alpha`)*

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
