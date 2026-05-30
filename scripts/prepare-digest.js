#!/usr/bin/env node

// ============================================================================
// Follow Builders — Prepare Digest
// ============================================================================
// Gathers everything the LLM needs to produce a digest:
// - Fetches the central feeds (tweets + podcasts + blogs)
// - Fetches the latest prompts from GitHub
// - Supports --user <id> for multi-user mode (reads users/<id>.json)
// - Outputs a single JSON blob to stdout
//
// Usage:
//   node prepare-digest.js                 # single-user: ~/.follow-builders/config.json
//   node prepare-digest.js --user xiaoming  # multi-user: users/xiaoming.json
// ============================================================================

import { readFile, mkdir } from 'fs/promises';
import { existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { homedir } from 'os';
import { getJSON, getText } from './lib/fetch.js';

// -- Constants ---------------------------------------------------------------

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(__dirname, '..');

const USER_DIR = join(homedir(), '.follow-builders');
const CONFIG_PATH = join(USER_DIR, 'config.json');
const USERS_DIR = join(REPO_ROOT, 'users');

const FEED_X_URL = 'https://raw.githubusercontent.com/zarazhangrui/follow-builders/main/feed-x.json';
const FEED_PODCASTS_URL = 'https://raw.githubusercontent.com/zarazhangrui/follow-builders/main/feed-podcasts.json';
const FEED_BLOGS_URL = 'https://raw.githubusercontent.com/zarazhangrui/follow-builders/main/feed-blogs.json';

const PROMPTS_BASE = 'https://raw.githubusercontent.com/zarazhangrui/follow-builders/main/prompts';
const PROMPT_FILES = [
  'summarize-podcast.md',
  'summarize-tweets.md',
  'summarize-blogs.md',
  'digest-intro.md',
  'translate.md'
];

// -- CLI arg parsing ---------------------------------------------------------

function parseArgs() {
  const args = process.argv.slice(2);
  const userId = args.indexOf('--user') !== -1 ? args[args.indexOf('--user') + 1] : null;
  return { userId };
}

// -- RSS feed fetcher (uses proxy-aware fetch helper) -----------------------

async function fetchRSS(url) {
  let xml;
  try { xml = await getText(url); } catch { return null; }
  if (!xml) return null;

  // Extract channel/title
  const channelTitle = (xml.match(/<title>([^<]+)<\/title>/) || [])[1] || url;

  // Extract items: <item>...</item> blocks
  const itemBlocks = xml.match(/<item>[\s\S]*?<\/item>/gi) || [];
  const items = [];

  for (const block of itemBlocks.slice(0, 10)) { // max 10 items per feed
    const title = (block.match(/<title>([\s\S]*?)<\/title>/i) || [])[1] || '';
    const link = (block.match(/<link>([\s\S]*?)<\/link>/i) || [])[1] || '';
    const pubDate = (block.match(/<pubDate>([\s\S]*?)<\/pubDate>/i) || [])[1] || '';
    // Strip CDATA and HTML tags from description
    let desc = (block.match(/<description>([\s\S]*?)<\/description>/i) || [])[1] || '';
    desc = desc.replace(/<!\[CDATA\[|\]\]>/g, '').replace(/<[^>]+>/g, '').slice(0, 1000);

    if (title || link) {
      items.push({
        title: title.replace(/<!\[CDATA\[|\]\]>/g, '').trim(),
        url: link.trim(),
        published: pubDate.trim(),
        summary: desc.trim()
      });
    }
  }

  return { name: channelTitle, url, items };
}

// -- User config loading -----------------------------------------------------

async function loadUserConfig(userId) {
  if (!userId) {
    // Legacy single-user mode
    let config = {
      language: 'en',
      frequency: 'daily',
      delivery: { method: 'stdout' }
    };
    if (existsSync(CONFIG_PATH)) {
      config = JSON.parse(await readFile(CONFIG_PATH, 'utf-8'));
    }
    if (process.env.FB_LANGUAGE) config.language = process.env.FB_LANGUAGE;
    return { config, sources: null };
  }

  // Multi-user mode: read from users/<id>.json
  const userPath = join(USERS_DIR, `${userId}.json`);
  if (!existsSync(userPath)) {
    throw new Error(`User config not found: ${userPath}`);
  }
  const userData = JSON.parse(await readFile(userPath, 'utf-8'));
  const config = {
    language: userData.language || 'zh',
    frequency: 'daily',
    delivery: { method: 'email', email: userData.email }
  };
  return { config, sources: userData.sources || null, customRss: userData.customRss || [] };
}

// -- Source filtering --------------------------------------------------------

function filterContent(feedX, feedPodcasts, feedBlogs, sources) {
  // If no sources specified or "all", return everything
  if (!sources) {
    return {
      podcasts: feedPodcasts?.podcasts || [],
      x: feedX?.x || [],
      blogs: feedBlogs?.blogs || []
    };
  }

  const isAll = (arr) => !arr || arr.length === 0 || arr.includes('all');

  const podcasts = feedPodcasts?.podcasts || [];
  const xBuilders = feedX?.x || [];
  const blogs = feedBlogs?.blogs || [];

  return {
    podcasts: isAll(sources.podcasts)
      ? podcasts
      : podcasts.filter(p => sources.podcasts.includes(p.name)),
    x: isAll(sources.xBuilders)
      ? xBuilders
      : xBuilders.filter(b => sources.xBuilders.includes(b.handle)),
    blogs: isAll(sources.blogs)
      ? blogs
      : blogs.filter(b => sources.blogs.includes(b.name))
  };
}

// -- Main --------------------------------------------------------------------

async function main() {
  const errors = [];
  const { userId } = parseArgs();

  // 1. Load user config
  const { config, sources, customRss } = await loadUserConfig(userId);

  // 2. Fetch all three feeds + custom RSS
  const [feedX, feedPodcasts, feedBlogs] = await Promise.all([
    getJSON(FEED_X_URL).catch(() => null),
    getJSON(FEED_PODCASTS_URL).catch(() => null),
    getJSON(FEED_BLOGS_URL).catch(() => null)
  ]);

  // Fetch custom RSS feeds in parallel
  const customFeeds = (await Promise.all(
    (customRss || []).map(async (feed) => {
      try {
        return await fetchRSS(feed.url) || { name: feed.name, url: feed.url, items: [], error: 'Failed to fetch' };
      } catch (e) {
        return { name: feed.name, url: feed.url, items: [], error: e.message };
      }
    })
  )).filter(f => f.items.length > 0);

  if (!feedX) errors.push('Could not fetch tweet feed');
  if (!feedPodcasts) errors.push('Could not fetch podcast feed');
  if (!feedBlogs) errors.push('Could not fetch blog feed');

  // 3. Load prompts
  const prompts = {};
  const scriptDir = decodeURIComponent(new URL('.', import.meta.url).pathname);
  const localPromptsDir = join(scriptDir, '..', 'prompts');
  const userPromptsDir = join(USER_DIR, 'prompts');

  for (const filename of PROMPT_FILES) {
    const key = filename.replace('.md', '').replace(/-/g, '_');
    const userPath = join(userPromptsDir, filename);
    const localPath = join(localPromptsDir, filename);

    if (existsSync(userPath)) {
      prompts[key] = await readFile(userPath, 'utf-8');
      continue;
    }

    let remote;
    try { remote = await getText(`${PROMPTS_BASE}/${filename}`); } catch { remote = null; }
    if (remote) {
      prompts[key] = remote;
      continue;
    }

    if (existsSync(localPath)) {
      prompts[key] = await readFile(localPath, 'utf-8');
    } else {
      errors.push(`Could not load prompt: ${filename}`);
    }
  }

  // 4. Filter content per user
  const { podcasts, x, blogs } = filterContent(feedX, feedPodcasts, feedBlogs, sources);

  // 5. Build output
  const output = {
    status: 'ok',
    generatedAt: new Date().toISOString(),
    userId: userId || 'default',

    config: {
      language: config.language || 'en',
      frequency: config.frequency || 'daily',
      delivery: config.delivery || { method: 'stdout' }
    },

    podcasts,
    x,
    blogs,
    customFeeds,

    stats: {
      podcastEpisodes: podcasts.length,
      xBuilders: x.length,
      totalTweets: x.reduce((sum, a) => sum + (a.tweets?.length || 0), 0),
      blogPosts: blogs.length,
      customFeedItems: customFeeds.reduce((sum, f) => sum + f.items.length, 0),
      feedGeneratedAt: feedX?.generatedAt || feedPodcasts?.generatedAt || feedBlogs?.generatedAt || null
    },

    prompts,
    errors: errors.length > 0 ? errors : undefined
  };

  console.log(JSON.stringify(output, null, 2));
}

main().catch(err => {
  console.error(JSON.stringify({
    status: 'error',
    message: err.message
  }));
  process.exit(1);
});
