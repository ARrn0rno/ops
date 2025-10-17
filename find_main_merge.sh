#!/bin/bash

# gh CLI と jq がインストールされているか確認
if ! command -v gh &> /dev/null; then
    echo "エラー: GitHub CLI (gh) がインストールされていません。インストールして認証してください。"
    exit 1
fi
if ! command -v jq &> /dev/null; then
    echo "エラー: jq がインストールされていません。"
    exit 1
fi

# スクリプトの使用法を表示する
if [ "$#" -ne 2 ]; then
    echo "使用法: $0 <リモートリポジトリURL> <コミットハッシュ>"
    echo "例: $0 https://github.com/octocat/Spoon-Knife.git a01f86461ffd9cac885dd9d31892f5fd0e69114b"
    exit 1
fi

REPO_URL="$1"
COMMIT_HASH="$2"

# 共通の関数を作成
get_pr_info() {
    local BASE_BRANCH=$1
    echo "---"
    echo "## ${BASE_BRANCH}ブランチへのPR情報"
    
    PR_INFO=$(gh pr list --state merged --base "$BASE_BRANCH" --limit 1 --json number,title,url,mergedAt --search "commit:$COMMIT_HASH" --repo "$REPO_URL" 2>/dev/null)

    # PRが見つからない場合はエラー
    if [ "$(echo "$PR_INFO" | jq -r '.[0].number')" == "null" ]; then
        echo "指定されたコミットを含む、${BASE_BRANCH}にマージされたPRは見つかりませんでした。"
    else
        # JSONから必要な情報を抽出
        PR_NUMBER=$(echo "$PR_INFO" | jq -r '.[0].number')
        PR_TITLE=$(echo "$PR_INFO" | jq -r '.[0].title')
        PR_URL=$(echo "$PR_INFO" | jq -r '.[0].url')
        MERGED_AT_UTC=$(echo "$PR_INFO" | jq -r '.[0].mergedAt')

        MERGED_AT_JST=$(perl -MTime::Piece -MTime::Seconds -e '
          my $tp = Time::Piece->strptime("'"$MERGED_AT_UTC"'", "%Y-%m-%dT%H:%M:%SZ");
          $tp += ONE_HOUR * 9;
          print $tp->strftime("%Y/%m/%d %H:%M:%S\n");
        ')

        # 結果を出力
        echo "PR番号: $PR_NUMBER"
        echo "タイトル: $PR_TITLE"
        echo "URL: $PR_URL"
        echo "マージ日時: $MERGED_AT_JST"
    fi
}

# mainブランチへのPR情報を取得
get_pr_info "main"

# developブランチへのPR情報を取得
get_pr_info "develop"