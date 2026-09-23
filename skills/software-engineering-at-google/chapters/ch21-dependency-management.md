# Chapter 21: Dependency Management

## Core Idea
Dependency management is what source control becomes once you cross an organizational boundary you don't control — prefer source control problems (shared repo, full visibility, CI) over dependency-management problems (external code, no coordination) whenever you can widen the definition of "organization" to make that trade.

## Frameworks Introduced
- **The Diamond Dependency Problem**: `libuser` depends on `liba` and `libb`, both of which depend on `libbase`. If `liba` needs `libbase` v1 and `libb` needs `libbase` v2, `libuser` cannot satisfy both — requires at least 3 layers of dependency to occur.
  - When to use: as the canonical model for any conflicting-requirements problem (version, OS, compiler flag, hardware) — treat any conflicting requirement as "a hidden node in the dependency graph."
  - How: C++ has near-zero tolerance (violates One Definition Rule); Java tolerates it via symbol renaming ("shading"/"versioning"); no language solves it cleanly once types cross the boundary between library versions.
- **Four Dependency-Management Models**: Nothing Changes (static/no versions), Semantic Versioning (SemVer, SAT-solver based), Bundled Distribution (a distributor curates a mutually compatible set and versions the bundle, e.g. Linux distros), Live at Head (always depend on current head; CI on downstream dependents is the safety net, no version numbers at all).
  - When to use: Nothing Changes is the default/correct starting model for new, short-lived projects. Bundled Distribution suits ecosystems with a dedicated curator (OS distros). Live at Head is Google's internal model, viable only within a single visible, CI-covered organization or a fully test-covered OSS graph.
- **Minimum Version Selection (MVS)** (Russ Cox, 2018, Go): when a requirement says `liba requires libbase >= 1.7`, resolve to exactly 1.7, not the newest available (e.g., not 1.8+).
  - When to use: as a higher-fidelity alternative to "always pick newest" SemVer resolution.
  - How: walk each dependency forward only as far as required by explicit constraints — this produces "high-fidelity builds" close to what the author actually tested against, since the author of `liba` almost certainly developed against 1.7 specifically.

## Key Concepts
- **Hyrum's Law**: with enough users of an API, every observable behavior (documented or not) will be depended upon by someone — the reason SemVer's "safe" patch/minor bumps still break people in practice.
- **SemVer (Semantic Versioning)**: major.minor.patch version scheme where major = breaking API change, minor = additive, patch = non-API-impacting; a human's *estimate* of risk, not a proof.
- **ABI compatibility**: binary-level compatibility (built artifacts link across versions) — distinct from and stricter than API/source compatibility.
- **third_party**: Google's monorepo directory for imported OSS/external dependencies, governed by an OWNERS-based policy.
- **Live at Head**: dependency-management analogue of trunk-based development — no pinned versions; providers must not land a change that breaks visible downstream CI.
- **Dependency hell**: the state where a SAT-solver over SemVer constraints finds no satisfying version assignment.
- **Shading/versioning**: Java-style technique of renaming symbols to let multiple versions of the same library coexist in one build.
- **SD-8 (Standing Document 8)**: the C++ standard's document defining the limited set of changes allowed to the standard library between versions — its de facto ABI-compatibility policy.

## Mental Models
- Think of a dependency as a **contract**: providers and consumers both have rights and obligations, and a provider should be explicit about what it promises to hold stable (API? ABI? for how long?).
- Use the "infinite compute resources" thought experiment to see where SemVer's weaknesses come from: with unlimited CI, you'd never need version-number *estimates* of risk — you'd just run all affected downstream tests and use that as ground truth. SemVer exists as an approximation because compute/visibility/test coverage are limited, not because it's theoretically ideal.
- SemVer is a **lossy compression** of "how risky is this change" into 3 buckets (major/minor/patch); treat SAT-solver results built on it as approximate, not absolute — they can both overconstrain (block compatible versions) and overpromise (allow builds that break at runtime via Hyrum's Law).
- A change is never intrinsically "breaking" or "safe" in isolation — that judgment only exists relative to how real consumers use the API today.

## Anti-patterns
- **Importing a dependency with no ownership plan**: Google's original `third_party` checklist (build works, no duplicate, 2 OWNERS) never required maintenance experience or upgrade planning — packages become simultaneously "critical" (widely, transitively depended upon) and "orphaned" (original owners moved on), producing forced, high-risk, multi-version-jump upgrades under security pressure.
- **Treating SemVer numbers as proof, not estimate**: a maintainer's major/minor/patch choice is human judgment, not a formal guarantee — building a SAT-solver on top of it escalates estimates into false absolutes.
- **Releasing OSS/dependencies without a long-term support mandate**: "throw it over the wall" costs reputation when the project rots externally, and un-synced internal/external forks eventually collide (see gflags case study).
- **Fine-grained-blind major version bumps**: bumping a library's major version for a change to one unused function (e.g., `Bar`) needlessly blocks consumers who only use an unaffected function (`Foo`) — SemVer applied at too-coarse a granularity overconstrains.

## Reference Tables

| Model | Version selection | Assumes | Google/industry example |
|---|---|---|---|
| Nothing Changes | N/A — no versions | Indefinite stability, no need to update | Default posture of most new projects |
| SemVer | SAT-solver over major.minor.patch constraints | Human-estimated compatibility is trustworthy | npm, most package managers |
| Bundled Distribution | Curated by a distributor, versioned as one unit | A dedicated party can test/patch a compatible set | Linux distros |
| Live at Head | "Newest stable version of everything," CI-gated | Tests exist, CI exists, providers test against downstream | Google-internal (monorepo) |

| Project | Compatibility promise |
|---|---|
| C++ standard library | Near-indefinite API + ABI compatibility (SD-8 bounds allowed changes) |
| Java | Source-compatible across versions; older JARs run on newer JVMs |
| Go | Source compatibility promised between releases; no binary compatibility |
| Abseil (Google) | No ABI promise; API changes allowed but must ship an automated migration tool |
| Boost | No compatibility promise between versions — an intentionally experimental proving ground |

## Worked Example
**Google's gflags open-sourcing (circa 2006)**, illustrating the cost of exporting a dependency without a maintenance plan:
1. Google open-sourced its C++ command-line flags library. At the time, Google's tooling couldn't do large-scale refactoring, so the internal copy couldn't be moved/renamed to unify with the OSS release — it became a permanent fork.
2. Legal/licensing rules meant external contributions couldn't be pulled back into the internal version either.
3. Over time, organizational priorities shifted (away from portable binaries like Google Earth, toward an internal-only toolchain), so nobody's job included maintaining OSS portability.
4. Original authors moved on; nobody owned the OSS fork; it silently diverged and was eventually re-forked externally by the community.
5. Separately, some other Google-authored OSS projects had reverse-engineered the *stable common subset* of the internal/external fork APIs and relied on their staying identical (a Hyrum's Law dependency on an unpromised property) from roughly 2008–2017.
6. When Google's C++ library team later changed undocumented internals of the flags implementation for an optimization affecting thousands of CPUs fleet-wide, those external-fork-dependent projects broke, significantly delaying the optimization — not because the API change was hard, but because a small number of projects depended on something never promised.

Lesson drawn by the authors: "Don't release things without a plan (and a mandate) to support it for the long term."

## Key Takeaways
1. Prefer source control problems to dependency-management problems — broaden "organization" scope when possible instead of accepting an external-dependency boundary.
2. Importing a dependency is nearly free for a one-off program; it becomes expensive only under the software-engineering assumption that you'll maintain and upgrade it over time — ask the import-checklist questions (tests? maintainer reputation? compatibility promise? popularity? who owns the upgrade?) before pulling it in.
3. SemVer works "well enough" only at small scale, with fine-grained/well-maintained dependencies and usage staying inside the promised API surface — none of which reliably holds at scale.
4. MVS (pick the minimum satisfying version, not the newest) improves fidelity over naive SemVer resolution by staying closer to what the upstream author actually tested.
5. Live at Head is the theoretically ideal model under infinite compute/visibility, but requires ubiquitous tests, CI, and providers taking responsibility for downstream breakage — a real but costly shift in responsibility.
6. Exporting a dependency (OSS or internal API) is also a long-term cost center, not pure generosity or upside — plan for support before releasing, and remember external users cost far more to maintain than internal ones (AppEngine's 3-year Python/compiler freeze case).

## Connects To
- **Ch 15 (Deprecation)**: exporting dependencies without a support plan directly produces future deprecation pain (gflags, AppEngine).
- **Ch 16 (Version Control and Branch Management)**: trunk-based development is the source-control analogue that Live at Head extends to external dependencies.
- **Ch 18 (Build Systems and Build Philosophy)**: monorepo build visibility is what makes Google's internal Live at Head model tractable.
- **Ch 22 (Large-Scale Changes)**: the tooling needed to actually perform a forced dependency upgrade across a huge, indirectly-dependent codebase is LSC infrastructure.
- **Ch 23 (Continuous Integration)**: Live at Head and the "infinite resources" thought experiment both presuppose CI running downstream tests on every change.
- **Hyrum's Law**: the recurring theoretical justification for why SemVer's compatibility promises are inherently leaky at scale.
