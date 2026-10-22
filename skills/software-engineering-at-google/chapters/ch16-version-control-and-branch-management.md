# Chapter 16: Version Control and Branch Management

## Core Idea
A Version Control System (VCS) extends a filesystem's `filename → contents` mapping to `(filename, time, branch) → contents`; the hardest part of using one at scale is not the technology but the policy layered on top of it — above all, having exactly one Source of Truth and enforcing a One-Version Rule for dependencies.

## Frameworks Introduced
- **The One-Version Rule**: "Developers must never have a choice of 'What version of this component should I depend upon?'"
  - When to use: any time a codebase (monorepo or not) risks having two live copies/forks of the same library checked in simultaneously.
  - How: for third-party packages, allow only one checked-in version at steady state; for internal packages, forbid unrenamed forks — it must be safe to link both original and fork into the same binary with no special effort. Exception: mid-migration, briefly allow two versions while blocking new dependents from picking the old one.
- **Source of Truth**: one specific branch in one specific repository is declared authoritative; a change is "done" only once merged there.
  - When to use: always — DVCS does not give you this for free, unlike centralized VCS, so it must be established as policy.
  - How: pick a canonical repo+branch (e.g., trunk on the primary GitHub/GitLab repo, or Piper's trunk at Google); treat anything else as a copy in progress.
- **Trunk-based development**: commit small changes directly and frequently to trunk rather than long-lived feature/dev branches; rely on tests, CI, and feature flags (disable-at-runtime) to keep trunk stable.
  - When to use: as the default policy for any team past the "single dev, single machine" scale.
  - How: keep dev branches minimal or absent; if a feature isn't ready, land it disabled behind a flag rather than on a parallel branch.

## Key Concepts
- **VCS(filename, time, branch) => file contents**: the author's formal model of what a VCS actually provides over a plain filesystem.
- **Atomicity**: a commit touching multiple files is treated as a single unit; VCSs lacking this (e.g., CVS) were prone to corruption and lost changes.
- **Centralized VCS**: single central repository is the only place commit operations land (RCS, CVS, Subversion, Perforce).
- **Distributed VCS (DVCS)**: any clone is itself a full repository you can commit to locally (Git, Mercurial); centrality becomes a matter of policy, not technology.
- **Dev branch**: a halfway point between "uncommitted" and "on trunk," used to shield trunk from unstable in-progress work — the book argues this is "inherently misguided" as a stability strategy.
- **Release branch**: a branch capturing exactly what shipped, used for cherry-picked hotfixes; expected to be abandoned, not merged back.
- **Monorepo**: a single repository holding (nearly) all of an organization's source, as used at Google via Piper.
- **Virtual Monorepo (VMR)**: a federation of fine-grained repositories stitched together (via submodules, external deps, etc.) to approximate monorepo semantics without its costs.
- **Piper**: Google's in-house, centralized, cloud-hosted VCS storing 80+ TB and handling 60,000–70,000 commits/day.
- **OWNERS files**: per-directory text files in Piper listing engineers allowed to approve commits in that subtree — ownership as policy, not repository partitioning.

## Mental Models
- Think of choosing a VCS like choosing a filesystem format: at a technical level the differences are minor (any modern VCS gives you the same atomic-commit semantics); what actually matters is the policy and content you build on top.
- Treat every piece of uncommitted work-in-progress as conceptually "a branch" — this reframes questions like "rename Widget everywhere" to include outstanding, unmerged changes, not just what's on trunk.
- Use the DORA research finding as a forcing function: trunk-based development and absence of long-lived dev branches are *predictive* of high-performing engineering organizations — treat branch-heavy workflows as a symptom to be fixed at the root (testing/CI), not managed around (merge coordinators, scheduled merge meetings).
- View shading/symbol-renaming tricks to coexist multiple versions of a library as pure overhead: "the work to get those approaches working is entirely lost labor" — they patch around a One-Version violation rather than fixing it.

## Anti-patterns
- **Long-lived dev branches used for stability**: the same commits still merge to trunk eventually; batching them via a shared branch just makes merges bigger, failures harder to triage, and requires a dedicated "Merge Coordinator" role — a symptom of a scaling problem, not a fix for one.
- **No declared Source of Truth under DVCS**: without one, features accumulate in disparate un-synced clones; someone ends up manually bookkeeping "what's ready for release," which reinvents centralization anyway, informally and without tooling support.
- **Allowing silent library forks on trunk**: a team forks and tweaks shared infrastructure (e.g., a fixed copy of Abseil) without renaming it; any binary that transitively depends on both the original and the fork either fails to build or suffers hard-to-debug linker/runtime bugs.
- **Automatically-managed "latest" external dependency versions**: acceptable for hobby projects, a recipe for unreproducible builds at any real scale (build system consequence covered further in Ch. 18/21).
- **Shading/type-hiding tricks to allow multiple versions of the same library**: works for functions, fails for any exported type ("vocabulary type") — the fundamental multi-version problem is only hidden, not solved.

## Reference Tables

| Aspect | Centralized VCS | Distributed VCS |
|---|---|---|
| Where can you commit? | Only the central repo | Any clone, then push |
| Source of Truth | Built into system design | Must be established as policy |
| Offline work | Limited | Strong |
| Origin era | 1970s–80s (RCS), 90s–2000s (CVS, Subversion) | Mid-2000s onward (Git, Mercurial) |
| Google's approach | Piper (custom, centralized, cloud-scale) | — |

## Worked Example
**Scenario: Multiple Available Versions (One-Version violation).** A team discovers a bug in common infrastructure code (e.g., Abseil or Guava). Instead of fixing it in place, they fork the library, tweak it to work around the bug, but keep the original symbol/library names, and tell nearby teams, "we have an improved version checked in over here." A few teams build on top of this fork.

Now any project that transitively depends on *both* the original and the forked copy is in trouble: best case, the build fails outright because of duplicate symbols; worst case, two mismatched versions link into the same binary and produce runtime bugs that are extremely hard to diagnose. The fork has effectively partitioned the codebase — any link crossing from the "original" partition to the "fork" partition is a landmine. What began as "adding a new dependency" now potentially requires running the entire codebase's test suite to check for partition violations, which doesn't scale.

Attempted technical workaround: Java-style "shading" (renaming a library's internal symbols to hide them from the rest of the app). This works for functions but fundamentally cannot work for any type passed between packages — there's no efficient way to shade a vocabulary type. The only real fix is the One-Version Rule: never let this fork exist unrenamed in the first place.

## Key Takeaways
1. Adopt version control for anything beyond a single-developer throwaway project — the cost is low and the risk-reduction value is consistently judged worth it by experienced engineers.
2. Enforce a single, explicit Source of Truth branch+repository, even under a DVCS model that doesn't require one technically.
3. Apply the One-Version Rule: eliminate developer choice over which version of a dependency to use — this single policy prevents diamond dependencies, merge-strategy debates, and wasted effort.
4. Default to trunk-based development with minimal/no long-lived dev branches; use tests, CI, code review, and runtime feature flags to keep trunk stable instead of parallel branches.
5. Release branches are comparatively low-cost and fine to use for cherry-picked hotfixes — the technology of branching isn't the problem, the *usage pattern* of dev branches is.
6. Choice of monorepo vs. many fine-grained repos is a secondary decision; what matters is holding to One-Version regardless of repository topology (a VMR can deliver similar guarantees without a literal single repo).

## Connects To
- **Ch 18 (Build Systems and Build Philosophy)**: the One-Version Rule and diamond-dependency problem reappear as a build-system concern (Bazel enforces strict transitive dependencies and manual, explicit external-dependency versions).
- **Ch 21 (Dependency Management)**: version control policy (fine-grained, your-own-code) contrasted directly with dependency management (coarser-grained, other organizations' code, less control).
- **Ch 22 (Large-Scale Changes)**: trunk-based development is a prerequisite for LSCs — an unbounded set of hidden dev branches would make broad refactors unmanageable.
- **Ch 23 (Continuous Integration) / Ch 24 (Continuous Delivery)**: trunk-based development plus strong CI is presented as the alternative to dev-branch-based stability strategies.
- **DORA / *Accelerate* research**: cited repeatedly as the external evidence base for trunk-based development correlating with high-performing organizations.
