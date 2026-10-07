---
name: session-reflect
description: Use at the end of any substantive coding session — captures patterns, mistakes, and decisions into .wolf/cerebrum.md, and conditionally updates CLAUDE.md with project context worth preserving for the team
---

# Session Reflect Skill

End-of-session audit with three phases. Phase 1 (cerebrum) always runs automatically. Phase 2 (CLAUDE.md) runs only when something team-worthy was learned. Phase 3 (skill observation review) runs on a 7-day fallback cadence.

## Phase 1: Cerebrum Update (always)

1. **Check OpenWolf active**
   ```bash
   ls .wolf/memory.md 2>/dev/null && echo "ACTIVE" || echo "NO_WOLF"
   ```
   If NO_WOLF: report skip, proceed to Phase 2 anyway.

2. **Read the session log**
   Read `.wolf/memory.md` — focus on entries from today's date.

3. **Identify patterns worth remembering**
   - Mistake that cost time? → Do-Not-Repeat
   - Non-obvious decision with good rationale? → Decision Log
   - User expressed style/tool/approach preference? → User Preferences
   - Bug fixed that might recur? → buglog.json

   Aim for 1–3 high-signal entries. Zero is fine for routine sessions.

4. **Append to `.wolf/cerebrum.md`** (read first, then append only new entries):
   ```markdown
   ## Do-Not-Repeat
   - YYYY-MM-DD: <specific mistake or anti-pattern to avoid>

   ## User Preferences
   - YYYY-MM-DD: <preference expressed this session>

   ## Key Learnings
   - YYYY-MM-DD: <project convention or non-obvious behavior discovered>

   ## Decision Log
   - YYYY-MM-DD: <decision made and why>
   ```
   Keep entries specific and dated. Vague entries decay in value; precise ones compound.

5. **Update buglog.json for any newly fixed bugs**
   If a bug was fixed with a reusable fix pattern, append to `.wolf/buglog.json`:
   ```json
   {
     "id": "bug-<next-number>",
     "error_message": "<exact error text>",
     "file": "<file/path.ts>",
     "root_cause": "<why it happened>",
     "fix": "<what was changed>",
     "tags": ["<category>"],
     "occurrences": 1,
     "last_seen": "<ISO date>"
   }
   ```

6. **Resolve this session's observation-log checkpoints**
   Check `.wolf/observations.md` for OPEN `compaction-checkpoint` or
   `write-batch-checkpoint` entries whose `**Session:**` field matches this
   session. For each: if the session produced a real insight worth keeping,
   resolve it as ACTIONED and fold the content into a proper entry via
   `node scripts/wolf-observation-log.js append` (with a `skill-improvement`
   or `new-skill-candidate` type as appropriate); otherwise resolve DECLINED:
   ```bash
   node scripts/wolf-observation-log.js resolve <N> DECLINED "nothing to log this session"
   ```

7. **Check for a new-skill candidate**
   Ask: "was there a repeating 3+-step manual workflow this session that no
   existing skill covers?" If yes, log it — flag only, never create the
   skill automatically:
   ```bash
   echo '{"type":"new-skill-candidate","skill":"New skill candidate: <working name>","issue":"<what the repeating workflow was>","improvement":"<what a skill for this would need to cover>","principle":"<why this generalizes beyond this session>"}' | node scripts/wolf-observation-log.js append
   ```

## Phase 2: CLAUDE.md Audit (conditional)

8. **Assess — did this session reveal anything CLAUDE.md-worthy?**
   Ask: "Would a future Claude session working in this project be helped by knowing this?"
   - New commands or build/test invocations discovered?
   - Environment or configuration gotchas?
   - Non-obvious code patterns or conventions?
   - Warnings or constraints that apply project-wide?

   If none of the above: skip to step 11.

9. **Find CLAUDE.md files**
   ```bash
   find . -name "CLAUDE.md" -o -name ".claude.local.md" 2>/dev/null | head -20
   ```
   Decide per addition: `CLAUDE.md` (team-shared, checked into git) vs `.claude.local.md` (personal, gitignored).

10. **Draft additions and get approval**
    One line per concept. Format: `<command or pattern>` — `<brief description>`
    Avoid verbose explanations, obvious info, one-off fixes unlikely to recur.

    Present as diffs before writing:
    ```
    ### Update: ./CLAUDE.md
    **Why:** [one-line reason]
    + [the addition]
    ```
    Apply only changes the user approves.

## Phase 3: Skill Observation Review (conditional, 7-day fallback)

11. **Check whether a review is due**
    ```bash
    cat .wolf/observations-last-review.txt 2>/dev/null || echo never
    ```
    If the value is `never` or the date is more than 7 days old, AND
    `.wolf/observations.md` has at least one `### Observation` header whose
    Status is not ACTIONED/DECLINED (statusless entries count as OPEN — never
    filter by grepping for the literal string `OPEN`, since that silently
    drops entries missing a Status line): offer one line — "The
    skill-observation backlog hasn't been reviewed [in N days / yet] — run it
    now, or wrap up?" Never gate the user's task on this; proceed either way.

    **Model-tier usage skim (same cadence as step 11).** When a review is due,
    also skim `.wolf/claude-model-usage.jsonl` — read it from the main
    checkout (the hook writes under `CLAUDE_PROJECT_DIR`, not the worktree):
    - Look for a subagent_type/model pattern worth flagging — e.g. repeated
      `opus` or `fable` dispatches for a subagent_type that isn't in
      `config/claude-tier-limits.json` (so nothing blocked it). Entries with
      `model: null` are dispatches that omitted `model` (inherited default).
      A `capped: true` line normally means an over-cap explicit request, but
      can also mean an invalid `max_tier` in that config file — check it.
    - If you find one, log it with `scripts/wolf-observation-log.js append`
      (type `skill-improvement`, skill `model-routing`). Describe the pattern
      and cite a few example log lines.
    - This step only creates the observation and never resolves it. It then
      flows into step 12's normal OPEN-entry handling.

12. **If the user accepts the review:**
    a. Archive first:
       ```bash
       node scripts/wolf-observation-log.js archive
       ```
    b. **Scan for cross-session recurrence — delegate this to a dispatched
       subagent**, rather than reading the sources directly. This keeps 90
       days of archive text, buglog.json, and cerebrum.md out of this
       session's context, matching how this repo already routes
       multi-file research to a subagent. The task requires judgment
       (matching "substantially the same friction," not locating a known
       string), so dispatch it as a general-purpose research subagent, not
       the narrower Explore type — Explore's own description excludes
       "open-ended analysis" and "cross-file consistency checks," which is
       exactly this scan.

       List the remaining OPEN entries first (title, type, skill, issue
       text for each — including any logged this session by step 7), then
       dispatch one subagent with:
       - that list of OPEN entries to check for recurrence
       - instructions to read `.wolf/observations-archive/*.md` (files
         dated within the last 90 days only — a match found only in an
         older file counts as not found), `.wolf/buglog.json`, and current
         `.wolf/cerebrum.md` (Do-Not-Repeat, Key Learnings, Decision Log
         sections, read as a live snapshot — `cerebrum.md` is rewritten
         wholesale weekly by the `cerebrum-reflection` cron, so there's no
         stable history to diff against)
       - instructions to report back, per OPEN entry: whether a match was
         found; if so, a one-line citation (e.g. "Observation #4 (DECLINED
         2026-07-20)", "buglog bug-142 (2 occurrences)", "cerebrum
         Do-Not-Repeat line 12"); and whether the match was itself a prior
         **resolution** (an ACTIONED archive entry or an existing cerebrum
         bullet) as opposed to a DECLINED entry or a bare occurrence count
         — this distinction drives the escalation rule in step (d)

       The subagent only reports findings — it never writes to any file or
       makes the tier/routing decision. Those stay here, in this session,
       where the approval gates live.
    c. Enumerate the remaining OPEN entries and cross-check each against
       the skill(s) it names. For each one, also use the subagent's report
       from (b) to see whether it matched something already seen: another
       observation (archived or still open), a recurring buglog bug, or an
       existing cerebrum bullet. Its citation is what you'll record as
       evidence in step (e).
    d. For each entry, decide how to act on it:
       - **Escalation rule (check this first):** if the entry matches
         something already **resolved** — an ACTIONED entry in the archive,
         or a pattern already present in cerebrum's Do-Not-Repeat — treat it
         as **Substantial** below, regardless of how small the pattern would
         otherwise look. A fix that already exists and didn't stop the
         recurrence needs a stronger intervention, not a second copy of the
         same small fix. (A match against only a DECLINED entry, or only a
         buglog `occurrences` count with no prior fix attached, does *not*
         trigger this rule — that's repetition without a prior remedy, not a
         fix that failed.)
       - **Small additive** (new rule, clarification, factual fix — and the
         escalation rule above doesn't apply): route by what the pattern is
         about, not open judgment:
         - tied to a specific named skill's behavior → show an inline diff
           of the proposed SKILL.md change, apply on approval, write live
         - a general mistake or preference not tied to any one skill →
           append to cerebrum.md's Do-Not-Repeat section, using the same
           append method as Phase 1 step 4
         - a project-wide fact, convention, or environment gotcha → a
           CLAUDE.md addition, using the same diff-and-approve pattern as
           Phase 2 step 10
       - **Substantial** (restructuring, new capability, any
         new-skill-candidate the user wants to build, or anything the
         escalation rule forced here): hand off to the `github-issue-first`
         skill to file the issue — if this entry has recurrence evidence
         from (c), include it in the issue body as the "why now" citation —
         then the normal `using-git-worktrees → test-driven-development →
         verification-before-completion → requesting-code-review` pipeline.
    e. Mark the entry:
       ```bash
       node scripts/wolf-observation-log.js resolve <N> ACTIONED "<what was applied>"
       ```
       or
       ```bash
       node scripts/wolf-observation-log.js resolve <N> DECLINED "<why not>"
       ```
       If this entry had a recurrence match from step (c), add it as a
       citation with `--evidence`:
       ```bash
       node scripts/wolf-observation-log.js resolve <N> ACTIONED "<what was applied>" --evidence "Recurs: Observation #4 (DECLINED 2026-07-20), buglog bug-142 (2 occurrences), cerebrum Do-Not-Repeat line 12"
       ```
    f. Write today's date to `.wolf/observations-last-review.txt`.

## Step 13: Report

```
Session reflect complete:
- cerebrum.md: N entries added [or: no high-signal patterns this session]
- buglog.json: [updated / not updated]
- CLAUDE.md: [M additions applied / nothing team-worthy this session]
- observations.md: [K entries resolved / review skipped or not due]
Most important learning: <one sentence>
```
