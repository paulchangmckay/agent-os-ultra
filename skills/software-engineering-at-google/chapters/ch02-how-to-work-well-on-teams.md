# Chapter 2: How to Work Well on Teams

## Core Idea
Software engineering is a team endeavor, not a solo craft — working in isolation is inherently riskier than working with others, and the discipline that makes collaboration work rests on three pillars: humility, respect, and trust.

## Frameworks Introduced
- **The Three Pillars of Social Interaction**: Humility, Respect, Trust.
  - When to use: as a root-cause lens for any social/team conflict — trace the conflict back to a missing pillar.
  - How: **Humility** — you're not the center of the universe, you're open to self-improvement. **Respect** — you genuinely care about coworkers and appreciate their abilities. **Trust** — you believe others are competent and let them drive when appropriate.
- **Googleyness rubric**: a defined, non-vague replacement for the informal "Googley"/"not Googley" test, created to prevent unconscious bias in hiring/reviews ("Googley" risked meaning "just like me").
  - When to use: hiring and performance-review calibration.
  - How: six named attributes — thrives in ambiguity, values feedback, challenges status quo, puts the user first, cares about the team, does the right thing.

## Key Concepts
- **The Genius Myth**: the false belief that landmark software (Linux, Python, the Macintosh) was the product of one solitary genius, rather than a leader coordinating a large collective effort.
- **Bus factor**: the number of people who'd need to disappear (not just literally "get hit by a bus" — also marriage, relocation, attrition, leave) before a project is doomed; more shared ownership = higher bus factor.
- **Psychological safety** (via "Hiding Considered Harmful"): the freedom to share unfinished, imperfect work without fear of judgment — the antidote to insecurity-driven secrecy.
- **Early detection**: sharing work-in-progress surfaces design mistakes and wheel-reinvention while they're still cheap to fix.
- **Pace of progress**: teams (like compilers) work best in tight feedback loops — solo, cave-dwelling work loses this loop entirely.
- **Blameless postmortem**: a Google-standard document explaining what was learned and what will change — explicitly not a list of apologies, excuses, or blame.
- **"You are not your code"**: self-worth must not be tied to a specific piece of output, so criticism of the code isn't criticism of the person.
- **Compliment sandwich (rejected)**: the softening technique of wrapping criticism in praise — flagged in this chapter's companion discussion as something to avoid because it buries the actual message (see Ch 5 for the full argument).

## Mental Models
- Use the "bicycle-design enthusiast in the garage" scenario whenever you're tempted to work in secret until something is "perfect" — early external feedback would have caught the flaw in week one instead of month three.
- Think of the compiler feedback loop (write a function → compile → add a test → compile) as the template for how a *team* should also get feedback — via code review, standups, pairing — not just how an individual should treat their code.
- When giving criticism, reframe from accusation ("you got this wrong") to self-directed confusion ("I'm having trouble following this — would X make it clearer?") — this keeps the discussion on the code, not the person's competence.
- Treat vulnerability as a credibility signal, not a weakness: admitting "I don't know" or "I made a mistake" increases trust and status over time, unlike a politician's reflexive denial of error.

## Anti-patterns
- **Hiding your code / working in a cave**: increases risk of fundamental design mistakes, forfeits collaboration benefits, and produces a single point of failure (low bus factor).
- **Genius-worship as an excuse for poor social skills**: "100% of the work requires a minimal level of social skills" — being a genius does not excuse being a jerk; poor collaborators are poor teammates regardless of talent.
- **Harsh, unsolicited code review without buy-in** (the "Joe" story): technically valid criticism delivered without first establishing team norms or trust reads as an attack, not help.
- **Open-plan offices taken to the extreme**: a hundred-plus engineers in one room with zero walls is "just as bad" as fully private offices — both fail to balance focus time against high-bandwidth team connection.
- **Stubbornness / being closed to influence**: team members route around a person whose mind never changes regardless of evidence — the fix is being genuinely open to persuasion.

## Reference Tables
| Recommended patterns (cooperative) | Antipatterns (adversarial) |
|---|---|
| Basic questions/mistakes are guided in the proper direction | Basic questions/mistakes are picked on |
| Explanations given to help the asker learn | Explanations given to show off one's own knowledge |
| Responses are kind, patient, helpful | Responses are condescending, snarky |
| Interactions are shared discussions | Interactions are arguments with "winners"/"losers" |

## Worked Example
Karl and the author were pair-programming on a CVS-to-Subversion/Git conversion tool and kept hitting bizarre CVS bugs. The author is a bottom-up engineer (dive into the muck, try things quickly); Karl is top-down (map the whole call stack before touching the bug). Paired directly, this style clash produced repeated, genuinely frustrating conflict — to the point they couldn't pair-program together at all. Because they had a longstanding foundation of trust and respect, they didn't abandon the collaboration; instead they redesigned *how* they worked: sit together to identify the bug, then split up and attack it from both directions independently, and reconvene with findings. Patience plus an existing reserve of trust let them invent a new working mode rather than force one style onto the other — illustrating that the three pillars aren't abstract ideals, they're what makes it possible to actually resolve a real interpersonal friction point without losing the collaboration.

## Key Takeaways
1. Share work-in-progress early and often — the risk of hiding it (wasted effort, low bus factor, missed feedback) outweighs the discomfort of being seen mid-mistake.
2. Diagnose team conflict by checking which of humility, respect, or trust is missing, rather than treating it as a personality clash.
3. Phrase criticism as your own confusion or a question, not as a verdict on someone else's competence — it keeps the conversation about the code.
4. Document failures via blameless postmortems that produce concrete follow-up actions, not blame or apology.
5. Build bus factor deliberately: pair, document, and avoid all-or-nothing single ownership of any critical area.
6. Being open to having your mind changed is a source of influence, not a loss of it — stubbornness gets you routed around.

## Connects To
- **Ch 3 Knowledge Sharing**: bus factor and psychological safety are picked up and formalized there (mentorship, SPOFs, information islands).
- **Ch 5 How to Lead a Team**: humility/respect/trust, blameless postmortems, and "lose the ego" are extended into leadership-specific patterns, including the full critique of the compliment sandwich.
- **Ch 9 Code Review**: the "learn to give and take criticism" section is the cultural foundation for Google's code review norms.
- **Ch 1 What Is Software Engineering?**: reinforces that software engineering is inherently a "multiperson" activity, echoing Ch 1's definition.
