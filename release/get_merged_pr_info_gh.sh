#!/bin/bash

# GNU date (gdate) がインストールされているか確認し、コマンドを決定
if command -v gdate &> /dev/null
then
  DATE_CMD="gdate"
else
  DATE_CMD="date"
fi

# PRのURLを引数として受け取る
PR_URL=$1

if [ -z "$PR_URL" ]; then
  echo "Usage: $0 <PR_URL>"
  exit 1
fi

# URLからオーナー、リポジトリ名、PR番号を抽出
OWNER=$(echo "$PR_URL" | sed -E 's/https:\/\/github.com\/([^\/]+)\/([^\/]+)\/pull\/([0-9]+).*/\1/')
REPO=$(echo "$PR_URL" | sed -E 's/https:\/\/github.com\/([^\/]+)\/([^\/]+)\/pull\/([0-9]+).*/\2/')
PR_NUMBER=$(echo "$PR_URL" | sed -E 's/https:\/\/github.com\/([^\/]+)\/([^\/]+)\/pull\/([0-9]+).*/\3/')

if [ -z "$OWNER" ] || [ -z "$REPO" ] || [ -z "$PR_NUMBER" ]; then
  echo "Invalid GitHub PR URL provided."
  exit 1
fi

# ghコマンドで元のPRのタイトルとマージ日時（Unix秒）を取得
# Unix秒に変換することで、dateコマンドで正確なJST変換が可能になる
PR_INFO_JSON=$(gh pr view "$PR_NUMBER" --repo "$OWNER/$REPO" --json title,mergedAt)
MAIN_PR_TITLE=$(echo "$PR_INFO_JSON" | jq -r '.title')

# --- JSTへの正確な変換 ---
# 1. mergedAtをjqでUnix秒に変換（fromdateiso8601）
MERGED_AT_UNIX=$(echo "$PR_INFO_JSON" | jq -r '.mergedAt | fromdateiso8601')

# 2. dateコマンドにUnix秒を渡し、TZ=Asia/Tokyoを設定してJSTでフォーマット
#    macOS date (-rオプション) と GNU date (-d "@"オプション) の両方に対応
if [ "$DATE_CMD" = "gdate" ]; then
  MERGED_AT_JST=$(TZ=Asia/Tokyo "$DATE_CMD" -d "@$MERGED_AT_UNIX" +"%Y/%m/%d %H:%M:%S")
else
  # macOSのdateコマンドを使用: -r (reference time) オプションを使用
  MERGED_AT_JST=$(TZ=Asia/Tokyo "$DATE_CMD" -r "$MERGED_AT_UNIX" +"%Y/%m/%d %H:%M:%S")
fi
# --------------------------

# ヘッダー情報を出力
echo "$REPO $MAIN_PR_TITLE"
echo "Released at: $MERGED_AT_JST"
echo "Merged PRs:"
echo ""

# コミット一覧の取得 (gh api + --paginate で全件取得)
COMMITS_MESSAGES=$(gh api repos/"$OWNER"/"$REPO"/pulls/"$PR_NUMBER"/commits --paginate | jq -r '.[].commit.message | split("\n")[0]')

echo "$COMMITS_MESSAGES" | while read -r COMMIT_MESSAGE; do

  # 'Merge pull request #<数字> from' というパターンからPR番号を抽出
  MERGED_PR_NUMBER=$(echo "$COMMIT_MESSAGE" | sed -E 's/.*Merge pull request #([0-9]+) from.*/\1/')

  # 抽出できた場合のみ処理を続行
  if [ -n "$MERGED_PR_NUMBER" ] && [[ "$MERGED_PR_NUMBER" =~ ^[0-9]+$ ]]; then
    # ghコマンドで元のPRの情報を取得
    PR_INFO_JSON=$(gh pr view "$MERGED_PR_NUMBER" --repo "$OWNER/$REPO" --json title,url,author)

    TITLE=$(echo "$PR_INFO_JSON" | jq -r '.title')
    AUTHOR=$(echo "$PR_INFO_JSON" | jq -r '.author.login')
    URL=$(echo "$PR_INFO_JSON" | jq -r '.url')

    # Slackに貼り付けやすいようにMarkdown形式で出力
    echo "- $TITLE $AUTHOR $URL"
  fi

done