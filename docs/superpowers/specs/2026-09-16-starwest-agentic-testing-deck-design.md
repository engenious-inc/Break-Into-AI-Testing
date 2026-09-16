# STARWEST 2026 Deck Revision Design

## Goal

Revise `Herding Cats in the Cloud` into a leaner, more defensible 45-minute conference talk while preserving its current visual identity, technical depth, and speaker voice.

The revision will use a surgical scope: approximately 50 main-flow slides, with supporting material retained in an appendix. The original PowerPoint will remain unchanged.

## Audience and Thesis

The audience is QA engineers, test leaders, and engineering managers who understand conventional automation but may not yet have a practical framework for testing agentic systems.

The talk's central claim is:

> Test the workflow, not just the model.

Every section must support that claim with either a testable mechanism, a repository-backed example, or qualified external evidence.

## Narrative

The main flow will keep the existing title and five-part structure, tightened into four conceptual acts:

1. **The testing contract changed** — non-determinism, state, tools, and cross-agent timing invalidate exact-output assumptions.
2. **Build evidence in layers** — deterministic tool and contract tests, cognitive evals, and workflow simulations each address different risks.
3. **Test the oracle and the control plane** — graders, fixtures, suppression layers, configuration, retrieval, and permissions can all invalidate a green result.
4. **Operate a compounding loop** — traces become eval cases; failures become constraints; gates produce ship, canary, hold, rollback, or collect decisions.

Section dividers may remain, but transitions and repeated framing slides will be consolidated.

## Repository Integration

The deck will use `Break-Into-AI-Testing` as concrete evidence rather than as a closing reference. Examples will include:

- the three-axis taxonomy: factual accuracy, reasoning, and safety/refusal;
- the triplet structure of prompt, tests, and provider configuration;
- deterministic assertions paired with model-graded assertions;
- the grading-the-grader case where a rubric passed a full prompt leak;
- testing an application through route and citation fields rather than prose alone;
- overreliance versus refusal: refusing a false premise is not correcting it;
- prompt injection through retrieved documents and MCP tool results;
- tool inventory, least privilege, and closed argument sets;
- ordinary versus inverted red-team scoring;
- CI cadence split across deterministic tests, live evals, and generated attacks;
- telemetry and failed traces feeding the regression corpus.

Repository examples will be explained without requiring attendees to know Promptfoo or clone the project during the talk.

## Content Changes

### Correct

- Distinguish empirical pass rate, `pass@k` (at least one success), and `pass^k` (all k trials succeed).
- Replace claims that ten repeated runs constitute a `pass@k` baseline.
- Clarify sample-size assumptions and avoid treating repeated prompts as independent observations.
- Describe aggregation masking directly unless the slide demonstrates Simpson's paradox.
- Correct duplicated or mismatched speaker notes.

### Add or Strengthen

- A compact agentic test contract covering outcome, trajectory, tool authority, state invariants, recovery, and observability.
- A model-to-application-to-agent progression showing why prose-only assertions stop being sufficient.
- A repository-backed poisoned-retrieval example: the guard sees the user message but not the retrieved payload.
- A repository-backed application assertion example for route and citations.
- Source footnotes on evidence slides and a linked bibliography.
- Clear labels for internal, illustrative, preprint, and published measurements.

### Move to Appendix or Consolidate

- detailed sample-size calculations;
- the full nine-reviewer architecture;
- the nine-fixture grid;
- the complete OWASP ASI list;
- the 2026 vendor landscape;
- detailed internal framework/property matrices;
- dense agent-contract rows;
- secondary war stories that repeat an already established mechanism.

The appendix will remain usable for Q&A.

## Public-Conference Safety

Potentially sensitive operational details will be generalized unless already public and explicitly necessary:

- exact internal repository and service counts;
- exact business-unit/CDN matrices;
- capabilities that mutate live encoder state;
- internal authentication or topology details;
- thresholds presented as organizational policy.

External evidence will be qualified:

- The original τ-bench results will be labeled as a 2024 benchmark result for a specific GPT-4o version and harness, not current frontier performance.
- MAST will cite the NeurIPS paper and state that its 1,642-trace dataset was predominantly LLM-annotated; human annotation developed and validated the taxonomy.
- The silent-failure study will be labeled a single-author, single-system, non-peer-reviewed longitudinal preprint.
- OWASP LLM and Agentic Top 10 references will use official titles and dates; the Agentic resource page date is December 9, 2025.
- OpenTelemetry GenAI conventions will be described as Development status.
- The July 2026 τ-bench 1.0.1 grading change will be cited to its release notes and scoped specifically to the `banking_knowledge` domain.
- `Testing AI` will include its full subtitle, edition, and publication date.

## Visual Direction

Keep the existing cream background, black typography, yellow rule, and section accent colors. Improve readability by:

- limiting each main-flow slide to one claim;
- reducing table density and body copy;
- using consistent evidence labels;
- reserving black-background slides for major claims;
- using diagrams for flows and invariants;
- keeping detailed tables in the appendix;
- maintaining large type suitable for a conference room.

No new visual theme or stock-image layer will be introduced.

## Speaker Notes

Speaker notes will be retained and tightened. Each main-flow slide will have:

- one intended spoken point;
- optional cut-for-time material;
- source qualification when needed;
- a transition to the next slide.

The main path will target 40–42 minutes, leaving at least three minutes of buffer before Q&A.

## Deliverables

- A new revised PowerPoint beside the original, with `-Revised` in the filename.
- The original PowerPoint unchanged.
- Approximately 50 main-flow slides plus appendix.
- Working hyperlinks and QR code where applicable.
- No clipped text, overlapping shapes, missing fonts, or render errors in a PDF export.

## Verification

The revised deck will be checked by:

1. extracting slide text and notes to verify order, titles, and terminology;
2. exporting to PDF with LibreOffice;
3. rendering contact sheets for visual inspection;
4. scanning for clipping, overlaps, missing text, and inconsistent footers;
5. checking hyperlinks and source URLs;
6. confirming the original file checksum is unchanged.
