// Stanza Phase 9 -- automated consistency checks (spec section 25:
// "Automated consistency checks -- Check names, dates, numbers and
// entities against source information.").
//
// Deliberately lightweight: this is a sanity net, not a fact-checker.
// A flagged Stanza is still stored and still shown to users -- spec
// section 25's "Human review" step is explicitly future/large-scale
// work, not something to gate the MVP pipeline on. Flags exist so you
// can query `flagged_for_review = true` and spot-check the AI's output
// quality over time.

export interface ConsistencyCheckInput {
  articleTitle: string;
  articleDescription: string;
  summary: string;
  headline: string;
  wordCount: number;
}

export interface ConsistencyCheckResult {
  flagged: boolean;
  reason: string | null;
}

function tokenize(text: string): Set<string> {
  return new Set(
    text
      .toLowerCase()
      .replace(/[^a-z0-9\s]/g, ' ')
      .split(/\s+/)
      .filter((w) => w.length > 3),
  );
}

/** Extracts standalone numbers (years, counts, statistics) from text. */
function extractNumbers(text: string): Set<string> {
  return new Set(text.match(/\b\d{2,}\b/g) ?? []);
}

export function checkConsistency(input: ConsistencyCheckInput): ConsistencyCheckResult {
  const reasons: string[] = [];

  // 1. Word count sanity -- the prompt asks for 40-60, but the model is
  // not a guarantee. Allow slack (30-80) before flagging, since a
  // slightly-off count is not itself evidence of a bad summary.
  if (input.wordCount < 30 || input.wordCount > 80) {
    reasons.push(`word_count_out_of_range:${input.wordCount}`);
  }

  // 2. Topical overlap -- the summary should share at least some
  // vocabulary with the source article's title/description. Near-zero
  // overlap is a strong signal the model drifted off-topic or
  // hallucinated content unrelated to the source.
  const sourceTokens = new Set([
    ...tokenize(input.articleTitle),
    ...tokenize(input.articleDescription),
  ]);
  const summaryTokens = tokenize(input.summary);

  let overlap = 0;
  for (const token of summaryTokens) {
    if (sourceTokens.has(token)) overlap += 1;
  }
  const overlapRatio = summaryTokens.size === 0 ? 0 : overlap / summaryTokens.size;

  if (overlapRatio < 0.15) {
    reasons.push(`low_source_overlap:${overlapRatio.toFixed(2)}`);
  }

  // 3. Numeric consistency -- any number the summary states (a year, a
  // count, a statistic) should appear somewhere in the source. A number
  // in the summary that's absent from the source is a plausible
  // fabrication (spec section 26: "do not invent information").
  const sourceNumbers = extractNumbers(input.articleTitle + ' ' + input.articleDescription);
  const summaryNumbers = extractNumbers(input.summary);
  const inventedNumbers = [...summaryNumbers].filter((n) => !sourceNumbers.has(n));

  if (inventedNumbers.length > 0) {
    reasons.push(`numbers_not_in_source:${inventedNumbers.join(',')}`);
  }

  // 4. Degenerate output -- headline and summary should not be
  // near-identical; that suggests the model didn't actually summarize.
  if (input.headline.trim().toLowerCase() === input.summary.trim().toLowerCase()) {
    reasons.push('headline_equals_summary');
  }

  return {
    flagged: reasons.length > 0,
    reason: reasons.length > 0 ? reasons.join('; ') : null,
  };
}
