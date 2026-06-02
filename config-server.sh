#!/bin/bash
# ============================================================================
# 配置管理 — 打开浏览器直接管理你的跟踪列表
# ============================================================================
# 用法:
#   cd /Users/bdh/.claude/skills/follow-builders
#   ./config-server.sh             # 编辑 xiaoming 的配置
#   ./config-server.sh lisi        # 编辑 lisi 的配置（新用户自动创建）
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_ID="${1:-xiaoming}"
PORT=8765

cat > /tmp/config-ui.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AI 文摘 — 配置</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, sans-serif; background: #0f172a; color: #e2e8f0; padding: 24px; max-width: 800px; margin: 0 auto; }
h1 { font-size: 1.5em; margin-bottom: 4px; }
h2 { font-size: 1.1em; color: #94a3b8; margin: 24px 0 12px; border-bottom: 1px solid #1e293b; padding-bottom: 8px; }
.section { background: #1e293b; border-radius: 12px; padding: 16px; margin-bottom: 16px; }
label { display: flex; align-items: center; gap: 8px; padding: 6px 0; cursor: pointer; }
label input { width: 16px; height: 16px; accent-color: #6366f1; }
label .desc { font-size: 0.8em; color: #64748b; margin-left: auto; }
.btn { background: #6366f1; color: white; border: none; padding: 10px 24px; border-radius: 8px; cursor: pointer; font-size: 1em; }
.btn:hover { background: #818cf8; }
input[type="text"], input[type="email"] { width: 100%; padding: 8px 12px; border-radius: 6px; border: 1px solid #475569; background: #0f172a; color: #e2e8f0; font-size: 0.95em; }
.form-row { display: flex; gap: 8px; margin-bottom: 8px; align-items: center; }
.form-row input { flex: 1; }
.status { padding: 8px 16px; border-radius: 8px; margin-top: 12px; }
.status.ok { background: #065f46; color: #6ee7b7; }
.status.err { background: #7f1d1d; color: #fca5a5; }
.tabs { display: flex; gap: 8px; margin-bottom: 16px; flex-wrap: wrap; }
.tab { padding: 8px 20px; border-radius: 8px; cursor: pointer; border: 1px solid #475569; background: transparent; color: #94a3b8; font-size: 0.95em; }
.tab.active { background: #6366f1; border-color: #6366f1; color: white; }
.small { font-size: 0.85em; color: #94a3b8; }
.help-box { background: #1e293b; border: 1px solid #334155; border-radius: 8px; padding: 16px; margin-top: 12px; line-height: 1.8; }
.help-box code { background: #0f172a; padding: 2px 8px; border-radius: 4px; color: #a78bfa; font-size: 0.9em; font-family: monospace; }
.help-box .step { color: #fbbf24; font-weight: bold; }
.help-box a { color: #818cf8; }
.remove-btn { background: none; border: none; color: #f87171; cursor: pointer; font-size: 1.2em; padding: 0 4px; }
.builder-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 2px; }
.info-row { display: flex; gap: 12px; align-items: center; margin-bottom: 8px; }
.info-row span { color: #94a3b8; font-size: 0.9em; min-width: 50px; }
</style>
</head>
<body>
<h1>⚙️ AI 文摘配置</h1>
<p class="small">选信源 → 设邮箱 → 保存 → 明天9:30准时到</p>

<div class="tabs">
  <button class="tab active" onclick="showTab('basic')">📧 基本信息</button>
  <button class="tab" onclick="showTab('sources')">🐦 内置信息源</button>
  <button class="tab" onclick="showTab('custom')">➕ 自定义添加</button>
  <button class="tab" onclick="showTab('rss-help')">❓ RSS 怎么获取</button>
  <button class="tab" onclick="showTab('export')">📋 查看配置</button>
</div>

<!-- Tab 1: Basic info -->
<div id="tab-basic">
  <div class="section">
    <h2>📧 基本信息</h2>
    <p class="small">邮件发到哪个邮箱</p>
    <div style="margin-top:12px">
      <label>名字<br><input type="text" id="cfg-name" style="margin-top:4px"></label>
      <label style="margin-top:10px">接收邮箱<br><input type="email" id="cfg-email" style="margin-top:4px" placeholder="zhangsan@gmail.com"></label>
      <label style="margin-top:10px">语言<br>
        <select id="cfg-language" style="padding:8px;border-radius:6px;border:1px solid #475569;background:#0f172a;color:#e2e8f0;margin-top:4px">
          <option value="zh">中文</option>
          <option value="bilingual">中英双语</option>
          <option value="en">英文</option>
        </select>
      </label>
    </div>
  </div>
</div>

<!-- Tab 2: Built-in sources -->
<div id="tab-sources" style="display:none">
  <div class="section">
    <h2>🐦 X / Twitter 博主</h2>
    <p class="small">勾选你要跟踪的。不选的不出现。</p>
    <div class="builder-grid" id="x-builders"></div>
  </div>
  <div class="section">
    <h2>🎙️ 播客</h2>
    <p class="small">AI 领域热门播客，含完整文字转录</p>
    <div id="podcasts"></div>
  </div>
</div>

<!-- Tab 3: Custom sources -->
<div id="tab-custom" style="display:none">
  <div class="section">
    <h2>📡 自定义添加（YouTube / 博客 / Reddit / 任何 RSS）</h2>
    <p class="small">不知道怎么获取 RSS？点 "RSS 怎么获取" 标签看教程</p>
    <div class="form-row" style="margin-top:12px">
      <input type="text" id="custom-name" placeholder="显示名称，如：李沐的 YouTube">
      <input type="text" id="custom-url" placeholder="RSS 地址">
      <button class="btn" onclick="addCustom()">添加</button>
    </div>
    <div id="custom-list"></div>
  </div>
</div>

<!-- Tab 4: RSS Help -->
<div id="tab-rss-help" style="display:none">
  <div class="section">
    <h2>❓ 各种平台的 RSS 怎么获取</h2>
    <p class="small">RSS 就是一个固定的网址，工具每天访问这个网址读取最新内容</p>

    <div class="help-box">
      <p><span class="step">📺 YouTube 频道</span></p>
      <p>每个频道都有一个公开的 RSS 地址：</p>
      <code>https://www.youtube.com/feeds/videos.xml?channel_id=频道ID</code>
      <p style="margin-top:8px"><b>怎么找到频道ID：</b></p>
      <p>1. 打开该频道的 YouTube 主页（比如 https://www.youtube.com/@lexfridman）</p>
      <p>2. 右键 → 查看网页源代码</p>
      <p>3. Ctrl+F 搜索 <code>externalId</code></p>
      <p>4. 找到的值类似 <code>UCSHZKyawb77ixDdsGog4iWA</code> 就是频道ID</p>
      <p>5. 拼起来就是 <code>https://www.youtube.com/feeds/videos.xml?channel_id=UCSHZKyawb77ixDdsGog4iWA</code></p>
    </div>

    <div class="help-box">
      <p><span class="step">🐦 推特 / X</span></p>
      <p>Twitter 没有直接 RSS。用 RSSHub（免费中转服务）：</p>
      <code>https://rsshub.app/twitter/user/用户名</code>
      <p style="margin-top:8px">比如跟踪 Elon Musk：<code>https://rsshub.app/twitter/user/elonmusk</code></p>
      <p>注意：RSSHub 偶尔不稳定，不是100%成功</p>
    </div>

    <div class="help-box">
      <p><span class="step">📝 任何博客/网站</span></p>
      <p>大多数博客本身就有 RSS。试这几个地址：</p>
      <p><code>https://网站域名/rss</code></p>
      <p><code>https://网站域名/feed</code></p>
      <p><code>https://网站域名/feed.xml</code></p>
      <p><code>https://网站域名/rss.xml</code></p>
      <p style="margin-top:8px">比如：<code>https://openai.com/blog/rss.xml</code></p>
      <p><code>https://www.anthropic.com/blog/rss.xml</code></p>
      <p><code>https://stratechery.com/feed/</code></p>
    </div>

    <div class="help-box">
      <p><span class="step">📱 Reddit</span></p>
      <p>任何子版块后面加 <code>.rss</code> 就行：</p>
      <code>https://www.reddit.com/r/MachineLearning/.rss</code>
    </div>

    <div class="help-box">
      <p><span class="step">📰 公众号 / 知乎 / 微博 / 小红书</span></p>
      <p>这些国内平台没有公开 RSS，但可以通过 <a href="https://docs.rsshub.app" target="_blank">RSSHub</a>（一个开源项目）中转。打开 docs.rsshub.app 搜你要的平台，按文档填入对应参数就行。</p>
      <p style="margin-top:4px;color:#fbbf24">⚠️ 注意：RSSHub 服务器有时被墙或被限流，不保证100%成功。</p>
    </div>
  </div>
</div>

<!-- Tab 5: Export -->
<div id="tab-export" style="display:none">
  <div class="section">
    <h2>📋 当前配置预览</h2>
    <pre id="config-preview" style="background:#0f172a; padding:16px; border-radius:8px; overflow:auto; max-height:500px; font-size:0.85em;"></pre>
  </div>
</div>

<div style="margin-top:20px; display:flex; gap:12px; align-items:center;">
  <button class="btn" onclick="saveConfig()">💾 保存配置</button>
  <button class="btn" style="background:#334155" onclick="testNow()">🧪 立即测试发送一封</button>
  <span id="save-status"></span>
</div>

<script>
let config = {};
const API = 'http://localhost:8765/api';

async function load() {
  const r = await fetch(API + '/load');
  config = await r.json();
  document.getElementById('cfg-email').value = config.email || '';
  document.getElementById('cfg-name').value = config.name || '';
  document.getElementById('cfg-language').value = config.language || 'zh';
  renderBuiltin();
  renderCustom();
}

function renderBuiltin() {
  const xDiv = document.getElementById('x-builders');
  const xBuilders = config.available?.xBuilders || [];
  const xSelected = config.sources?.xBuilders || [];
  const xAll = xSelected.includes('all') || xSelected.length === 0;

  xDiv.innerHTML = `<label style="font-weight:bold;margin-bottom:4px"><input type="checkbox" onchange="toggleCat('xBuilders')" ${xAll ? 'checked' : ''}> <b>全部跟踪</b></label>`;
  if (!xAll) {
    for (const b of xBuilders) {
      xDiv.innerHTML += `<label><input type="checkbox" value="${b.handle}" onchange="toggleItem('xBuilders','${b.handle}')" ${xSelected.includes(b.handle) ? 'checked' : ''}> ${b.name}</label>`;
    }
  }

  const pDiv = document.getElementById('podcasts');
  const podcasts = config.available?.podcasts || [];
  const pSelected = config.sources?.podcasts || [];
  const pAll = pSelected.includes('all') || pSelected.length === 0;

  pDiv.innerHTML = `<label style="font-weight:bold;margin-bottom:4px"><input type="checkbox" onchange="toggleCat('podcasts')" ${pAll ? 'checked' : ''}> <b>全部跟踪</b></label>`;
  if (!pAll) {
    for (const p of podcasts) {
      const key = p.slug || p.name;
      pDiv.innerHTML += `<label><input type="checkbox" value="${key}" onchange="toggleItem('podcasts','${key}')" ${pSelected.includes(key) ? 'checked' : ''}> ${p.name}</label>`;
    }
  }
}

function toggleCat(type) {
  if (config.sources[type]?.includes('all')) {
    config.sources[type] = [];
  } else {
    config.sources[type] = ['all'];
  }
  renderBuiltin();
}

function toggleItem(type, key) {
  if (!config.sources[type]) config.sources[type] = [];
  const idx = config.sources[type].indexOf(key);
  if (idx >= 0) {
    config.sources[type].splice(idx, 1);
  } else {
    config.sources[type] = config.sources[type].filter(s => s !== 'all');
    config.sources[type].push(key);
  }
  renderBuiltin();
}

function addCustom() {
  const name = document.getElementById('custom-name').value.trim();
  const url = document.getElementById('custom-url').value.trim();
  if (!name || !url) return alert('名称和地址都要填');
  if (!url.startsWith('http')) return alert('地址必须以 http:// 或 https:// 开头');
  if (!config.customRss) config.customRss = [];
  config.customRss.push({ name, url });
  document.getElementById('custom-name').value = '';
  document.getElementById('custom-url').value = '';
  renderCustom();
}

function removeCustom(idx) {
  config.customRss.splice(idx, 1);
  renderCustom();
}

function renderCustom() {
  const div = document.getElementById('custom-list');
  const items = config.customRss || [];
  div.innerHTML = items.length === 0
    ? '<p class="small">还没有自定义源。切到 "RSS 怎么获取" 标签看教程，然后回来添加。</p>'
    : items.map((f, i) =>
        `<div style="padding:6px 0;display:flex;align-items:center;gap:8px">
          <button class="remove-btn" onclick="removeCustom(${i})">✕</button>
          <b>${f.name}</b> <span class="small">${f.url.slice(0, 70)}…</span>
        </div>`
      ).join('');
}

function exportConfig() {
  return {
    email: document.getElementById('cfg-email').value.trim(),
    name: document.getElementById('cfg-name').value.trim(),
    language: document.getElementById('cfg-language').value,
    sources: config.sources,
    customRss: config.customRss || []
  };
}

async function saveConfig() {
  const status = document.getElementById('save-status');
  const toSave = exportConfig();
  if (!toSave.email) {
    status.innerHTML = '<span class="status err">❌ 请输入接收邮箱！</span>';
    return;
  }
  status.textContent = '⏳ 保存中...';
  try {
    const r = await fetch(API + '/save', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(toSave)
    });
    const j = await r.json();
    if (j.ok) {
      status.innerHTML = `<span class="status ok">✅ 已保存！${toSave.email} 明天 9:30 开始收到文摘</span>`;
      document.getElementById('config-preview').textContent = JSON.stringify(toSave, null, 2);
    } else {
      status.innerHTML = '<span class="status err">❌ ' + j.error + '</span>';
    }
  } catch(e) {
    status.innerHTML = '<span class="status err">❌ 连接失败</span>';
  }
}

async function testNow() {
  const status = document.getElementById('save-status');
  await saveConfig();
  status.innerHTML += '<br>⏳ 正在生成并发送测试邮件...';
  try {
    const r = await fetch(API + '/test');
    const j = await r.json();
    if (j.ok) {
      status.innerHTML += '<br><span class="status ok">✅ 测试邮件已发送！去 ' + j.email + ' 查收</span>';
    } else {
      status.innerHTML += '<br><span class="status err">❌ ' + j.error + '</span>';
    }
  } catch(e) {
    status.innerHTML += '<br><span class="status err">❌ 测试失败: ' + e.message + '</span>';
  }
}

function showTab(name) {
  ['basic','sources','custom','rss-help','export'].forEach(t => {
    document.getElementById('tab-'+t).style.display = t===name ? 'block' : 'none';
  });
  document.querySelectorAll('.tab').forEach(b => b.classList.remove('active'));
  const labels = {basic:'📧', sources:'🐦', custom:'➕', 'rss-help':'❓', export:'📋'};
  document.querySelectorAll('.tab').forEach(b => {
    if (b.textContent.includes(labels[name])) b.classList.add('active');
  });
  if (name === 'export') {
    document.getElementById('config-preview').textContent = JSON.stringify(exportConfig(), null, 2);
  }
}

load();
</script>
</body>
</html>
HTMLEOF

echo "打开浏览器访问: http://localhost:$PORT"
echo "按 Ctrl+C 退出"

# Start Python HTTP server with API
python3 -c "
import json, os, http.server, urllib.request, subprocess, sys
from pathlib import Path

SCRIPT_DIR = '$SCRIPT_DIR'
USERS_DIR = Path(SCRIPT_DIR) / 'users'
PORT = $PORT
USER_ID = '$USER_ID'

class Handler(http.server.BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def send_json(self, data):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode('utf-8'))

    def send_html(self, path):
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.end_headers()
        with open(path) as f:
            self.wfile.write(f.read().encode())

    def do_GET(self):
        if self.path == '/':
            return self.send_html('/tmp/config-ui.html')

        if self.path == '/api/load':
            user_file = USERS_DIR / f'{USER_ID}.json'
            config = {'email': '', 'name': USER_ID, 'language': 'zh', 'sources': {'xBuilders': ['all'], 'podcasts': ['all'], 'blogs': ['all']}, 'customRss': []}
            if user_file.exists():
                with open(user_file) as f:
                    config = json.load(f)

            # Fetch available builder lists
            try:
                r = urllib.request.urlopen('https://raw.githubusercontent.com/zarazhangrui/follow-builders/main/feed-x.json', timeout=10)
                config['available'] = {'xBuilders': [{'handle': b.get('handle',''), 'name': b.get('name','')} for b in (json.loads(r.read()).get('x',[]) or [])]}
            except: config['available'] = {'xBuilders': []}
            try:
                r = urllib.request.urlopen('https://raw.githubusercontent.com/zarazhangrui/follow-builders/main/feed-podcasts.json', timeout=10)
                config['available']['podcasts'] = [{'name': p.get('name',''), 'slug': p.get('slug','')} for p in json.loads(r.read()).get('podcasts',[])]
            except: config['available']['podcasts'] = []
            return self.send_json(config)

        if self.path == '/api/test':
            user_file = USERS_DIR / f'{USER_ID}.json'
            if not user_file.exists():
                return self.send_json({'ok': False, 'error': '请先保存配置'})

            import subprocess
            try:
                result = subprocess.run(
                    ['node', str(Path(SCRIPT_DIR)/'scripts'/'prepare-digest.js'), '--user', USER_ID],
                    capture_output=True, text=True, timeout=60,
                    cwd=str(Path(SCRIPT_DIR)/'scripts'),
                    env={**os.environ, 'HOME': os.environ.get('HOME','')}
                )
                if result.returncode != 0:
                    return self.send_json({'ok': False, 'error': '拉取内容失败: ' + result.stderr[:200]})

                with open('/tmp/feed-test.json', 'w') as f:
                    f.write(result.stdout)

                result2 = subprocess.run(
                    ['node', str(Path(SCRIPT_DIR)/'scripts'/'remix-digest.js')],
                    input=result.stdout, capture_output=True, text=True, timeout=120,
                    cwd=str(Path(SCRIPT_DIR)/'scripts'),
                    env={**os.environ, 'HOME': os.environ.get('HOME','')}
                )
                if result2.returncode != 0:
                    return self.send_json({'ok': False, 'error': 'AI生成失败: ' + result2.stderr[:200]})

                with open('/tmp/digest-test.md', 'w') as f:
                    f.write(result2.stdout)

                with open(user_file) as f:
                    user_email = json.load(f).get('email','')

                result3 = subprocess.run(
                    ['node', str(Path(SCRIPT_DIR)/'scripts'/'deliver.js'), '--file', '/tmp/digest-test.md'],
                    capture_output=True, text=True, timeout=30,
                    cwd=str(Path(SCRIPT_DIR)/'scripts'),
                    env={**os.environ, 'FB_DELIVERY_METHOD': 'email', 'FB_DELIVERY_EMAIL': user_email}
                )
                return self.send_json({'ok': True, 'email': user_email, 'detail': result3.stdout})
            except Exception as e:
                return self.send_json({'ok': False, 'error': str(e)})

        return self.send_json({'error': 'not found'})

    def do_POST(self):
        if self.path == '/api/save':
            length = int(self.headers.get('Content-Length', 0))
            body = json.loads(self.rfile.read(length))
            USERS_DIR.mkdir(parents=True, exist_ok=True)
            user_file = USERS_DIR / f'{USER_ID}.json'
            to_save = {
                'email': body.get('email', ''),
                'name': body.get('name', USER_ID),
                'language': body.get('language', 'zh'),
                'sources': body.get('sources', {}),
                'customRss': body.get('customRss', []),
                'createdAt': body.get('createdAt', '')
            }
            with open(user_file, 'w') as f:
                json.dump(to_save, f, ensure_ascii=False, indent=2)
            return self.send_json({'ok': True})

        self.send_json({'error': 'not found'})

    def log_message(self, format, *args):
        pass

httpd = http.server.HTTPServer(('0.0.0.0', PORT), Handler)
print(f'Config server running on http://localhost:{PORT}')
try:
    httpd.serve_forever()
except KeyboardInterrupt:
    pass
"
