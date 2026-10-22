# Patterns: Interpretive Techniques

## Casting a Hexagram (Coin Method)
**When to use**: Any live consultation — the standard method for getting a hexagram to interpret.
**How**: Throw 3 coins per line, 6 lines total, bottom to top. Inscribed side (tails) = 2 (yin), reverse side (heads) = 3 (yang). Sum the 3 coins: 6 = old yin (moving), 7 = young yang (static), 8 = young yin (static), 9 = old yang (moving). Run `scripts/cast.py` to do this automatically and get the resulting file references.
**Trade-offs**: Faster and simpler than the yarrow-stalk method, but the source notes the coin method's probability distribution differs slightly from the yarrow-stalk method's (the yarrow-stalk process makes 9 harder to obtain than other values at the first count) — the coin method treats all three outcomes for a given coin as uniform.

## Casting a Hexagram (Yarrow-Stalk Method)
**When to use**: A more traditional, deliberate consultation — the method the Ta Chuan itself describes and grounds cosmologically.
**How**: Take 49 of 50 stalks (1 set aside). Divide into two heaps at random. Take one stalk from the right heap, hold it aside. Count the left heap off by fours; remainder (4 or fewer) held aside. Count the right heap off by fours; remainder held aside. Sum of the three held-aside groups is 5 (counts as 3) or 9 (counts as 2) on the first round; 4 (counts as 3) or 8 (counts as 2) on the second and third rounds. Repeat 3 rounds per line, 6 lines total. Three 3's = 9 (old yang); three 2's = 6 (old yin); two 3's + one 2 = 7 (young yang); one 3 + two 2's = 8 (young yin).
**Trade-offs**: Slower (3 rounds × 6 lines = 18 counting operations) but the Ta Chuan explicitly ties its arithmetic (49 stalks, division into two, one set aside, counting by fours) to a cosmological model — heaven/earth/man, the four seasons, the intercalary month. Choose this method when the deliberateness of the process itself matters to the consultation.

## Reading What You Cast
**When to use**: Immediately after casting, before consulting any chapter file.
**How**: If no lines are moving (all 7s and 8s), read only the primary hexagram's Judgment and Image — the situation as a whole, no line-level detail applies. If one or more lines are moving (any 6s or 9s), also read the text of each moving line, and read the resulting hexagram's Judgment and Image (the direction the situation is moving toward). The source (Appendix I) does not specify a different priority ordering for hexagrams with several moving lines at once — read all of them.
**Trade-offs**: Simplicity over sophistication — later I Ching traditions add more elaborate rules for weighting multiple moving lines against each other; this translation's own appendix does not, so don't import a rule the source doesn't state.

## Identifying the Two Primary Trigrams
**When to use**: The first step of any structural reading, before touching correspondence or ruling lines.
**How**: Split the hexagram into lower (lines 1-3) and upper (lines 4-6) trigrams. Look up each trigram's attribute, image, and family role in `ch65-discussion-of-the-trigrams.md`. A hexagram's core meaning is often just its two trigrams' images combined (e.g., Water below Fire = "quarreling" in Conflict; Fire below Water = "mutual distrust" in Before Completion).
**Trade-offs**: This is the fastest, coarsest-grained reading — good for a quick take, but skips the finer detail correspondence/ruling-line analysis provides.

## Deriving Nuclear Trigrams
**When to use**: When you want a deeper reading than the primary trigrams alone provide.
**How**: Take the hexagram's four middle lines (positions 2-5). Lines 2-3-4 form the lower nuclear trigram; lines 3-4-5 form the upper nuclear trigram. Look these up the same way as primary trigrams — they add a second, hidden layer of meaning.
**Trade-offs**: Adds real interpretive depth (this is why lines 3 and 4 carry the most structural tension — each belongs to 3 trigrams: 2 primary + 1 nuclear), but requires the trigram lookup table and is easy to get backwards (double-check which 3 lines go in which nuclear trigram).

## Checking Correspondence (2nd/5th lines)
**When to use**: After identifying trigrams — the single most informative line-relationship check for most hexagrams.
**How**: Compare the 2nd line (lower trigram's center) and 5th line (upper trigram's center). They "correspond" only if they differ in kind (one firm, one yielding). A strong 2nd corresponding with a yielding 5th-place ruler is favorable in most cases. A yielding 2nd corresponding with a strong 5th-place ruler is markedly less reliable. See `cheatsheet.md` for the specific hexagram lists.
**Trade-offs**: A powerful signal when present, but correspondence can be absent entirely (both lines the same kind) — don't force a reading where none exists.

## Checking Holding Together (adjacent lines)
**When to use**: Alongside correspondence, especially for the 4th/5th (minister/ruler) pair.
**How**: Compare two adjacent lines of differing character. The lower line "receives," the upper "rests upon." A yielding 4th holding together with a strong 5th (ruler) is usually favorable; a strong, "incorrect" 4th holding together with a yielding ruler usually reads as a minister overshadowing his ruler — unfavorable. See `cheatsheet.md` for specific hexagram lists.
**Trade-offs**: Only meaningful between lines of differing character — two adjacent lines of the same kind aren't "holding together" in this technical sense.

## Locating the Ruling Line(s)
**When to use**: To identify what a hexagram is fundamentally "about," beyond its trigrams and correspondences.
**How**: Ask two separate questions. (1) Constituting ruler — which single line, good or bad, gives the hexagram its defining meaning? (2) Governing ruler — which line (usually the 5th) is genuinely good and rules through both position and the demands of the time? Cross-check against that hexagram's T'uan Chuan (Commentary on the Decision) in Book III, which the source says will confirm the ruler.
**Trade-offs**: When constituting and governing ruler are the same line, the hexagram reads cleanly. When they differ, that gap is itself diagnostic — the hexagram is describing tension between what defines the situation and what would actually resolve it well.

## Determining the Hexagram's "Time"
**When to use**: Before interpreting any individual line value — the same six/nine can mean different things depending on time-type.
**How**: Classify which of four senses the hexagram represents: a movement (growth/decrease, emptying/filling — e.g. Peace, Standstill), a characteristic action or process (e.g. Conflict, Biting Through), a law or principle (e.g. Treading, Modesty, Duration), or a symbolic situation as such (e.g. The Well, The Caldron).
**Trade-offs**: This classification isn't always crisp — some hexagrams could be read more than one way — but skipping it risks reading a line's firmness/correctness as universally good or bad when the source ties its meaning to the surrounding "time."
