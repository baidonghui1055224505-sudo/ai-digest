#!/bin/bash
# ============================================================================
# AI Digests — 本地一键测试
# ============================================================================
# 用法:
#   ./test.sh              # 跑完整管线，输出到终端
#   ./test.sh --send       # 跑完还发邮件
#   ./test.sh xiaoming     # 指定用户
#   ./test.sh --send lisi  # 指定用户并发邮件
#
# 需要:
#   GEMINI_API_KEY 环境变量
#   RESEND_API_KEY 环境变量（仅 --send 时需要）
# ============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 解析参数
USER_ID="xiaoming"
SEND_EMAIL=false
for arg in "$@"; do
  case "$arg" in
    --send) SEND_EMAIL=true ;;
    -*) ;;
    *) USER_ID="$arg" ;;
  esac
done

# lib/fetch.js 会自动检测并使用 HTTPS_PROXY 代理
# 不需要手动处理

# 检查 key
if [ -z "$GEMINI_API_KEY" ]; then
  echo "❌ 请先设置 GEMINI_API_KEY"
  echo "   export GEMINI_API_KEY=你的key"
  exit 1
fi

cd "$SCRIPT_DIR/scripts"
npm install --silent 2>/dev/null

echo "============================================"
echo "  AI 文摘工具 — 本地测试"
echo "  用户: $USER_ID"
echo "  时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
echo ""

# Step 1: Prepare
echo "[1/3] 拉取内容..."
node prepare-digest.js --user "$USER_ID" > /tmp/feed-test.json 2>/tmp/prep-err.txt
if [ $? -ne 0 ]; then
  echo "❌ 拉取失败:"
  cat /tmp/prep-err.txt
  exit 1
fi
echo "  ✓ Feed: $(wc -c < /tmp/feed-test.json | tr -d ' ') bytes"

# Show stats
python3 -c "
import json
d = json.load(open('/tmp/feed-test.json'))
s = d['stats']
print(f'  播客: {s[\"podcastEpisodes\"]}  推文作者: {s[\"xBuilders\"]}  推文: {s[\"totalTweets\"]}  博客: {s[\"blogPosts\"]}  自定义源: {s.get(\"customFeedItems\", 0)}')
" 2>/dev/null

# Step 2: Remix with AI
echo ""
echo "[2/3] AI 生成摘要..."
node remix-digest.js < /tmp/feed-test.json > /tmp/digest-test.md 2>/tmp/remix-err.txt
if [ $? -ne 0 ]; then
  echo "❌ AI 生成失败:"
  cat /tmp/remix-err.txt
  exit 1
fi
echo "  ✓ 摘要: $(wc -c < /tmp/digest-test.md | tr -d ' ') bytes"

# Step 3: Show or send
echo ""
echo "============================================"
if $SEND_EMAIL; then
  if [ -z "$RESEND_API_KEY" ]; then
    echo "❌ 请先设置 RESEND_API_KEY"
    exit 1
  fi
  echo "[3/3] 发送邮件..."
  USER_EMAIL=$(python3 -c "import json; print(json.load(open('$SCRIPT_DIR/users/${USER_ID}.json'))['email'])")
  FB_DELIVERY_METHOD=email FB_DELIVERY_EMAIL="$USER_EMAIL" \
    node deliver.js --file /tmp/digest-test.md
  echo "  ✓ 已发送到 $USER_EMAIL"
else
  echo "[3/3] 预览（不发送邮件）:"
  echo "============================================"
  cat /tmp/digest-test.md
fi
echo ""
echo "============================================"
echo "  完成！"
echo "  完整摘要: /tmp/digest-test.md"
echo "  原始数据: /tmp/feed-test.json"
echo "============================================"
