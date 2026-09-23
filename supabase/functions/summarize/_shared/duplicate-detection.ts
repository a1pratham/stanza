// Stanza Phase 7 -- basic duplicate/near-identical story detection.
//
// Scope note: this is deliberately simple -- headline word-overlap
// similarity within the same category, compared against already-published
// Stanzas from roughly the last 24 hours (which is all that exists anyway,
// given the cleanup job's retention window). No embeddings, no new
// database columns, no event-clustering data model. Real semantic
// clustering with a dedicated EVENTS table (spec section 13) is Phase 8's
// job -- this only prevents the most obvious case: three publishers
// running near-identical wire copy on the same event, which would
// otherwise show up as three near-duplicate cards in the feed.

const STOPWORDS = new Set([
  'a', 'an', 'the', 'and', 'or', 'but', 'is', 'are', 'was', 'were', 'be',
  'been', 'being', 'to', 'of', 'in', 'on', 'at', 'for', 'with', 'by',
  'from', 'as', 'it', 'its', 'this', 'that', 'after', 'over', 'amid',
  'says', 'said', 'new', 'has', 'have', 'had', 'will', 'not',
]);

/** Normalizes a headline into a set of significant words for comparison. */
function tokenize(text: string): Set<string> {
  const words = text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter((w) => w.length > 2 && !STOPWORDS.has(w));
  return new Set(words);
}

/** Jaccard similarity: intersection size / union size, 0..1. */
function jaccardSimilarity(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 || b.size === 0) return 0;
  let intersection = 0;
  for (const word of a) {
    if (b.has(word)) intersection += 1;
  }
  const union = a.size + b.size - intersection;
  return union === 0 ? 0 : intersection / union;
}

// Above this similarity, two headlines are treated as the same underlying
// event. Chosen conservatively (higher = stricter) to avoid falsely
// merging two genuinely different stories that just share common nouns
// (e.g. two different "India" stories). Tune based on observed behavior.
const SIMILARITY_THRESHOLD = 0.6;

export interface RecentHeadline {
  title: string;
  category: string;
}

/**
 * Returns true if `title` is a near-duplicate of any already-published
 * story in the same category from the recent-headlines set.
 */
export function isDuplicate(
  title: string,
  category: string,
  recent: RecentHeadline[],
): boolean {
  const candidateTokens = tokenize(title);
  if (candidateTokens.size === 0) return false;

  for (const entry of recent) {
    if (entry.category !== category) continue;
    const similarity = jaccardSimilarity(candidateTokens, tokenize(entry.title));
    if (similarity >= SIMILARITY_THRESHOLD) return true;
  }

  return false;
}
