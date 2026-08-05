# skills

Jesse Robbins' public Claude Code skills marketplace.

A catalog of agent skills and plugins. Each entry lives in its own repository — this repo holds the catalog (`.claude-plugin/marketplace.json`), not the skills themselves.

The through-line: both entries are **private scaffolding around public work**. Somewhere to keep the raw thinking — design docs, drafts, review notes, the record of a long review loop — under git, next to the code, without publishing it.

## Install

**As a Claude Code marketplace** — adds every plugin below, and keeps them current:

```sh
/plugin marketplace add jesserobbins/skills
```

Then browse and install with `/plugin`.

**Or take one directly.** Both skills are also published as standalone skills, which work on Claude Code, Codex, Cursor, and the other agents the [skills CLI](https://www.skills.sh) supports:

```sh
npx skills add jesserobbins/greenroom
npx skills add jesserobbins/refine-and-polish --skill roborev-refine-and-polish
```

The two channels are independent: the marketplace is Claude Code plugins, `npx skills` is any agent. Neither needs the other.

## What's here

### [greenroom](https://github.com/jesserobbins/greenroom) — `0.2.1-alpha`

Keeps your private superpowers docs, designs, plans, drafts, and review notes in a private repo right beside the public code, so you do high-quality work in the open without leaking your raw thinking. The public repo is the stage; the private repo is the green room.

Also on skills.sh: [`jesserobbins/greenroom`](https://www.skills.sh/jesserobbins/greenroom)

Mirrored into this repo under `skills/greenroom`, refreshed from each release — see [MIRRORS.md](./MIRRORS.md). The source repo is canonical; report issues there.

### [roborev-refine-and-polish](https://github.com/jesserobbins/refine-and-polish) — `0.0.2-alpha`

Keeps a long [roborev](https://roborev.io) refine loop honest: a private ledger tracking every finding across iterations and reviewers, so you can tell a regression from a repeat from a loop, defend a deliberate design call, and decide when to stop.

Also on skills.sh: [`jesserobbins/roborev-refine-and-polish`](https://www.skills.sh/jesserobbins/roborev-refine-and-polish)

Mirrored into this repo under `skills/roborev-refine-and-polish`, refreshed from each release — see [MIRRORS.md](./MIRRORS.md). The source repo is canonical; report issues there.

## Adding a plugin (maintainer notes)

Each plugin lives in its own repo and is referenced by an entry in `.claude-plugin/marketplace.json`:

```json
{
  "name": "example",
  "source": { "source": "url", "url": "https://github.com/jesserobbins/example.git" },
  "description": "One line on what it does."
}
```

Entries are sourced by git URL off the default branch, so a plugin's own release flows through without touching this repo. Two things here are hand-maintained and *will* drift:

- `metadata.version` in `marketplace.json` — bump it whenever the catalog changes.
- The version label beside each entry above — bump it when that plugin cuts a release.

Keep each `description` in step with the plugin's own `.claude-plugin/plugin.json`, so the catalog and the plugin say the same thing about it.

See Claude Code's plugin marketplace documentation for the full schema.

## License

[MIT](./LICENSE)
