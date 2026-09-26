// Stanza Phase 7/8/9 -- duplicate/near-identical story detection.
//
// PHASE 9 CHANGE: RecentHeadline now also carries reliabilityTier, so the
// caller (index.ts) can pass source-quality info through to event-linking
// without a second query. Similarity logic itself is UNCHANGED from
// Phase 7/8.

const STOPWORDS = new Set([
  'a', 'an', 'the', 'and', 'or', 'but', 'is', 'are', 'was', 'were', 'be',
  'been', 'being', 'to', 'of', 'in', 'on', 'at', 'for', 'with', 'by',
  'from', 'as', 'it', 'its', 'this', 'that', 'after', 'over', 'amid',
  'says', 'said', 'new', 'has', 'have', 'had', 'will', 'not',
]);

function tokenize(text: string): Set<string> {
  const words = text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter((w) => w.length > 2 && !STOPWORDS.has(w));
  return new Set(words);
}

function jaccardSimilarity(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 || b.size === 0) return 0;
  let intersection = 0;
  for (const word of a) {
    if (b.has(word)) intersection += 1;
  }
  const union = a.size + b.size - intersection;
  return union === 0 ? 0 : intersection / union;
}

const SIMILARITY_THRESHOLD = 0.6;

export interface RecentHeadline {
  articleId: string;
  title: string;
  category: string;
  reliabilityTier: number;
}

/**
 * Returns the best-matching near-duplicate headline entry (including its
 * reliability tier, needed for Phase 9's title-preference logic), or null
 * if no match clears the threshold.
 */
export function findDuplicateMatch(
  title: string,
  category: string,
  recent: RecentHeadline[],
): RecentHeadline | null {
  const candidateTokens = tokenize(title);
  if (candidateTokens.size === 0) return null;

  let best: { entry: RecentHeadline; similarity: number } | null = null;

  for (const entry of recent) {
    if (entry.category !== category) continue;
    const similarity = jaccardSimilarity(candidateTokens, tokenize(entry.title));
    if (similarity >= SIMILARITY_THRESHOLD) {
      if (!best || similarity > best.similarity) {
        best = { entry, similarity };
      }
    }
  }

  return best?.entry ?? null;
}
