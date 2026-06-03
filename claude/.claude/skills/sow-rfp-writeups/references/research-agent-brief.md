# Research sub-agent brief template

Build each research sub-agent prompt from this template. Fill the bracketed parts per track. The
structure is what made the reference engagement's findings usable: each agent came back with a
per-question brief, every claim sourced, and a clean line between what was verified and what was
inferred. Keep that discipline, it is what lets the reviewer actually check the work.

## Template

```
Research [TRACK FOCUS, e.g. "how Palantir Foundry and AIP engagements are delivered and the typical
timelines"] to inform [DELIVERABLE, e.g. "a government RFP response for Palantir specialist services"].

Context: [one or two lines on the domain, the buyer, and why this matters. Paste the relevant asks
from the source document so the agent researches the real question.]

Find and cite authoritative, current sources. Prioritise primary sources ([vendor docs, official
announcements, regulator or buyer publications]) over secondary commentary. For every factual claim,
give a source name and a URL inline.

Answer these specific questions:
1. [question]
2. [question]
3. [question]
[3 to 6 focused questions, each independently answerable]

Rules for your return:
- Structure the answer with one section per question.
- Put an inline citation (source name + URL) on every factual claim.
- Separate VERIFIED facts from INFERRED reasoning. Label inference explicitly. Never present a
  deduction as a sourced fact.
- Flag clearly wherever evidence is thin, a single source, or contradicted elsewhere.
- Where you cite a number (duration, team size, cost, throughput, adoption rate), say whether it is a
  vendor claim, an independent benchmark, or your estimate, and under what assumptions it holds.
- No padding. No restating the question. No marketing language.

Return: a structured markdown brief, one section per question, plus a one-line "research value"
self-assessment (high / medium / low) at the top noting how solid the evidence base was.
```

## Choosing the tracks

Default to three: technology and delivery, industry and sector context, sizing and benchmarks. Add or
swap tracks when the topic demands it, for example a dedicated governance, security, or compliance
track for regulated sectors, or a commercial-model track when the ask is about pricing or operating
models. Keep tracks non-overlapping so two agents do not return the same sources. Always two or more,
never exactly one.

## When a track is sent back for redo

On a REDO, append the reviewer's gap list to the original brief verbatim, under a heading like:

```
The previous research pass had these gaps. Close them specifically:
- [gap 1]
- [gap 2]
Re-confirm the claims that passed; do not discard them. Focus your effort on the gaps above.
```

This keeps the agent from re-doing solid work and points it straight at what failed.
