# Mirrors

Some skills in this catalog live in their own repository. That repository is
canonical — it carries the releases, the CI, and the issue tracker. This repo
keeps a copy under `skills/` so skills.sh has something to index here.

| Mirrored to | Source | Refreshed from |
|---|---|---|
| `skills/greenroom` | [jesserobbins/greenroom](https://github.com/jesserobbins/greenroom) | its newest release |

## How it works

`.github/workflows/sync-mirrors.yml` runs `scripts/sync-mirrors.sh` daily, and on
demand via **Run workflow**. The script copies the payload out of the source
repo's newest release — including prereleases, which is why it reads `/releases`
rather than `/releases/latest`; the latter skips prereleases and 404s on a repo
that has only those.

Each mirrored payload is **byte-identical** to the release it came from. Nothing
is written inside the skill directory — this file is the provenance record —
so "identical to upstream" stays a property you can check:

```sh
scripts/sync-mirrors.sh --check    # reports staleness, changes nothing, exits 1 if stale
```

The sync also updates the version label beside the entry in `README.md`, which is
otherwise hand-maintained and drifts.

## Rules

- **One way.** The source repo is canonical; nothing here is ever pushed back.
  Edit the skill in its own repo and cut a release.
- **Report issues upstream**, against the source repository.
- Either install path works and fetches an identical payload:

  ```sh
  npx skills add jesserobbins/greenroom                  # canonical
  npx skills add jesserobbins/skills --skill greenroom   # this mirror
  ```
