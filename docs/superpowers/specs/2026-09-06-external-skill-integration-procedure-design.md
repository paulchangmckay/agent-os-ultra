# External Skill Integration Procedure + Taste-Skill Tiebreak — Design Spec

Date: 2026-09-06
Status: Approved, pending grill
Issue: https://github.com/paulchangmckay/agent-os-ultra/issues/82
Source: skill-observation #28 (`.wolf/observations.md`)

## Purpose

Two related additions to `skills/claude-infra-reference/SKILL.md`:

1. A general **External Skill Integration Procedure** — the checklist issue #82 asked for, so evaluating and installing a new third-party skill or skill bundle stops being re-derived from scratch each time (has happened 5+ times: mattpocock, taste-skill, make-interfaces-feel-better, silk-design, refero).
2. A **tiebreak rule backported to the existing taste-skill routing table**, closing a real, already-flagged contradiction risk: the table warns that stacking aesthetic-locked skills "can produce contradictory instructions," but never resolves which one fires when more than one plausibly matches.

The second item exists because `claude-infra-reference`'s taste-skill routing table and CLAUDE.md §2a's agent-stylebooks routing table solved the same shape of problem (many near-tied candidates) at different times, with different rigor — agent-stylebooks got an explicit tiebreak rule during its own grilling pass; the taste-skill table never did, and the two patterns don't reference each other.

## Background / Problem

- `claude-infra-reference/SKILL.md` (confirmed via direct read, ~3,000 words) has 5 existing `## External Skill Integration(s) (<name> / <author>)` sections, each following the same skeleton (install mechanism → gap filled → conflict relationship → "When to invoke"), plus one 12-row `Situation | Use | Notes` routing table for the taste-skill family. No procedural section documents this skeleton or the routing-table convention — each was reconstructed by reading prior sections as examples.
- The taste-skill routing table's own intro text states the risk directly: "installing more than one [aesthetic-locked skill] into context for the same task can produce contradictory instructions." No rule resolves it. The clearest near-tie cluster: `design-taste-frontend`, `minimalist-ui`, `high-end-visual-design`, `industrial-brutalist-ui`, `stitch-design-taste` — all plausibly match a generic "build/redesign a UI" request.
- CLAUDE.md §2a (agent-stylebooks, installed 2026-09-05, one day before this spec) hit the identical shape of problem — 8 of 16 stylebooks all plausibly match "generic technical documentation" — and resolved it during grilling with a two-part rule: fire an org-named option only on a concrete platform/geography signal; with no signal, default to a named family anchor rather than guessing or firing nothing.
- Confirmed via `grep -n "agent-stylebooks\|stylebook" skills/claude-infra-reference/SKILL.md`: zero matches. The two patterns don't cross-reference each other, so a session using either file has no signal that the other's tiebreak convention exists.

## Anti-goals

- Do NOT modify agent-stylebooks' own routing table, tiebreak rule, or plugin files — CLAUDE.md §2a is already grilled and approved; this spec only adds a pointer to it.
- Do NOT invent a 4th install mechanism — only document the decision procedure for the 3 already in use (plugin marketplace, `npx skills`, vendored clone).
- Do NOT re-rank or change any existing taste-skill routing-table recommendation — the tiebreak rule only resolves which row fires when more than one already-documented row plausibly matches; it doesn't add or remove rows.
- Do NOT extract a shared standalone skill for routing/tiebreak/precedence conventions (Option 3, rejected during brainstorming) — only 2 instances of this pattern exist; not enough to justify an abstraction yet.
- Do NOT scope the new procedure section to design/frontend skills only — it must generalize to any future skill-bundle integration (the original issue's ask), which is why it references agent-stylebooks as a second worked example even though agent-stylebooks isn't a "design skill."

## Design

### 1. New section: "External Skill Integration Procedure"

**Placement:** in `skills/claude-infra-reference/SKILL.md`, after `## Custom Plugin Registration` and before the first existing worked-example section (`## External Skill Integrations (mattpocock/skills)`) — it documents the procedure those sections already followed by hand.

**Content:**

1. **When to use this** — evaluating or installing any new third-party skill or skill bundle: a design/frontend skill, an editorial stylebook, or any future category.
2. **Evaluate for overlap** — check the candidate against every routing table it could plausibly join (this file's taste-skill table; CLAUDE.md §2a's stylebook table). Note whether it's aesthetic-locked / a full system-prompt (high conflict risk) or a composable capability layer like `silk-design` or `make-interfaces-feel-better` (low risk — composes rather than competes).
3. **Choose the install mechanism** — decision guide built from the 3 mechanisms already in use, each confirmed against a real prior integration:
   - Repo has `.claude-plugin/marketplace.json` → `claude plugin marketplace add <repo>` then `claude plugin install <name>@<name>` (used for `refero`).
   - Loose multi-skill repo, no marketplace manifest, want specific skills copied in → `npx skills@latest add <repo> <skill-names...> --global --copy -y` (used for `mattpocock/skills` and `taste-skill`). Two gotchas to carry into the new section: `-s/--skill` doesn't reliably filter non-interactively — pass names positionally, or install everything and prune with `npx skills remove`; and `--global` resolves to the real `~/.claude/skills/` path regardless of `cwd`, bypassing worktree isolation — run this from the main checkout, not inside a worktree.
   - Single-skill MIT repo, no marketplace manifest → vendor directly: `git clone <repo>`, strip `.git`, commit the files as regular tracked content (used for `silk-design`, matching the existing `superpowers`/`senior-engineering-partner` convention).
4. **Conflict & Precedence Check** (new — generalized from the agent-stylebooks tiebreak pattern):
   - If the candidate could plausibly match the same trigger/situation as an existing routing-table row, that's a near-tie. Add an explicit tiebreak rule before considering the integration done: a concrete signal (platform, geography, explicitly named aesthetic) resolves it first; with no signal, default to a named anchor — never leave it to per-session guessing.
   - If the candidate governs a different *concern* on the same output rather than competing for the same slot (e.g., voice vs. structure vs. correctness), that's layering, not a tie. Document it as an explicit `Layer | Owner | Governs | Fires` table rather than scattering the relationship across prose bullets.
   - A routing table's own intro prose naming a contradiction risk without resolving it (as the taste-skill table currently does) counts as an open item — resolve it as part of the next integration that touches that table, per item 2 below.
5. **Write the integration section**, reusing the skeleton already used by all 5 existing sections:
   ```
   ## External Skill Integration (<name> / <author-or-org>)

   - **Install:** <exact command(s), from step 3>
   - **Fills:** <what gap it fills / what it does>
   - **Relationship:** <composes freely with X / mutually exclusive with Y / layered under Z>
   - **When to invoke:** <trigger>
   ```
6. **Add or extend the routing-table row**, reusing whichever table's existing column format applies (3-column `Situation | Use | Notes` for the taste-skill table; the corresponding 2-column format if extending a different table).

**Cross-reference (end of section):** "For a second worked example of this routing-table-plus-tiebreak pattern applied to a different skill family, see CLAUDE.md §2a (agent-stylebooks)."

### 2. Backport: taste-skill routing table tiebreak rule

**Placement:** new subsection immediately after the existing 12-row routing table, inside `## External Skill Integrations (taste-skill / Leonxlnx)`.

**Content:**

> **Tiebreak rule:** `design-taste-frontend`, `minimalist-ui`, `high-end-visual-design`, `industrial-brutalist-ui`, and `stitch-design-taste` all plausibly match a generic "build or redesign a UI" request, and each is a full aesthetic-locked system prompt — stacking more than one risks contradictory palette, font, or persona instructions. Fire a named-aesthetic skill (`minimalist-ui`, `high-end-visual-design`, `industrial-brutalist-ui`) only when the user names that aesthetic explicitly, or `stitch-design-taste` only when the target is actually Google Stitch. With no explicit aesthetic or platform signal, default to the family anchor, `design-taste-frontend`, rather than guessing among the named options or firing none.

This mirrors CLAUDE.md §2a's tiebreak shape exactly: concrete signal first, else a named anchor, no guessing among near-ties.

### 3. Cross-reference in CLAUDE.md §2a

Add one line near the top of §2a: "This section's routing-table-plus-tiebreak pattern follows the general convention documented in `claude-infra-reference`'s External Skill Integration Procedure."

## Documentation updates (files touched)

1. `skills/claude-infra-reference/SKILL.md` — new "External Skill Integration Procedure" section; new tiebreak subsection under the taste-skill routing table; one cross-reference line.
2. `CLAUDE.md` — one cross-reference line added to the top of §2a. No other change to §2a's existing content.

No change to agent-stylebooks' plugin files, to the taste-skill routing table's existing rows/recommendations, or to any other skill file.

## Out of scope

- Rewriting or re-ranking any existing routing-table row.
- Building a shared standalone routing/tiebreak skill (rejected: only 2 instances exist so far).
- Retrofitting the procedure onto integrations that predate it (mattpocock, taste-skill, make-interfaces-feel-better, silk-design, refero) beyond the tiebreak backport in item 2 above.
- Any change to agent-stylebooks' own repo, marketplace registration, or SKILL.md files.
