# Chapter 7: Measuring Engineering Productivity

## Core Idea
Only measure engineering productivity when the result will drive a concrete, already-empowered decision; when you do measure, derive metrics from goals through the Goals/Signals/Metrics chain so you measure what matters instead of what's easy (the streetlight effect).

## Frameworks Introduced
- **Goals/Signals/Metrics (GSM) framework**: a goal is a desired end result (no metric reference); a signal is how you'd know you achieved it (may be unmeasurable); a metric is a measurable proxy for a signal.
  - When to use: any time you're about to define what to measure for a software process.
  - How: write goals first with zero mention of measurement, derive one-or-more signals per goal, then derive one-or-more metrics per signal — maintaining traceability back through the chain.
- **QUANTS**: the five components of engineering productivity, always in trade-off with one another — **Qu**ality of the code, **A**ttention from engineers, **I**ntellectual complexity, **T**empo and velocity, **S**atisfaction.
  - When to use: while defining goals, to ensure you don't optimize one productivity dimension (e.g., velocity) while silently damaging another (e.g., quality).
  - How: check whether each QUANTS component has an applicable goal; "n/a" for a component is fine, but check deliberately rather than by omission.
- **Triage questions** (five questions to ask before measuring anything): What result do you expect, and why? If the data supports it, what action follows? If the result is negative, will action still be taken? Who decides, and when? Can that decision maker act on the form of evidence you'll produce?
  - When to use: before committing research-team resources to any productivity measurement request.
  - How: if any answer reveals the result won't change a decision (or there's no empowered decision maker), don't measure.

## Key Concepts
- **Streetlight effect**: measuring only what's easily accessible instead of what actually serves the goal (named for "looking for keys under the streetlight").
- **Metrics creep / metrics bias**: the risk of stakeholders proposing new metrics after the fact specifically because initial results didn't match their expectations.
- **Traceability**: the requirement that every metric map back through a signal to a goal.
- **Anecdata**: disparaged term for anecdotal evidence — the book argues structured interviews and case studies still have real, complementary value alongside quantitative data.
- **Experience sampling study**: a study design that interrupts engineers in the moment of doing a task (e.g., right after starting a build) to capture in-context feedback.
- **Vanity metric**: a metric whose result won't change a decision already made for other reasons — a top reason *not* to measure.

## Mental Models
- Treat "we can't measure it precisely" as a legitimate GSM outcome, not a failure — GSM surfaces gaps in measurement coverage so you can consciously decide whether to invest in new metrics or accept the gap.
- When quantitative and qualitative metrics disagree, suspect the quantitative metric first — Google's research team found this was consistently the case in practice.
- Treat quantitative metrics as giving you scale/power and qualitative studies as giving you the "why" — neither alone tells the complete story; use both to triangulate.

## Anti-patterns
- **Measuring to validate a decision already made for other reasons**: if the team would proceed regardless of the result, the measurement adds no value (the release-tool-team example — they'd ship the improvement either way).
- **Using imprecise proxy metrics under pressure**: falling back to lines-of-code or similarly weak proxies when the "right" metric is unavailable produces uninterpretable, confirmation-biased results.
- **Measuring when a negative result won't change anything**: the single most common reason the research team kills a proposed measurement project.
- **Optimizing one QUANTS dimension while ignoring the others**: e.g., "I can make your review velocity very fast: just remove code reviews entirely" — a real risk when a team fixates on tempo/velocity goals alone.

## Reference Tables
Condensed from the chapter's Table 7-1 / 7-2 (Goals → Signals → Metrics for the readability-process study):

| QUANTS | Goal | Signal (example) | Metric (example) |
|---|---|---|---|
| Quality | Engineers write higher-quality code as a result of readability | Readability has a positive impact on code quality | Survey: % reporting readability improved code quality |
| Intellectual complexity | Engineers learn best practices via the process | Engineers report learning from readability | Survey: % reporting they learned relevant topics |
| Tempo/velocity | Engineers complete tasks faster as a result | CLs from readability-granted authors review faster | Logs: median review/shepherd/submit time, with vs. without readability |
| Satisfaction | Engineers see the process as worthwhile | Engineers view the process as an overall positive experience | Survey: % reporting positive overall experience |
| Attention | n/a for this study | n/a | n/a |

## Worked Example
**Readability process evaluation.** The C++ and Java language teams asked: is the (expensive, hundreds-of-engineers-deep) readability review process still worth its cost now that autoformatters and linters exist? Triage: the team didn't know the expected result (unlike most requests); it committed in advance to killing the process per-language if costs outweighed benefits; the decision makers (language leads) trusted self-reported survey data for happiness/learning but wanted logs-based "hard numbers" for velocity and quality — so the research plan mixed both. GSM: goals spanned four of five QUANTS components (no Attention goal was needed); each goal produced one or more signals (e.g., "engineers who've been granted readability judge their code higher quality"); each signal was measured via a combination of a post-process readability survey, a broader quarterly survey, and fine-grained tool logs — triangulating because no single source captured the true signal. Result: readability was judged worthwhile — engineers who completed it were satisfied, felt they'd learned, and (per logs) had their code reviewed and submitted faster even net of needing fewer reviewers — while also surfacing concrete UX pain points the language teams then fixed in the tooling.

## Key Takeaways
1. Before measuring, confirm someone empowered will act on both a positive *and* a negative result — otherwise don't spend the resources.
2. Derive metrics from goals via GSM (goal → signal → metric), never metrics-first, to avoid the streetlight effect and post hoc metric-swapping.
3. Cover all five QUANTS dimensions when setting goals so you don't trade one form of productivity for another without noticing.
4. Treat qualitative data (surveys, interviews) as real metrics, not filler — and treat quant/qual disagreement as a signal your quantitative metric is probably wrong.
5. Aim recommendations at the tool/workflow layer, not exhortations to "just be more careful" — behavior change sticks when it's built into daily habits.

## Connects To
- **Ch 3**: Knowledge Sharing — the readability process (the chapter's running example) is defined and motivated there.
- **Ch 9**: Code Review — the readability approval bit measured here is one of the three approval types in Google's code review process.
- **Ch 6**: Leading at Scale — GSM-style quantified trade-off analysis is the same discipline used in the Search latency case study (quality vs. latency vs. capacity).
- **Frederick P. Brooks, *The Mythical Man-Month***: cited for the quadratic communication-cost argument motivating why per-engineer productivity, not just headcount, must scale.
