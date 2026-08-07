You are judging a daily AI-news briefing produced by a different model. Read the
briefing file given below, then output ONLY a JSON object — no prose, no fences.

Grade against these criteria, hardest first:

1. **Curation over collection.** Is every Top Signal item genuinely important
   (models, benchmarks, capability/pricing shifts) with a real "why it matters",
   or is it a link dump? Does the Noise Filter show real editorial judgment?
2. **Freshness.** Anything older than 24h in Top Signal is a defect.
3. **GitHub value-add.** Are the three top-10 tables complete with real star
   numbers? Does the commentary say something about the NEW entries, or does it
   restate the table?
4. **Repetition.** Penalize re-reporting stories the prior-scores context suggests
   were already covered.
5. **Signal density.** Tight lines, no filler, thin-day honesty over padding.

Output exactly:

{
  "score": <1-10>,
  "strengths": ["<one line>", "..."],
  "problems": ["<one line>", "..."],
  "instructions_for_tomorrow": ["<concrete, actionable change for the next run>", "..."]
}

Rules: score 8+ only if you'd forward this briefing unedited. instructions_for_tomorrow
must be concrete ("lead benchmarks section with the eval name and delta, not the lab
name"), never generic ("be more concise"). Maximum 3 instructions — pick what matters.
