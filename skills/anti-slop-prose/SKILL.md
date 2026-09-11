---
name: anti-slop-prose
description: >
  Edit AI-drafted prose for purpose, specificity, and voice while treating
  the source as a hard constraint. Use for email drafts, Slack/notification
  text, essays, LinkedIn/social posts, and business-analysis docs — any
  prose with an audience outside the current conversation. Do not use for
  code, code comments, commit messages, PR/issue text, or a plain
  conversational reply. Never optimizes for or predicts AI-detector scores;
  never invents facts, quotes, or details.
---

# Anti-Slop Prose

<!-- Adapted from udaysharmadev/Not-Ai — see THIRD_PARTY_NOTICES.md -->

An editorial skill, not an authorship test or detector-bypass tool. Its job is
to make prose sound like a particular person with particular facts, not like a
generic idea of "human writing."

## Scope: when this fires

Fires on: any prose content that will be read by someone other than the
current user in this conversation, whether or not it is saved to a file —
email drafts, Slack/notification text, essays, business-analysis docs,
LinkedIn/social posts. This is broader than `agent-stylebooks`' scope
boundary (which requires an actual saved document) — this skill fires even on
ephemeral chat text, as long as it has an audience outside this conversation.

Does NOT fire on: code, code comments, a plain conversational reply addressed
to the user themself, or git/GitHub process artifacts (commit messages, PR
titles/descriptions, issue bodies) — those stay governed by existing git
conventions.

**Minimum-length threshold:** skip the full workflow below for text under
~15 words or a single short sentence (e.g. "Running 10 min late, be there
soon"). Write it naturally instead.

**Brand-voice precedence:** for `linkedin`, `social`, and `email` genres
specifically, the `brand` skill's HARD-GATE voice (formality, word choice)
always wins over this skill's register recommendations (contractions,
first-person casualness) — no per-skill exception. Those 3 profiles still
contribute their structural guidance (information order, paragraph shape).
The `personal`, `fiction`, `student`, `academic`, `technical`, and `readme`
profiles are unaffected.

## Non-negotiable rules

1. Preserve facts, names, numbers, citations, technical terms, and the author's actual position.
2. Never invent an experience, opinion, uncertainty, quote, source, result, name, number, or sensory detail if given.
3. Never add mistakes, slang, filler, fake emotion, or "imperfections" to simulate a person.
4. Never optimize against an AI detector, predict a detector score, or claim the result proves human authorship.
5. Do not force a rewrite. If the passage is already strong, return it unchanged or make only the edits that clearly help.
6. Keep code, equations, quotations, citations, table data, and required terminology intact unless the user asks otherwise.
7. If a missing personal detail would materially improve the piece, use a bracketed prompt or ask one concise question. Do not fill the gap yourself.
8. Never add em dashes.

## Choose the mode

Default to the fullest useful result supported by the user's material.

- `rewrite`: rewrite the whole submitted passage to its full potential while preserving meaning.
- `preserve`: make the fewest edits needed to remove stiffness or ambiguity.
- `diagnose`: identify issues and quote the relevant spans; do not rewrite.
- `from-notes`: write a complete, detailed draft from scratch using only the facts and views the user supplied.

Detector-focused requests do not change the method. Briefly state that detector scores are inconsistent and that the skill will optimize for clarity, specificity, fidelity, and voice instead.

## Establish the writing contract

Before editing, determine these five things from the prompt and text:

1. **Purpose:** what the piece must accomplish.
2. **Audience:** who will read it and what they already know.
3. **Genre:** one of the 9 profiles below.
4. **Register evidence:** the level of formality and style already present in the draft.
5. **Protected content:** facts, claims, quotations, citations, terminology, formatting, and length constraints that must survive.

Do not interrogate the user when the contract is obvious. Infer the contract silently and use a neutral, direct register when the draft gives weak evidence.

### Genre fallback mapping

For content types that don't map cleanly to a named profile: Slack/notification
text → `social`; business-analysis docs → `technical`; anything else with no
clear match → `email` (the most neutral formal-but-conversational default).

## Protect the source before rewriting

Create a private ledger with four columns:

| Type | What belongs here | Editing rule |
|---|---|---|
| Fact | names, dates, numbers, events, results | preserve exactly unless correcting an explicit error |
| Claim | conclusions, opinions, confidence level | preserve strength and direction |
| Voice | idioms, preferred words, humor, formality | retain when natural and intelligible |
| Structure | headings, order, required format | change only when it improves the stated purpose |

Mark unsupported gaps separately, e.g. `[specific result]`, `[what changed your mind]`. A bracket is honest; a fabricated detail is not.

## The editorial pass

Work paragraph by paragraph, not with global synonym replacement.

1. **Find the paragraph's job.** Each paragraph should make a claim, tell an event, explain a mechanism, give evidence, qualify a conclusion, or request an action. If it does none of these, cut it or combine it with the paragraph that does.
2. **Put the useful information first.** Replace broad scene-setting with the fact, action, or question the reader needs.
3. **Replace abstraction with supported detail.** Use the genericity counterfactual: could this sentence survive unchanged if the names, setting, and subject were replaced? If yes, inspect its job. If the source lacks the detail, leave a bracketed prompt.
4. **Make agency clear.** Name who decided, built, observed, or changed something when the source supports it. Passive voice is fine when the actor is unknown or irrelevant.
5. **Remove empty framing** — `It is worth noting that`, `In today's fast-paced world`, `plays a crucial role in`, `serves as a testament to`, `This demonstrates the importance of` — without banning individual words.
6. **Repair rhythm by ear.** Split sentences that carry unrelated jobs. Join choppy sentences when the relationship is clearer together. Never manufacture length variation to hit a numeric target.
7. **Keep logical transitions, remove mechanical ones.** `But`, `Because`, `For example` can mark real relationships. Delete `Moreover` or `Additionally` when it's decoration.
8. **Preserve uncertainty.** Don't turn `may` into `will` or `suggests` into `proves`. Remove ceremonial hedges that merely postpone the claim.
9. **End on substance** — the final consequence, decision, image, result, or next action, not a repeated summary.

## Grammar mechanics (Elements of Style)

Adapted from William Strunk Jr.'s *The Elements of Style* (1920, public domain) — mechanical correctness checks that sit alongside the editorial pass above, not a replacement for it.

- **No comma splices.** Never join two independent clauses with a bare comma. Use a semicolon, a period, or a coordinating conjunction with a comma before it. If the second clause opens with an adverb (`however`, `therefore`, `accordingly`), use a semicolon — never a comma.
- **No dangling modifiers.** An opening participial phrase must modify the sentence's actual grammatical subject. "Turning the corner, the building came into view" dangles — the building didn't turn the corner.
- **Parallel construction.** Co-ordinate ideas take matching grammatical form — a list of gerunds stays gerunds, a list of infinitives stays infinitives.
- **Filler-noun recast, don't patch.** `case`, `character`, `factor`, `feature`, `nature`, `system` used as padding (e.g. "acts of a hostile character" instead of "hostile acts") signal the sentence's real subject is hiding. When caught, rewrite the sentence from its actual subject — don't just swap in a synonym. This is the same failure mode [`references/why-word-swapping-fails.md`](references/why-word-swapping-fails.md) already names from the AI-tell-vocabulary angle; this is its classical-grammar counterpart.
- **End-emphasis.** Put the word or phrase you want the reader to remember at the end of the sentence — the position of emphasis.
- **One tense per summary.** Keep a single tense throughout a given passage or summary; don't drift between past and present without reason.

## Genre profiles

Genre detection runs first. Every profile still obeys the same fidelity and no-invention rules. Read [`references/profile.md`](references/profile.md) for the linguistic-research context behind these checks.

### LinkedIn and social (`linkedin`, `social`)

Lead with the actual event, observation, or claim. Keep paragraphs easy to scan. Use first person only for the author's real experience. Avoid manufactured vulnerability, engagement bait, inflated lessons, and decorative emoji. (Register recommendations here are superseded by brand voice — see Scope above.)

### Personal essay (`personal`)

Preserve the author's odd, specific choices and emotional restraint. Keep chronology intelligible without sanding away digressions that reveal voice. Replace labels such as "inspiring" with supported moments when available.

### Professional email (`email`)

Put the purpose or request near the top. Match the relationship and level of formality. Make owners, dates, and next steps explicit. Do not add friendliness the sender did not express. (Register recommendations here are superseded by brand voice — see Scope above.)

### Student project report (`student`)

First person is appropriate when the student actually did the work. Keep methods, datasets, results, limitations, and citations exact. Explain decisions using supplied constraints, not invented stories about confusion or discovery. Avoid forced casualness unless that register already exists in the source. Convert objective checklists into grammatical parallel lists.

### Formal academic writing (`academic`)

Preserve disciplinary terminology, cautious claims, citations, and necessary nominalization. Prefer precision over conversational tone. Do not add first person unless the venue or author uses it. Never strengthen causality or generalize beyond the evidence.

### Technical documentation and README files (`technical`, `readme`)

Optimize for correctness, navigation, and successful action. Use imperative steps where appropriate. Keep identifiers, commands, code, warnings, and prerequisites exact. Remove marketing language that obscures behavior.

### Fiction (`fiction`)

Preserve point of view, tense, characterization, and intentional repetition. Do not normalize dialect or unusual syntax unless asked. Add no sensory detail, motivation, or backstory absent from the source.

## Quality gate

Review every deliverable against these checks:

1. **Fidelity:** every factual statement and claim is supported by the input or a cited source.
2. **No invention:** no new biography, result, quotation, feeling, stance, or concrete detail appears.
3. **Purpose:** the opening and organization serve the requested outcome.
4. **Specificity:** vague language is replaced only where the source supports something clearer.
5. **Voice:** diction and rhythm fit the available voice evidence and genre (subject to brand-voice precedence above).
6. **Logic:** transitions reflect real relationships; references and pronouns are unambiguous.
7. **Restraint:** no needless framing, repeated conclusion, inflated significance, or padded list.
8. **Register:** formality, contractions, fragments, and technical vocabulary fit the audience.
9. **Protected content:** names, numbers, citations, quotations, code, and required terminology survive.
10. **Mechanics:** grammar and punctuation are correct unless the source intentionally departs from them.
11. **Em dashes:** before sending newly authored prose, check for the `—` character and replace every instance with punctuation that preserves the sentence's meaning.
12. **Grammar mechanics:** no comma splices, no dangling modifiers, co-ordinate ideas in parallel form, filler nouns (`case`, `character`, `factor`, `feature`, `nature`, `system`) recast rather than patched — see Grammar mechanics above.

### Running the deterministic gate

For text saved to a file:

```bash
python3 skills/anti-slop-prose/scripts/gate.py draft.txt --genre linkedin
```

For ephemeral text drafted inline (the common case — a Slack message or email that's never saved to disk), pipe it via stdin, no temp file needed:

```bash
echo "$draft" | python3 skills/anti-slop-prose/scripts/gate.py --stdin --genre email
```

Use `--protect` once per literal fact or term that must appear in the deliverable, and `--ascii-punctuation` only when the writer or publication has explicitly requested that house style. The gate's findings are editorial prompts, reviewed in context — not obeyed mechanically. Read [`references/vocabulary.md`](references/vocabulary.md) for guidance on the tier-1/tier-2 vocabulary findings, [`references/mechanical-tells.md`](references/mechanical-tells.md) for the mechanical-pattern findings, and [`references/why-word-swapping-fails.md`](references/why-word-swapping-fails.md) when a rewrite is turning into a synonym pass.

For a broader, optional diagnostic pass (word/sentence density, readability grade, stance markers), run `scripts/metrics.py` the same way. See [`references/research-sources.md`](references/research-sources.md) for the citations behind both scripts' checks.

Never show the gate's raw output to the user — read the findings, revise if warranted, and present only the final text, unless a disclosure note is genuinely warranted below.

## Output

For a normal rewrite, return the revised text without a long preamble. Add a short note only when needed to disclose:

- the assumed genre or audience;
- a bracketed fact the author must supply;
- a material ambiguity;
- a fidelity concern;
- that detector-score optimization was not performed.

For diagnosis, use:

```text
Genre: [genre]
Keep: [strong choices worth preserving]
Revise: [issue, quoted span, and reason]
Missing: [information needed for a stronger draft]
```
```
