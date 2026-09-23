# Chapter 1: What Is Software Engineering?

## Core Idea
Software engineering is programming integrated over time — the discipline of keeping code useful, correct, and adaptable across a life span, team size, and set of trade-offs that programming-in-the-small never has to face.

## Frameworks Introduced
- **Sustainability**: "Your project is sustainable if, for the expected life span of your software, you are capable of reacting to whatever valuable change comes along, for either technical or business reasons."
  - When to use: evaluating whether a codebase/organization can survive its own required upgrades (compiler, OS, dependency, product direction).
  - How: preserve the *capability* to change, even if you choose to defer a given change — capability, not obligation, is the test.
- **Hyrum's Law**: "With a sufficient number of users of an API, it does not matter what you promise in the contract: all observable behaviors of your system will be depended on by somebody."
  - When to use: any time you plan an interface change, deprecation, or "harmless" internal refactor.
  - How: treat it like entropy — never eliminated, only mitigated (reduce user count, reduce observability of the behavior, or reduce time exposed).
- **The Beyoncé Rule**: "If you liked it, you should have put a CI test on it." An infrastructure change that breaks something not covered by CI is not the fault of the change.
  - When to use: setting policy for how much infrastructure teams owe downstream teams for untested behavior.
  - How: make CI the sole contract of correctness; untested expectations don't count as obligations.
- **The Churn Rule** (2012): infrastructure teams that force a migration must do the migration work themselves, or land it backward-compatibly — never push the churn onto every downstream customer team.
- **Shifting Left**: catching a problem earlier in the dev workflow (design → implementation → review → test → commit → canary → production) is always cheaper than catching it later.

## Key Concepts
- **Programming vs. software engineering**: programming produces code; software engineering is "the multiperson development of multiversion programs" — it adds time and scale as first-class dimensions.
- **Expected life span**: reasonable answers range over a factor of ~100,000 (minutes to decades); best practices that fit one end are wrong for the other.
- **Cost (six kinds)**: financial, resource, personnel, transaction, opportunity, societal — "cost" in engineering decisions is never just dollars.
- **Policies that scale**: a policy is scalable if the work it imposes on one engineer does not grow linearly (or worse) as the org grows 10x or 100x.
- **Boiled-frog problems**: slow-creeping costs (build time, checkout time, upgrade cost) that never trigger a single crisis moment and so go unmonitored until crippling.
- **Jevons Paradox**: consumption of a resource can rise in response to greater efficiency in its use (observed in Google's distributed build system).
- **Technical debt** (informal definition given here): the delta between what "should" be done and what has actually been done.

## Mental Models
- Think of the "cube isn't a square" analogy: short-lived code is software engineering compressed to zero on the time axis — it looks like plain programming, but only because the time dimension vanished, not because a different discipline is at work.
- Use the "it's programming if 'clever' is a compliment, but it's software engineering if 'clever' is an accusation" test to decide which mode you're in for a given piece of code.
- Treat Hyrum's Law like thermodynamic entropy: you plan around it and mitigate it, you never defeat it.
- Use the "expertise + automation + consolidation" triad (drawn from the 2006 compiler upgrade retrospective) as the lens for any recurring, scale-sensitive task: can a few experts absorb repeated cost instead of every team paying it independently?

## Anti-patterns
- **"We'll delete the old Widget on August 15th"**: traditional deprecation that pushes migration cost onto every downstream customer team — fails as dependency graphs grow; fix is the Churn Rule.
- **Ever-multiplying dev branches**: "merge less frequently" policies that create per-team branches scale linearly-or-worse in resync/merge overhead as branch count grows.
- **Assuming "nothing will ever change"**: a bet that is survivable for short-lived code and a serious gamble for anything expected to live years (security patches like Heartbleed, Meltdown/Spectre being the canonical counterexamples).
- **"Because I said so"**: any decision justified without evidence, precedent, or argument is where bad engineering decisions hide.
- **Ignoring societal cost**: at billion-user scale, small discrepancies in fairness, accessibility, or abuse potential are magnified — ignoring this cost category is itself a cost.

## Reference Tables
| Cost type | Example |
|---|---|
| Financial | Money |
| Resource | CPU time |
| Personnel | Engineering effort |
| Transaction | Cost to take action |
| Opportunity | Cost of *not* taking action |
| Societal | Impact on society at large |

| Factor (from the 2006 compiler-upgrade retrospective) | What it buys |
|---|---|
| Expertise | Repeated upgrades become routine, not novel |
| Stability | More frequent releases → smaller deltas per upgrade |
| Conformity | Less code depends on implementation quirks |
| Familiarity | Redundant manual steps become automatable |
| Policy | Beyoncé Rule limits scope of "what must not break" |

## Worked Example
Google's 2006 compiler upgrade: after roughly five years without a compiler change, several thousand engineers — almost none of whom had ever been through a compiler upgrade — had to migrate a codebase full of undocumented, Hyrum's-Law-style dependencies on the old compiler's specific behavior (e.g., code relying on `std::string` implementation quirks, or omitting the `std` namespace). There was no Beyoncé Rule yet and no pervasive CI, so the team of mostly volunteers couldn't even be sure what would break. The upgrade was extremely painful. Afterward, Google explicitly invested in making the *next* upgrade cheaper: automation, consolidation/consistency, and centralized expertise, plus policies like the Beyoncé Rule so infrastructure teams only had to worry about CI-visible breakage. The lesson generalizes: the first change of a given kind is always disproportionately expensive; the fix is to invest in making the operation routine rather than declaring it too expensive to repeat.

## Key Takeaways
1. Match your practices to expected code life span — integration tests and SemVer discipline are wasted effort on a script that runs once; they're mandatory for anything meant to last years.
2. Never assume a "no one will notice" behavior is safe to change — Hyrum's Law guarantees someone, eventually, depends on it; weigh the value of the change against the cost of finding and fixing breakage.
3. Before adopting any repeated organizational policy, ask: does this scale sublinearly in human effort as we grow 10x? If not, redesign it (see the Churn Rule as the fix for old-style deprecation).
4. Watch for boiled-frog costs (build times, checkout times) that creep slowly with no single crisis moment — they need active, ongoing monitoring, not reactive firefighting.
5. Base engineering decisions on data, evidence, precedent, or argument — never on "because I said so" — and be willing to revisit decisions when the data changes.
6. When forking vs. reusing a dependency, weigh time (forks are safer for short-lived, narrow-scope code) against scale (forks multiply the surface area for security fixes and maintenance across the org).

## Connects To
- **Ch 15 Deprecation**: the Churn Rule's fix to traditional "we'll delete it on this date" deprecation policy is developed fully there.
- **Ch 16 Version Control and Branch Management**: the dev-branch scaling anti-pattern here is the setup for that chapter's approach (trunk-based development).
- **Ch 18 Build Systems and Build Philosophy**: the distributed-build example (Jevons Paradox, bloat) is expanded there.
- **Ch 21 Dependency Management**: the fork-vs-reuse trade-off under Hyrum's Law is a direct lead-in.
- **Ch 4 Engineering for Equity**: the societal-cost category introduced here is developed at length.
- **Ch 7 Measuring Engineering Productivity**: the "some costs are hard to measure" discussion points forward to EPR's quantification work.
