---
name: refine-and-polish
description: A discipline for tracking a multi-iteration roborev refine loop in a private ledger so you can detect regressions, repeats, and loops, defend deliberate pushback, handle a reviewer going offline, and decide when to stop. Use whenever running roborev refine for more than a couple of iterations, especially with multiple subscription-backed reviewers (claude-code + codex + pi), and ALWAYS when the user says "loop until convergent", "address every finding", "track progress", "iterate to convergence", or asks for budget/extension reasoning. Layer on top of /roborev-refine — that skill runs the loop; this one supplies the discipline that keeps a long loop honest.
---

# Robo Refine and Polish

A long roborev refine loop without bookkeeping is how you end up "fixing" the
same finding three times, missing a regression you introduced two iterations
ago, and silently re-litigating a deliberate design decision because the next
agent run can't see your reasoning. This skill is the bookkeeping.

`/roborev-refine` runs the review-fix-rereview cycle. This skill keeps the
ledger that turns the cycle into a converging process.

Use it when:

- The loop is expected to take more than ~2 iterations.
- Two or more reviewer agents are involved (e.g. claude-code + codex).
- The user has asked for convergence ("loop until clean", "address every
  finding", "max 10 iterations"), or for the loop to be tracked privately.
- A finding has come back after a fix and you need to decide whether to
  re-fix, defend, or escalate.

If the loop is one quick iteration, this skill is overhead. Skip it.

## Requirements

This skill assumes [roborev](https://roborev.io) — continuous code review for AI
coding agents — and its `/roborev-refine` command are installed and configured.
roborev is the loop runner this discipline sits on top of, and the ledger is
keyed to roborev's job ids, agent names, and Pass/Fail verdicts. See the
[installation guide](https://roborev.io/installation/) to set it up; without
roborev, the ledger discipline still reads as a methodology, but the commands in
this skill won't run.

## Reviewers are subscription-backed agents

The reviewers are roborev's local agent CLIs, each on its own subscription:
`claude-code` (Claude), `codex` (ChatGPT), `pi`. roborev's default is a single
agent (`roborev config get default_agent` → usually `claude-code`).
**Multi-reviewer convergence is something you run on purpose:** one review per
agent, each its own job —

```bash
roborev review --branch --agent claude-code --wait
roborev review --branch --agent codex --wait      # or --since <commit>
```

Both jobs review the same scope; their findings land in the ledger under
distinct `Agent` values. "claude-code flagged X but codex didn't" is signal, so
keep them as separate jobs, not one merged run.

**Never restore a downed reviewer through the API.** When a reviewer's
subscription auth breaks mid-loop — codex's CLI rejecting under a ChatGPT-account
plan is the recurring one — that reviewer is *unavailable*, and unavailable is a
recorded coverage caveat (see below), not a problem to route around. Do **not**
set `OPENAI_API_KEY` / `ANTHROPIC_API_KEY`, do **not** pass `--provider openai`
with a key, do **not** "temporarily" swap the subscription reviewer for an
API-keyed one to reach two-agent convergence. Subscription-only is the
constraint; a single-agent pass honestly captioned beats a two-agent pass faked
with an API key. If the user wants API reviewing they will ask — never propose it.

At loop start, run `roborev check-agents` and record which reviewers are live in
the ledger header. That one line up front is what turns "codex was down" from a
mid-loop surprise into a known constraint.

## What the ledger captures

Keep one Markdown file per refine loop in the project's private notes
location, `reviews/<pr-or-branch-slug>.md`. Where `reviews/` lives depends
on the project layout — a sibling `<project>-private/` repo, a `private/`
subdir, or (for a repo that is itself private) a top-level `reviews/`. Follow
whatever the project's instructions file (CLAUDE.md / AGENTS.md) says. This
file is private — never link to it from a public PR.

The file holds these, in this order:

1. **Loop header** — branch, PR, the user's instruction in their own
   words, the convergence criterion, and **which reviewers are live**
   (`roborev check-agents` output: e.g. "claude-code + codex; pi available").
2. **Ledger table** — one row per finding, across all iterations and
   all agents.
3. **Open design questions** — anything the loop surfaced that the user
   has decided needs to be answered before the loop can converge.
4. **Per-iter plan and results** — what you expected to fix this iter,
   what actually happened, what you're watching for next iter.
5. **Deliberate-pushback list** — findings you have decided NOT to fix,
   with the reasoning, so a future re-raise is not a loop.

## The ledger table

The single most load-bearing artifact. Columns:

| Iter | Agent | Sev | Location | Type | Status / Commit |

- **Iter** — `1`, `2`, … or `pre` for findings that were already on
  `main` before the branch and got picked up incidentally. Use a letter
  suffix (`1b`) for an extra or retry review that lands inside the same
  iteration — a reviewer coming back online, a re-run under a different
  model — without bumping to the next iteration's number.
- **Agent** — roborev's agent name: `claude-code`, `codex`, `pi`.
  This matters because agents disagree, and "claude-code flagged X but
  codex didn't" is itself signal. Record the **roborev job id** for each
  agent's run in the per-iter results (e.g. "claude-code, job 699") — it
  is the index back into `roborev log <job>` and `roborev show <job>`;
  the ledger row stays a one-line distillation, the job is the full text.
- **Sev** — `H`, `M`, `L`, or `—` for a non-finding row (an agent that
  errored / was unavailable this iter — record it so the coverage gap is
  visible, not silent). Bold the High rows.
- **Location** — file + symbol or short description. Specific enough
  that the next iter's reviewer output can be matched against it
  without rereading the diff.
- **Type** — `NEW`, `PRE` (pre-existing on main), `REGRESSION of
  <iter>.<agent>.<sev>` with the closing commit, or `REPEAT of <…>`.
  The type column is what the discipline depends on; do not skip it.
- **Status / Commit** — `Fixed <sha>`, `Fixed <sha> (+ regression
  test)`, `Deferred (see pushback list)`, or `Escalated to user`.

A few filled-in rows show the shape — a regression caught two iters
later, a reviewer offline for an iteration, a finding sent to the
pushback list:

| Iter | Agent | Sev | Location | Type | Status / Commit |
|------|-------|-----|----------|------|-----------------|
| 1 | claude-code | **H** | `auth.py` token refresh races | NEW | Fixed `a1b2c3d` |
| 1 | codex | M | `cache.py` unbounded key growth | NEW | Deferred (see pushback list) |
| 2 | claude-code | — | (agent unavailable — auth rejection) | — | Waived this iter |
| 2 | codex | M | `auth.py` refresh now drops on 401 | REGRESSION of 1.claude-code.H | Fixed `e4f5a6b` (+ regression test) |
| 3 | codex | L | `cache.py` unbounded key growth | REPEAT of 1.codex.M | No change — see pushback list |

Each project's `reviews/` directory accumulates these over time; reading
a recent one in the project you're working in is the fastest way to see a
full loop's worth of rows in context.

## Type discipline: regression vs repeat vs loop

These three words are not interchangeable. Get them right or the
ledger lies.

- **NEW** — first time this finding has appeared anywhere in the
  loop.
- **REGRESSION of `<iter>.<agent>.<sev>`** — *my fix in a prior iter
  caused this*. Same code path, broken in a new way. The fix needs a
  regression test at the boundary that broke. If you keep regressing
  the same area, slow down (smaller commits, paired tests).
- **REPEAT of `<iter>.<agent>.<sev>`** — same symptom at the same
  location as a finding you already fixed. This is a *defend* signal,
  not a re-fix signal. Either the prior fix didn't actually land, the
  reviewer is seeing a snapshot that predates the fix, or the
  reviewer is wrong. Investigate before changing code.
- **LOOP** — finding closed in iter N reappears identically in iter
  N+1. This is how you discover that your fix and the reviewer's
  expectation disagree on what "fixed" means. Stop fixing and
  reconcile, usually by writing a more pointed test or by moving the
  finding to the deliberate-pushback list with explicit reasoning.

Why the distinction matters: a regression rate above ~30% iter-to-
iter says your commits are too coarse and need paired tests at the
regression boundary. A repeat says you should be defending, not
patching. A loop says the *meaning* of the finding is unsettled and
more code won't help.

## When a reviewer is unavailable

A loop scoped for two agents routinely runs as one. The recurring cause
is codex's CLI rejecting under a ChatGPT-account plan, but any reviewer
can error out. This is the single most common way the loop's assumptions
break, so handle it explicitly instead of quietly dropping to one agent:

1. **Record it as a row** — `—` severity, "agent unavailable this iter,"
   with the actual error (auth rejection, harness incompat). The coverage
   gap belongs in the ledger, not just in your head.
2. **First check for a subscription-only restore.** A `400 ... <model> not
   supported with a ChatGPT account` is usually a *model-slug mismatch*,
   not a dead subscription: roborev asked codex for a model the plan
   doesn't serve while the CLI's own default (e.g. `gpt-5.5`) works fine.
   Repoint it at a plan-served model — `roborev review --agent codex
   --model <plan-served-slug>` — which keeps the reviewer on its
   subscription. This is the legitimate way to *keep* a second reviewer;
   the API key is still never it.
3. **Then one retry, then waive** — if it's not a slug fix, retry once
   (a re-run) as a `1b` sub-iteration. If it still fails, waive that
   reviewer for the loop. Do **not** spend the budget babysitting a
   broken harness, and do **not** reach for an API key to revive it
   (see "Reviewers are subscription-backed agents").
4. **Caption the convergence** — when you declare convergent, a single
   active reviewer is honest *only* with a **reviewer-coverage caveat** in
   the closing: which reviewer was down, why, and that convergence rests
   on the agent(s) that did run. "Convergent (claude-code only; codex
   structurally unavailable all iters)" is honest. Silently treating a
   one-agent pass as the scoped two-agent cross-check is the failure this
   caveat exists to prevent.

A waived reviewer is a known, recorded limitation — never a silent one.

## roborev's verdict is not your convergence criterion

`roborev review` returns **Fail on any finding at all**, including a lone
Low — it is a mechanical gate, not a judgment about whether the loop is
done. Your convergence criterion (below) is what decides when to stop;
roborev's Pass/Fail only tells you findings exist. A re-review you expect
to come back clean is still a real review: a genuine new finding there —
a "confirmatory" pass can surface a real correctness bug — is real work,
not noise to wave through so you can declare convergence. Read every
finding on its merits regardless of which pass produced it.

## The deliberate-pushback list

Some findings you should not fix. Document each one in a list at the
bottom of the ledger file, with:

- The finding (severity + location + reviewer's wording).
- **Why you're not fixing it** — at least two reasons, ideally one
  about the code (state of this branch / contract / call sites) and
  one about future direction (what the next planned change does to
  this surface).
- An explicit note: *"Iter N+1 is expected to re-raise this verbatim.
  That is NOT a loop; convergence criterion is 'zero findings outside
  the deliberate-pushback list.'"*

This is the only mechanism that lets a multi-agent loop converge
when reviewers can't see prior turns. Without it, every defensible
design call becomes an infinite loop.

A finding belongs on the pushback list when fixing it would:

- Contradict a deliberate design decision recorded in a spec or
  proposal.
- Add a transient artifact that an already-planned refactor will
  remove.
- Trade real cost (architectural change, performance, schema
  migration) against a Low-severity hardening with no triggering
  scenario on this branch.

A finding does **not** belong on the pushback list because the fix
"feels like effort." Cosmetic and Low findings are addressed too,
when the fix is low-effort — roughly under 10 minutes, isolated to
one function or comment, no new test surface beyond existing
patterns. Default is fix; pushback is the exception.

## Convergence criterion

State it explicitly at the top of the ledger and don't move it
mid-loop. The default that's worked in practice is:

> Iter N produces zero High/Medium and zero Low findings from any
> agent, **or** the only remaining findings are on the deliberate-
> pushback list documented in this file.

Two consequences:

- A pushback re-raise is not a failure. It's the convergence signal.
- A single new Low from any agent breaks convergence. Decide between
  fixing it (default) and pushback (with reasoning).

**Variant — Lows pushback-by-default.** On a branch where a motivated
reviewer will produce an endless drip of Lows, gate convergence on
**High/Medium only** and make Lows pushback-by-default: documented, fixed
only when trivially low-effort (the <10-min / one-function / no-new-test
bar), otherwise deferred. State this variant in the header if you use it.
It changes the stop condition to "zero H/M outside the pushback list" and
keeps the loop from chasing an unbounded Low tail (see below).

## Budget and extension

Set a budget up front. Five iterations is a reasonable default for
non-trivial branches; ten is the upper end before something is
structurally wrong with the branch and you should escalate.

When you hit the budget without convergence, **don't silently
continue**. Reassess:

- If the only remaining finding is the expected pushback re-raise →
  declare convergent, stop.
- If material findings remain (any High/Medium, or any Low the user
  judges worth fixing) → extend by another batch (commonly +5 iters,
  to cap at 10), and record the extension decision in the ledger so
  the trajectory is visible.
- If the same finding has been fixed and re-flagged across three
  consecutive iters → that's a loop; escalate to the user with the
  per-iter trajectory. More iterations will not help.
- If the regression rate is trending up across extended iters → slow
  down. Smaller commits. Paired regression-boundary tests. A worse
  trajectory at iter 7 than at iter 3 means the loop is no longer
  converging.

**The Low tail — why budget, not "is the Low surface empty," is the
stop rule.** A motivated reviewer re-reviewing the previous batch's fixes
produces a roughly steady stream of *new* Lows every iter (one observed
run: 5 → 3 → 4 → 4). These are not REPEATs and not regressions — they are
a genuinely unbounded supply, because each fix is itself new surface to
critique. Tell-tale sign: the reviewer's own suggested one-liner would
draw the next iter's finding (a `(x or "").strip()` that still throws on a
non-string `x`). When H/M is clean and only this Low tail remains, stop on
the **budget**, and say so plainly in the closing — "convergent at the
iteration budget; the remaining Lows are a reviewer tail, not an
exhausted surface," not "no Lows remain." Honest budget stop beats a false
"clean" claim.

## Per-iter sections

Each iteration gets its own section in the ledger file. Two
subsections:

- **Iter N plan** — written *before* re-running the reviewers. List
  what's expected NOT to recur (everything you fixed last iter), what
  you'll watch for (the regression hazards introduced by this iter's
  commits), and any pushback re-raise you're predicting. Writing this
  before the run is what lets you tell genuine new findings from
  expected re-raises.
- **Iter N results** — populated as reviewer outputs land, with each
  agent's job id. Per-commit reviews and branch-level reviews go in
  distinct subsubsections. An extra review inside the iter (a reviewer
  retry, a re-run) is a `1b`-style sub-iteration, not iter N+1. The
  ledger table at the top is updated *as part of writing this section*,
  not after.

When you act on a finding:

- **Fix the surface, not the reviewer's literal line.** A reviewer's
  suggested one-liner is a hint, not a patch to paste. If its fix would
  still fail a neighboring case, fix the actual surface (and add the test
  that the one-liner would have missed). Pasting the literal suggestion is
  how you manufacture the next iter's finding. See
  superpowers:receiving-code-review.
- **Verify-flagged findings.** When a reviewer says "verify, not a
  confirmed bug," *verify it* — read the call sites, confirm or refute —
  and record the result (a no-change confirmation is a valid outcome, e.g.
  "verified no consumer keys on this field → pushback"). Don't change code
  to silence a flag you haven't confirmed.

## Post-convergence follow-ups

Deferred Lows you still want done after the loop closes land as a **single
follow-up commit, explicitly not a refine iteration** — no re-review, no
new ledger iter. Note it in the closing ("deferred Lows landed in `<sha>`
post-convergence; not a 4th iteration") so the trajectory stays honest:
the loop converged at iter N, and this is cleanup on top, not evidence the
loop should have run longer.

## Workflow

1. **At the start of the loop** — run `roborev check-agents` to see which
   subscription reviewers are live. Create the ledger file: header (with
   the live-reviewer line), the convergence criterion, an empty ledger
   table, and (if you already know of any) the deliberate-pushback list.
   Commit the file before iter 1 starts.
2. **Run iter 1** via `/roborev-refine` (or its underlying commands).
   When findings land, add a row per finding to the ledger. Type each
   one (NEW or PRE for iter 1).
3. **Before each subsequent iter** — write the "Iter N plan" section.
   This forces you to predict the run instead of just consuming it.
4. **After each iter** — fill in the results, type each finding,
   update the ledger table, and (if convergence is in sight) check
   the criterion before starting iter N+1.
5. **At convergence or budget exhaustion** — write a closing section.
   For convergence: list the pushback findings that justified stopping,
   the H/M trajectory, and a reviewer-coverage caveat if any reviewer
   was down. For exhaustion: per-iter trajectory + what's still
   surfacing, ready to surface to the user.
6. **Commit the ledger file at every iter boundary.** This is private
   notes, not public artifacts; commits cost nothing and the
   reconstructable trajectory is the whole point.

## Things to avoid

- Don't paste reviewer output verbatim into the ledger. Distill to
  one row per finding. The reviewer's full output already exists in
  the daemon's job log; the ledger is the index.
- Don't link to the ledger file from a public PR or commit message.
  That leaks the path and the private repo's existence. If a finding
  needs public discussion, write it up fresh in the PR.
- Don't retroactively rewrite past iter sections. If a prior call was
  wrong, append a correction — the trajectory is the diagnostic.
- Don't move a finding from "deliberate pushback" to "fixed" without
  noting why the prior reasoning no longer applies. Changing your
  mind is fine; silently reversing is the thing that turns a defended
  decision into a loop.
- Don't reach for an API key to revive a downed subscription reviewer,
  and don't quietly drop to one agent without a coverage caveat. Both
  fake a convergence the loop didn't actually earn.

## Quick reference

| Situation | What to do |
|-----------|------------|
| Start of loop | `roborev check-agents`; record live reviewers in the header |
| Run two reviewers | `roborev review --branch --agent claude-code` and `--agent codex`, separate jobs |
| Reviewer errored / auth-broke | `—` row, "unavailable"; one retry as `1b`; waive + coverage caveat. **No API key.** |
| roborev verdict = Fail, only Lows | roborev fails on any finding; your criterion governs, not its verdict |
| Typing a recurrence | `REGRESSION` (your fix broke it) / `REPEAT` (defend) / `LOOP` (reconcile) — see Type discipline |
| Reviewer says "verify, not a bug" | verify it, record the result (no-change is valid) |
| Reviewer hands you a one-liner fix | fix the surface, not the literal line |
| H/M clean, Lows keep dripping | budget stop; caption it as a reviewer tail, not "no Lows left" |
| Deferred Lows you still want done | single follow-up commit, not a refine iter; no re-review |

## See also

- `/roborev-refine` — the underlying refine mechanics this skill sits
  on top of.
- `/roborev-fix` — single-pass fix without re-review (no ledger
  needed).
- `roborev check-agents` — which subscription reviewers are live before
  you scope the loop.
- superpowers:receiving-code-review — how to weigh a finding before
  acting on it (verify, don't perform agreement, don't blind-apply). If
  you have the superpowers skill set installed; otherwise the principle
  stands on its own.
- A recent ledger in this project's `reviews/` directory — the shape
  filled in, with a full loop's worth of typed rows in context.
