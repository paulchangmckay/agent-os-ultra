# Agent Stylebooks Integration — Design Spec

Date: 2026-09-05
Status: Approved (pending grilling pass)

## Purpose

Integrate [Neeeophytee/agent-stylebooks](https://github.com/Neeeophytee/agent-stylebooks) — a library of 16 installable Agent Skills, each an editorial/style system derived from a public style guide (Google developer docs, GOV.UK, GitLab docs, GitHub docs, MDN, Kubernetes docs, NHS, CDC, SEC plain English, W3C, NASA, Microsoft Writing Style, Apple Interface Writing, etc.) — into the user's global `~/.claude` setup.

The user's goal: gain genre-specific editorial structure for written deliverables, without overwriting the always-on plain-language output style, without duplicating the `iso-24495-3` technical-writing skill's territory, and without adding a workflow that confuses which skill governs what.

## Anti-goals

- Do NOT let a stylebook override the always-on `iso-24495-1` plain-language floor (sentence length, paragraph limits, active voice) for conversational replies.
- Do NOT let a stylebook override the user's brand voice (formal tone, Personal Brand Guide) for any output.
- Do NOT install via `npx skills add` or as loose files under `skills/` — this would create a second, inconsistent plugin-management convention alongside the existing `claude plugin marketplace add` / `claude plugin enable` pattern.
- Do NOT curate a subset of the 16 stylebooks to dodge overlap with `iso-24495-3` — the layering rule below makes overlap safe by construction, so exclusion isn't needed.
- Do NOT make stylebook selection a second silent auto-trigger layer that's indistinguishable from brand/iso-24495's existing auto-triggers in the user's mental model — it must be documented as its own distinct, lower-precedence layer.

## Install mechanism

Match the existing third-party skill-pack convention already used for `superpowers`, `document-skills`, and `iso-24495-plain-language`:

```sh
claude plugin marketplace add Neeeophytee/agent-stylebooks
claude plugin enable agent-stylebooks@<plugin-name>
```

This registers the marketplace under `plugins/marketplaces/agent-stylebooks` and adds the plugin flag to `settings.json`'s `enabledPlugins` map — the same tracked state as every other plugin-installed capability in this environment. No manual file copying, no separate `npx`-based tool, no `.claude/skills/` clutter.

The exact `<plugin-name>` depends on how the repo's `.claude-plugin/plugin.json` names itself — confirmed during the implementation plan, not guessed here.

## Layering rule (resolves overlap with existing skills)

Three concerns, three owners, no duplication, because each owns a different layer of the same output:

| Layer | Owner | Governs | Fires |
|---|---|---|---|
| Plain-language floor | `iso-24495-1` (+ `iso-24495-3` for technical writing) | Sentence-length ceiling, paragraph limits, active voice, structure/findability | Always — every conversational reply and every document |
| Voice | `brand` (HARD-GATE) | Word choice, tone, formality (Personal Brand Guide: formal voice) | Always, before any output is created |
| Genre structure | agent-stylebooks (auto-detected) | What to lead with, section/procedure ordering, genre-specific terminology conventions | Per matching deliverable only — never for conversational replies |

Precedence when more than one layer applies to the same deliverable: **iso-24495 floor > brand voice > stylebook structure.** A stylebook may never widen a sentence past the iso-24495 ceiling, and may never shift word choice/tone away from the user's brand voice — it only decides structural ordering and genre convention (e.g., $kubernetes-docs' procedure-step ordering, $sec-plain-english's risk-statement framing).

This is why $google-developer-docs / $mdn-web-docs / $kubernetes-docs / $w3c-technical-reports / $nasa-technical-writing (the 5 stylebooks whose genre overlaps `iso-24495-3`'s stated scope of "software documentation, architecture specs, and technical analysis") don't duplicate it: `iso-24495-3` sets the floor for *any* technical writing; the matching stylebook adds the genre-specific convention on top of that floor. Neither skill is redundant with the other.

## Trigger mode: auto-detect by genre

Confirmed with the user (overriding the initial recommendation for explicit-only): stylebooks auto-fire based on the deliverable's genre, the same way `brand` and `iso-24495-3` already auto-fire. The repo's own routing table becomes the auto-detect table:

| Genre signal | Stylebook |
|---|---|
| API or setup tutorial, how-to guide, onboarding instructions | `$google-developer-docs` |
| Public-service eligibility page, decision guide, application instructions | `$govuk` |
| Engineering or product docs, internal documentation, feature guide | `$gitlab-docs` |
| Product workflow, step-by-step guide, troubleshooting article | `$github-docs` |
| Web API explanation, technical reference, learning article | `$mdn-web-docs` |
| Infrastructure procedure, operations runbook, deployment guide | `$kubernetes-docs` |
| Health or patient content, explainer, care instructions | `$nhs-health-content` |
| Public-health message, safety advisory, awareness campaign | `$cdc-clear-communication` |
| Investor disclosure, business report, risk explanation | `$sec-plain-english` |
| Technical specification, standards document, requirements definition | `$w3c-technical-reports` |
| Engineering or test report, research report, findings summary | `$nasa-technical-writing` |
| Product help or UX copy, support article, interface guidance | `$microsoft-writing-style` |
| Interface labels or alerts, microcopy, onboarding flow | `$apple-interface-writing` |
| (Remaining catalog entries beyond these 13) | Per `CATALOG.md`, confirmed during implementation |

Auto-detection only selects a stylebook when the deliverable's genre clearly matches a row. Ambiguous or mixed-genre content gets no stylebook rather than a guessed one — silence beats a wrong guess here, since a wrong genre match would apply the wrong structural convention.

## Voice precedence (confirmed with user)

Brand voice always wins. When a stylebook's native voice example (e.g., $apple-interface-writing's casual microcopy) would conflict with the user's formal Personal Brand Guide voice, brand voice governs word choice and tone; the stylebook still governs structure (what to lead with, ordering) for that deliverable. This keeps output voice consistent across every deliverable regardless of which stylebook fired.

## Scope: install all 16

The layering rule (previous section) makes every stylebook, including the 5 that share genre territory with `iso-24495-3`, safe to install without redundancy. No curation needed.

## Storage location

Global `~/.claude`, plugin-installed (per Install mechanism above) — matching `brand` and `iso-24495-plain-language`, both of which are general-purpose writing capabilities available across all projects, not scoped to one project.

## Documentation updates

1. **CLAUDE.md Section 2 (Process Layer table):** add a row routing genre-matched writing tasks to agent-stylebooks, referencing the layering rule.
2. **New CLAUDE.md subsection** (adjacent to Section 2, e.g. "2a. Editorial Stylebooks"): documents the three-layer precedence table and the auto-detect routing table above, so future sessions apply this without re-deriving it.
3. No change needed to the `brand` skill or `iso-24495-*` skill files themselves — the layering rule is additive, not a modification of their existing behavior.

## Out of scope

- Modifying agent-stylebooks' own SKILL.md files (they're used as-is, per the repo's MIT-licensed, community-maintained content).
- Building any custom dispatch tooling — auto-detection relies on Claude's existing skill-description matching, the same mechanism that already auto-fires `brand` and `iso-24495-3`.
- Retrofitting past documents/PRs to the new stylebooks.
