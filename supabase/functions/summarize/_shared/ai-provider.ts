// Stanza Phase 3 -- Groq AI summarization provider.

export interface SummaryResult {
  headline: string;
  summary: string;
  wordCount: number;
  modelVersion: string;
}

export interface ArticleInput {
  title: string;
  description: string;
  sourceName: string;
}

const MODEL_VERSION = 'openai/gpt-oss-120b';

const PROMPT_TEMPLATE = (article: ArticleInput) => `
Summarize the supplied news content into approximately 50 words.

Requirements:
- Target 40-60 words.
- Preserve important factual information.
- Do not invent information.
- Do not add opinions.
- Do not speculate.
- Preserve important names, dates, locations and numbers.
- Use simple language.
- Clearly explain what happened.
- Do not use clickbait language.
- Also write a clear, non-clickbait headline under 12 words.

Source: ${article.sourceName}
Title: ${article.title}
Content: ${article.description}

Return JSON with exactly two fields:
{
  "headline": "short headline",
  "summary": "40-60 word summary"
}
`.trim();

export async function summarizeArticle(
  article: ArticleInput,
): Promise<SummaryResult> {
  const apiKey = Deno.env.get('GROQ_API_KEY');

  if (!apiKey) {
    throw new Error('GROQ_API_KEY is not set');
  }

  const response = await fetch(
    'https://api.groq.com/openai/v1/chat/completions',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: MODEL_VERSION,
        messages: [
          {
            role: 'system',
            content:
              'You summarize news articles accurately. Return only valid JSON containing headline and summary.',
          },
          {
            role: 'user',
            content: PROMPT_TEMPLATE(article),
          },
        ],
        temperature: 0.2,
        response_format: {
          type: 'json_schema',
          json_schema: {
            name: 'stanza_summary',
            strict: true,
            schema: {
              type: 'object',
              properties: {
                headline: {
                  type: 'string',
                },
                summary: {
                  type: 'string',
                },
              },
              required: ['headline', 'summary'],
              additionalProperties: false,
            },
          },
        },
      }),
    },
  );

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Groq API error (${response.status}): ${errText}`);
  }

  const data = await response.json();

  const rawText = data.choices?.[0]?.message?.content;

  if (!rawText) {
    throw new Error('Groq returned no usable content');
  }

  let parsed: { headline: string; summary: string };

  try {
    parsed = JSON.parse(rawText);
  } catch {
    throw new Error(`Failed to parse Groq JSON response: ${rawText}`);
  }

  if (!parsed.summary || !parsed.headline) {
    throw new Error(`Groq response missing required fields: ${rawText}`);
  }

  const wordCount = parsed.summary.trim().split(/\s+/).length;

  return {
    headline: parsed.headline.trim(),
    summary: parsed.summary.trim(),
    wordCount,
    modelVersion: MODEL_VERSION,
  };
}