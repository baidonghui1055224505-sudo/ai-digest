#!/usr/bin/env node

// ============================================================================
// Follow Builders — AI Remix Script
// ============================================================================
// Takes the JSON from prepare-digest.js and calls Gemini API to generate
// a formatted digest in the user's preferred language.
//
// Usage:
//   node prepare-digest.js | node remix-digest.js
//
// Needs GEMINI_API_KEY in environment. Get one free at:
//   https://aistudio.google.com/apikey
// ============================================================================

const GEMINI_API = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

async function main() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  const data = JSON.parse(Buffer.concat(chunks).toString('utf-8'));

  if (data.status !== 'ok') {
    console.error('Feed error:', JSON.stringify(data));
    process.exit(1);
  }

  if (data.stats.podcastEpisodes === 0 && data.stats.xBuilders === 0) {
    console.log('No new updates from builders today.');
    process.exit(0);
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.error('GEMINI_API_KEY not set');
    process.exit(1);
  }

  const config = data.config;
  const prompts = data.prompts;

  // Build system instruction from the skill prompts
  const systemPrompt = [
    prompts.digest_intro,
    prompts.summarize_tweets,
    prompts.summarize_podcast,
    prompts.summarize_blogs,
    config.language === 'zh' || config.language === 'bilingual' ? prompts.translate : '',
  ].filter(Boolean).join('\n---\n');

  // Build user content payload
  const contentParts = [];

  for (const p of data.podcasts || []) {
    contentParts.push(`<podcast>
  name: ${p.name}
  title: ${p.title}
  url: ${p.url}
  published: ${p.publishedAt}
  transcript: ${p.transcript}
</podcast>`);
  }

  for (const b of data.x || []) {
    const tweets = (b.tweets || []).map(t =>
      `<tweet id="${t.id}" url="${t.url}" likes="${t.likes}" retweets="${t.retweets}">${t.text}</tweet>`
    ).join('\n');
    contentParts.push(`<builder>
  name: ${b.name}
  handle: ${b.handle}
  bio: ${b.bio}
  tweets: [${tweets}]
</builder>`);
  }

  for (const b of data.blogs || []) {
    contentParts.push(`<blog>
  name: ${b.name}
  title: ${b.title}
  url: ${b.url}
  content: ${b.content || b.summary || ''}
</blog>`);
  }

  const userPrompt = `Generate the AI Builders Digest from the following content.

Language: ${config.language === 'zh' ? 'Chinese (simplified, natural Mandarin)' : config.language === 'bilingual' ? 'Bilingual (interleave English and Chinese paragraph by paragraph)' : 'English'}

Today's date: ${new Date().toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}

Content:
${contentParts.join('\n\n')}`;

  const res = await fetch(`${GEMINI_API}?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: systemPrompt }] },
      contents: [{ parts: [{ text: userPrompt }] }],
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 8192,
        topP: 0.95,
      },
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    console.error(`Gemini API error ${res.status}: ${err}`);
    process.exit(1);
  }

  const result = await res.json();
  const digest = result.candidates?.[0]?.content?.parts?.[0]?.text;

  if (!digest) {
    console.error('Empty response from Gemini:', JSON.stringify(result));
    process.exit(1);
  }

  console.log(digest);
}

main().catch(err => {
  console.error('Remix error:', err.message);
  process.exit(1);
});
