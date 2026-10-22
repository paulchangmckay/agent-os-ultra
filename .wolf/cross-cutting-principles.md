# Cross-Cutting Principles

Principles that apply to all skills. Read as a mandatory checklist during
any skill creation or regeneration.

---

## Active Principles

- **Never skip the final whole-branch review as a formality.** Task-scoped reviews structurally cannot catch bugs that only manifest across the whole diff or under a real invocation context (different cwd, different test fixture) the task reviewer's own diff happened not to exercise. A clean run of every per-task review is not evidence the whole branch is clean. (Source: Observation 19)

- **Trace the actual call sequence before attaching a change to a named operation.** When a spec or plan names a specific function/operation as the point a schema or data change attaches to, verify by reading the real code path that the named operation actually fires at that point in the flow — not just that the design is architecturally sound. A change can be well-designed and thoroughly grilled while still attaching to the wrong operation. (Source: Observation 21)

- **Re-verify every discrete sub-claim of an inherited claim, not just the headline.** When re-checking a claim from a subagent, an earlier audit pass, or prior conversation turns, confirming a few concrete examples match does not confirm the other details riding along with it (where something lives, how many places, which mechanism is responsible). Partial verification creates false confidence in the unverified parts — check each sub-claim independently, especially the ones that feel already-covered by adjacent verification. (Source: Observation 26)

- **A test assertion is itself a claim, not just a verification tool.** This applies with extra force to negative/absence assertions (proving old code was broken, proving a case was uncovered). Before writing "X was broken before, Y fixes it," actually run the real "before" case against the real code and confirm it fails for the stated reason — don't reason about it in the abstract. An inverted assertion silently proves nothing. (Source: Observation 27)

- **A plugin file existing in `plugins/marketplaces/**/commands/*.md` says nothing about whether it actually runs.** Before proposing changes to or building a use-case on any such file, grep `settings.json`'s `enabledPlugins` for that plugin's key first — it may not be enabled. Separately, check whether the same command name is shadowed by a capability compiled into the CLI binary itself (visible in the Skill tool listing with no matching repo file) — a same-named native command can be the thing that actually fires, unrelated to the plugin file entirely. (Source: Observation 30)

- **A shell command embedded in a skill's instructions needs live verification of its edge cases, not just its happy path.** Three independent failure modes surfaced only by actually running the literal command, never by reading the prose: a reset/cleanup command with a variable pathspec that can go empty (degrading to "operate on everything" instead of "operate on nothing"); a real pipe character written inside a markdown table cell with a `\|` escape, which an agent copying the raw file text verbatim will copy as a literal backslash, breaking the pipe; and a `command | sed`/`| grep` extraction pipeline, whose exit status reflects the downstream tool, silently swallowing an upstream failure a Failure-handling rule depended on. Before shipping a skill that instructs running a multi-step or variable-driven shell command, run it against the actual edge case (empty input list, a no-match case, a literal copy-paste of the table text) rather than trusting that the command reads correctly. (Source: Observation 34)
