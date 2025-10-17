#!/bin/bash

# --- 引数の検証と設定 ---

# 引数が2つ（リポジトリ名とユーザー名）渡されているか確認
if [ "$#" -ne 2 ]; then
    echo "エラー: 引数が不足しています。"
    echo "使用法: $0 <オーナー名>/<リポジトリ名> <ユーザー名>"
    echo "例: $0 cli/cli octocat"
    exit 1
fi

# 引数を変数に代入
REPO_NAME="$1"
TARGET_USER="$2"

# --- メイン処理 ---

echo "🔄 検索を開始します..."
echo "リポジトリ: $REPO_NAME"
echo "ユーザー: $TARGET_USER"
echo "-----------------------------------"

# 1. gh CLI を使用してPRのリストを取得する
#    -R: リポジトリ指定
#    --author: 作者指定
#    --state: PRの状態 (open を使用していますが、すべて含める場合は all に変更)
#    --json: 出力形式をJSONに指定
#    --limit: 取得するPRの最大数 (多い場合は適宜増やす)
PR_DATA=$(gh pr list -R "$REPO_NAME" --author "$TARGET_USER" --state merged --json title --limit 100 2>/dev/null)

# gh コマンドの実行エラーチェック
if [ $? -ne 0 ]; then
    echo "🚨 エラー: gh コマンドの実行に失敗しました。"
    echo "リポジトリ名 '$REPO_NAME' またはユーザー名 '$TARGET_USER' が正しいか、"
    echo "gh CLIが認証されているか確認してください。"
    exit 1
fi

# 2. 該当するPRがなかった場合のチェック
if [ -z "$PR_DATA" ] || [ "$PR_DATA" = "[]" ]; then
    echo "該当するオープンなプルリクエストは見つかりませんでした。"
    echo "(クローズ済みのPRも含める場合は、スクリプト内の --state を 'all' に変更してください。)"
    exit 0
fi

# 3. jq を使用してPRの数をカウントし、タイトルを抽出する
PR_COUNT=$(echo "$PR_DATA" | jq 'length')
PR_TITLES=$(echo "$PR_DATA" | jq -r '.[].title')

# --- 結果の出力 ---

echo "✅ PRの総作成数 (マージされたPR): $PR_COUNT 件"
echo ""
echo "📝 PRのタイトル一覧:"
echo "-----------------------------------"
echo "$PR_TITLES"
echo "-----------------------------------"