---
name: brand
description: "Use this skill before creating any output: PDF, presentation, slides, deck, PowerPoint, Google Slides, document, proposal, PRD, product requirements, executive summary, one-pager, report, email, newsletter, social post, LinkedIn post, process flow, flowchart, diagram, image, business card, or any deliverable. Also use before invoking document-skills:pdf, document-skills:pptx, document-skills:docx, document-skills:xlsx. TRIGGER — read and apply BEFORE any document or output creation begins. Invoke explicitly via /brand to receive a Brand Spec Card for a given output type."
---

# Brand Skill — Paul McKay Personal Brand

You are the brand gate. No output is created before this skill runs.

## What To Do

1. **Identify the output type** from the user's request:
   - Presentation / Slides / Deck / PPTX
   - PDF / One-Pager
   - Long-Form Document / Proposal / PRD
   - Email / Newsletter
   - Business Card
   - LinkedIn / Social Post
   - Data Visualization (standalone chart or dashboard)
   - Process Flow / Diagram

2. **Read the brand guide:**
   ```
   ~/.claude/brand/brand-guide.md
   ```

3. **Navigate to the matching `## Format:` section** for the output type identified in step 1. If multiple output types are involved, cover all relevant sections.

4. **Output a Brand Spec Card** — a compact, formatted block with the exact values Claude must use for this output. Use this structure:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
BRAND SPEC CARD — [Output Type]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
COLORS
  Background:     [value]
  Primary text:   Charcoal #2a2a28
  Accent/CTA:     Taupe #6b5b54
  Secondary:      [Slate #5a7a8a OR Khaki #a89980 — pick one]
  Section fill:   Linen #f5f2ed (only if needed)

TYPOGRAPHY
  Headline:       Poppins [weight], [size]
  Subhead:        Poppins [weight], [size]
  Body:           Lora 400, [size], line-height [value]

LAYOUT
  Margins:        [value]
  Grid:           [8px or 16px]
  White space:    [guidance]

VOICE
  Tone:           [Formal / Supportive / Decisive — per context]
  Check:          "Would an executive take this seriously?"

MARK
  Required:       ◆ minimum 24px, clear space 1 mark-width all sides
  Color:          Taupe #6b5b54 (primary) or Charcoal (monochrome)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

5. **Emit a machine-readable Brand Spec JSON block** immediately after the text Brand Spec Card. This allows document-skills to consume brand values programmatically without parsing the text card.

```json
{
  "brand_spec_version": "1",
  "output_type": "[output type from step 1]",
  "colors": {
    "background":    "#fafaf8",
    "section_fill":  "#f5f2ed",
    "text_dark":     "#2a2a28",
    "accent":        "#6b5b54",
    "secondary":     "#5a7a8a",
    "supporting":    "#a89980"
  },
  "accent_choice": "[taupe|slate — one per document, not both]",
  "typography": {
    "heading_font":   "Poppins",
    "heading_weight": "700",
    "body_font":      "Lora",
    "body_weight":    "400"
  },
  "mark": {
    "min_size_px": 24,
    "placement":   "top-right",
    "color":       "#6b5b54"
  },
  "voice": {
    "tone":  "formal-authoritative",
    "avoid": ["hedging", "hype", "casual", "filler"]
  }
}
```

Label this block with a header line: `### Brand Spec JSON` so downstream skills can locate it by heading.

6. **Confirm brand gate is satisfied** with this line:
   > ✓ Brand gate cleared. Proceeding to create [output type].

7. **Then proceed** to create the output using the specs from the Brand Spec Card.

## Hard Rules — Never Violate

- Only 6 colors exist: `#2a2a28`, `#6b5b54`, `#f5f2ed`, `#fafaf8`, `#5a7a8a`, `#a89980`
- Only 2 typefaces: Poppins (headings) and Lora (body)
- Mark minimum size: 24px always
- No 3D charts, drop shadows, or decorative effects on data viz
- No casual language in external-facing outputs
- One accent color per document/deck — not both Slate and Taupe
- One idea per slide maximum
- Margins: generous (1" for print/PDF)

## Prose Mechanics — The Elements of Style

Adapted from William Strunk Jr.'s *The Elements of Style* (1920, public domain). Every output passes these checks before the brand gate clears, regardless of tone:

- **No filler nouns.** `case`, `character`, `factor`, `feature`, `nature`, `system` used as padding (e.g. "acts of a hostile character") signal the real subject is hiding — recast the sentence around the concrete noun or verb instead of patching the word.
- **No comma splices.** Never join two independent clauses with a bare comma. Use a semicolon, a period, or a coordinating conjunction with a comma before it. If the second clause opens with an adverb (`however`, `therefore`, `accordingly`), use a semicolon — never a comma.
- **Parallel construction.** Co-ordinate ideas take matching grammatical form (a list of gerunds stays gerunds; a list of infinitives stays infinitives).
- **Active voice by default.** Passive only when the paragraph's real subject is the thing acted upon.
- **End-emphasis.** Put the word or phrase you want the reader to remember at the end of the sentence — the position of emphasis.
- **Recast, don't patch.** When a word choice feels wrong, rewrite the sentence from its actual subject rather than swapping in a synonym.

## When Invoked Explicitly (/brand)

If the user types `/brand` without specifying an output type, ask:

> "What output type are we creating? (e.g., presentation, PDF, proposal, email, social post, diagram)"

Then deliver the Brand Spec Card for that format.

## Common Mistake Check

Before confirming brand gate, quickly scan for these 9 anti-patterns and flag if relevant:
1. Too many colors (more than 3 from the palette in one piece)
2. Casual language in formal context
3. Inconsistent typography hierarchy
4. Data viz with decorative effects
5. Crowded slides / dense text blocks
6. Palette exception "just this once"
7. Mark too small or missing
8. Filler-noun padding (`case`, `character`, `factor`, `feature`, `nature`, `system`) instead of a concrete noun or verb
9. Comma splice joining two independent clauses
