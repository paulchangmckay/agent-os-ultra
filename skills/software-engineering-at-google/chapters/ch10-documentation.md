# Chapter 10: Documentation

## Core Idea
Documentation scales the same way code does — give it ownership, source control, review, and issue tracking — and its quality depends far more on knowing your audience and keeping a singular purpose per document than on writing talent.

## Frameworks Introduced
- **"Documentation Is Like Code" checklist**: have internal rules, live under source control, have clear owners, undergo review, have issues tracked, be periodically evaluated, and (where possible) be measured for accuracy/freshness.
  - When to use: deciding how to manage any documentation set at scale.
  - How: route documentation changes through the same bug tracker, code review tool, and ownership model already used for code, rather than inventing separate documentation-specific workflows.
- **WHO, WHAT, WHEN, WHERE, WHY**: the five framing questions every technical document should answer, usually in its first two paragraphs.
  - When to use: opening any document, since engineers default to jumping straight to "HOW."
  - How: state the audience (WHO), the document's singular purpose (WHAT), its last-reviewed date (WHEN), its canonical location (WHERE), and what the reader should take away (WHY) — a design doc is the exception where WHY often dominates.
- **Three Parameters of Good Documentation**: completeness, accuracy, clarity — rarely all three at once.
  - When to use: deciding what to sacrifice when writing any specific document type.
  - How: reference docs favor completeness (can sacrifice some clarity); conceptual docs favor clarity (can sacrifice completeness/rare-case accuracy); a "good" document is simply one doing its single intended job well.
- **Three Types of Documentation Review**: technical review (accuracy, by a subject matter expert), audience review (clarity, by someone unfamiliar with the domain), writing review (consistency, by a technical writer or volunteer).
  - When to use: reviewing any document intended for a broad or external audience.
  - How: run all three when a document is high-profile or externally published; even one reviewer of any kind beats none.

## Key Concepts
- **Seekers vs. stumblers**: seekers know what they want and need *consistency* to scan quickly; stumblers don't yet know what they need and require *clarity* (overviews, TL;DR framing).
- **Canonical documentation**: the single designated source of truth for a topic, established via ownership, source control (often alongside code, e.g., `g3doc`), or a memorable `go/` link.
- **Freshness date**: metadata (owner + last-reviewed date) attached to a document that triggers reminder emails after a set staleness period (e.g., three months).
- **g3doc**: Google's framework for embedding Markdown documentation directly alongside source code in the same directory tree.
- **API comments vs. implementation comments**: API/reference comments must not leak implementation details and can't assume reader familiarity; implementation comments can assume more domain knowledge but should still explain non-obvious choices.
- **Design document**: a required-before-coding artifact covering goals, implementation strategy, and trade-off-explicit alternative designs — reviewed like a pre-code-review code review.

## Mental Models
- Treat documentation exactly like testing: it costs effort up front with no immediate benefit to the author, but that cost is amortized across every future reader — worth it precisely because a document is read far more often than it's written.
- Never mix document types on one page: a document should do one job (reference, design doc, tutorial, conceptual doc, or landing page) — monolithic "everything" wiki pages fail because no single audience is served well and no one reads past a few screens.
- Write for the audience "standing where you once stood, but without your new domain knowledge" — you don't need to be a great writer, just willing to see the material from a novice's perspective.
- Landing pages should act only as a "traffic cop": if content on a landing page does more than link elsewhere, it's not doing its job, and it shouldn't try to serve both an API's customers and the team's own internal needs at once.

## Anti-patterns
- **Writing only for yourself**: the single most common documentation mistake — assumptions that seem obvious to the author cost every future reader who lacks that context.
- **Monolithic wiki pages mixing purposes**: conceptual info, broken links, and API reference all on one dozens-of-screens page — nobody reads it and nobody maintains it.
- **Documenting design decisions inside API reference docs**: users of an API don't need implementation rationale; that belongs in a separate design document.
- **Unowned documentation**: without a clear owner, documents rot; GooWiki's median document had ~90% of pages with no views or updates in months by the time it was deprecated.
- **A landing page serving two masters**: mixing "here's how customers use our API" with "here's our team's internal info" confuses both audiences — split them.

## Code Examples
```cpp
// File comment header (str_cat.h)
// -----------------------------------------------------------------------------
// str_cat.h
// -----------------------------------------------------------------------------
//
// This header file contains functions for efficiently concatenating and
// appending strings: StrCat() and StrAppend(). ...

// Function comment: leads with an indicative verb, folds pre/postconditions
// and exceptions into a single prose comment rather than artificial
// "Returns:"/"Throws:" boilerplate sections.
// Creates a new record for a customer with the given name and address,
// and returns the record ID, or throws `DuplicateEntryError` if a
// record with that name already exists.
int AddCustomer(string name, string address);
```
- **What it demonstrates**: Google's comment conventions optimize for "seekers" (consistent structure to scan quickly) and avoid boilerplate that adds verbosity without added clarity.

```
<!--* # Document freshness: For more information, see go/fresh-source.
freshness: { owner: `username` reviewed: '2019-02-27' } *-->
```
- **What it demonstrates**: the freshness-date metadata block that triggers staleness reminders and gives every document an explicit, incentivized owner.

## Reference Tables

| Document type | Primary audience need | Trade-off favored |
|---|---|---|
| Reference (incl. code comments) | Seekers scanning for a specific answer | Completeness over clarity |
| Design docs | Decision-makers evaluating trade-offs | Explicit WHY and alternatives |
| Tutorials | Newcomers with zero domain knowledge | Explicit, numbered, single-actor steps |
| Conceptual docs | Both novices and experts needing the big picture | Clarity over completeness/strict accuracy |
| Landing pages | Anyone orienting themselves | Pure navigation ("traffic cop"), no content |

## Worked Example
**Case Study: The Google Wiki (GooWiki).** Early Google used a single internal wiki for nearly all documentation. It initially seemed to work — everyone shared one editable set of pages — but broke down at scale: no true document owners meant pages went stale unnoticed; no process for adding documents meant duplicates proliferated (at one point, 7–10 different documents existed for setting up Borg, most unmaintained and scoped to specific teams' permissions); the flat namespace meant no hierarchy. Critically, the people who *could* fix bad documents rarely needed them anymore, while the people who *needed* them (new users) couldn't tell if a document was wrong or how to report it. Documentation became Google's #1 developer complaint in annual surveys. The fix: move documentation into source control, alongside the same workflows used for code — explicit owners, canonical locations in the source tree, bugs filed against broken docs, changes reviewed like code changes. Result: quality improved (despite fears that adding review/ownership overhead would make things worse), Markdown lowered the editing barrier, and the `g3doc` framework let documentation live directly beside the source it described — engineers began sending fixes directly to owners instead of merely complaining.

## Key Takeaways
1. Give every document an owner and put it under source control with review — an unowned document is a document that will rot.
2. Write to a specifically identified audience (and consider whether they're a "seeker" needing consistency or a "stumbler" needing an overview) rather than to yourself.
3. Keep each document to a single purpose; when content doesn't fit that purpose, split it into a separate document rather than appending it.
4. Accept that completeness, accuracy, and clarity trade off against each other — decide deliberately which two your document type needs most.
5. Use freshness dates and named owners to make staleness visible and cheaply correctable, rather than relying on someone eventually noticing a page is wrong.
6. Reserve scarce technical writers for cross-API/cross-team documentation (where an outside, unfamiliar perspective is the actual value they add) rather than embedding them permanently on high-priority teams that can write their own docs fine.

## Connects To
- **Ch 3**: Knowledge Sharing — documentation is one of the core mechanisms (alongside `go/` links and readability) for scaling institutional knowledge.
- **Ch 8**: Style Guides and Rules — the C++ style guide's evolution into a broader "C++ Developer Guide" is this chapter's own example of a rules document becoming canonical documentation.
- **Ch 9**: Code Review — documentation reviews (technical/audience/writing) mirror, and often are literally part of, the code review process.
- **Ch 17**: Code Search — Google's reliance on Code Search to surface in-source reference documentation reduced the need for separately generated API docs.
