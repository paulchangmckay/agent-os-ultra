# Agent Stylebooks Integration — Design Spec

Date: 2026-09-05
Status: Approved, grilled

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
claude plugin enable agent-stylebooks@agent-stylebooks
```

This registers the marketplace under `plugins/marketplaces/agent-stylebooks` and adds the plugin flag to `settings.json`'s `enabledPlugins` map — the same tracked state as every other plugin-installed capability in this environment. No manual file copying, no separate `npx`-based tool, no `.claude/skills/` clutter.

Verified directly against the repo (grilling pass, 2026-09-05): `.claude-plugin/marketplace.json` names the marketplace `agent-stylebooks` and lists a single bundled plugin also named `agent-stylebooks` (source `./`), so the enable command above is exact, not a placeholder. `.claude-plugin/plugin.json` confirms 16 skills are bundled — 3 more than the 13 named in the README's routing table: `18f-content`, `mailchimp-content`, and `red-hat-docs`. All three are folded into the routing and tiebreak rules below.

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
| Customer education, campaign copy, onboarding email, newsletter | `$mailchimp-content` (structure only — see Voice precedence) |
| US federal digital-government page, form, notice, transactional message | `$18f-content` (only when a US-federal signal is present — see Tiebreak rule) |
| Enterprise Linux/OpenShift administration, installation, configuration, troubleshooting | `$red-hat-docs` (only when a Red Hat/OpenShift platform signal is present — see Tiebreak rule) |

Auto-detection only selects a stylebook when the deliverable's genre clearly matches a row. Ambiguous or mixed-genre content with no tiebreak resolution gets no stylebook rather than a guessed one — silence beats a wrong guess, since a wrong genre match would apply the wrong structural convention.

### Tiebreak rule (added during grilling)

Grilling surfaced a gap the routing table alone doesn't resolve: 8 of the 16 stylebooks — `$google-developer-docs`, `$gitlab-docs`, `$github-docs`, `$kubernetes-docs`, `$red-hat-docs`, `$mdn-web-docs`, `$w3c-technical-reports`, `$nasa-technical-writing` — all plausibly match generic "technical documentation," and their own catalog descriptions overlap (e.g. GitLab: "administration, contributor, and engineering documentation"; Red Hat: "administration, installation, configuration, troubleshooting"; GitHub: "developer workflows, product help, troubleshooting"). The same pattern recurs for `$18f-content` vs `$govuk` (both match generic "public-service content").

Resolution, confirmed with the user:

1. **Concrete platform/geography signal first.** Fire an org-named stylebook only when the deliverable is actually about that platform or jurisdiction — `$kubernetes-docs` only for content actually about Kubernetes, `$red-hat-docs` only for content actually about Red Hat/OpenShift, `$gitlab-docs` only when the work lives in or documents a GitLab-hosted project, `$github-docs` only when the work lives in or documents a GitHub-hosted project, `$18f-content` only when the content is explicitly US-federal.
2. **No platform/geography signal at all → default to the family's anchor stylebook**, rather than guessing among near-ties or firing none:
   - Generic technical documentation with no named platform → `$google-developer-docs` (least platform-specific of the 8, and the one already anchoring the original routing table).
   - Generic public-service content with no US/UK signal → `$govuk` (already the routing-table anchor; `$18f-content` only fires on an explicit US-federal signal).
3. This tiebreak applies wherever two or more stylebooks in this spec's routing table would otherwise match the same content with no distinguishing signal — not just the two clusters named above.

## Voice precedence (confirmed with user)

Brand voice always wins, with no per-stylebook exceptions. When a stylebook's native voice example (e.g., $apple-interface-writing's casual microcopy, or $mailchimp-content's "plainspoken, empathetic, lightly playful" content voice) would conflict with the user's formal Personal Brand Guide voice, brand voice governs word choice and tone; the stylebook still governs structure (what to lead with, ordering, genre convention) for that deliverable.

Grilling explicitly tested whether voice-defined stylebooks like `$mailchimp-content` — whose entire purpose is a specific tone — should get an exception. Confirmed: no exception. One precedence rule for all 16 stylebooks keeps the system predictable; a growing exception list would be its own source of workflow confusion. `$mailchimp-content` still contributes its email/campaign structural conventions; tone stays formal brand voice regardless.

## Scope: install all 16

The layering rule and tiebreak rule (previous sections) make every stylebook — including the 5 that share genre territory with `iso-24495-3` and the 3 that overlap within the pack itself — safe to install without redundancy or guessed selection. No curation needed.

## Reply vs. deliverable scope (confirmed during grilling)

Stylebooks fire only when creating or editing an actual saved document, docs page, or content file — never for a plain conversational reply, even one that is substantively documentation-shaped (e.g., explaining an API inline in chat). Conversational replies stay governed solely by the always-on `iso-24495-1` output style. This keeps a firm, unambiguous line between "governs this chat reply" and "governs this deliverable" — the exact ambiguity the user wanted to avoid.

## Storage location

Global `~/.claude`, plugin-installed (per Install mechanism above) — matching `brand` and `iso-24495-plain-language`, both of which are general-purpose writing capabilities available across all projects, not scoped to one project.

## Documentation updates

1. **CLAUDE.md Section 2 (Process Layer table):** add a row routing genre-matched writing tasks to agent-stylebooks, referencing the layering rule.
2. **New CLAUDE.md subsection** (adjacent to Section 2, e.g. "2a. Editorial Stylebooks"): documents the three-layer precedence table, the auto-detect routing table, the tiebreak rule, the no-exception voice precedence, and the reply-vs-deliverable scope boundary above, so future sessions apply all of this without re-deriving it.
3. No change needed to the `brand` skill or `iso-24495-*` skill files themselves — the layering rule is additive, not a modification of their existing behavior.

## Out of scope

- Modifying agent-stylebooks' own SKILL.md files (they're used as-is, per the repo's MIT-licensed, community-maintained content).
- Building any custom dispatch tooling — auto-detection relies on Claude's existing skill-description matching, the same mechanism that already auto-fires `brand` and `iso-24495-3`.
- Retrofitting past documents/PRs to the new stylebooks.
