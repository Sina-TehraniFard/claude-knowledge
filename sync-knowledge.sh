#!/bin/bash

# sync-knowledge.sh
# /Users/tehrani/workspace/claude-knowledge専用のgitコミット・プッシュスクリプト
# バックアップ後に自動的にgitにコミットしてプッシュする

set -e

# カラー出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 設定値
KNOWLEDGE_DIR="/Users/tehrani/workspace/claude-knowledge"
REQUIRED_BRANCH="main"  # 必要に応じて変更

# エラーハンドリング
error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

# 情報出力
info() {
    echo -e "${BLUE}INFO: $1${NC}"
}

# 成功出力
success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

# 警告出力
warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

# ヘルプ表示
show_help() {
    cat << EOF
Usage: ./sync-knowledge.sh [OPTIONS]

/Users/tehrani/workspace/claude-knowledge専用のgitコミット・プッシュスクリプト

OPTIONS:
    -h, --help          このヘルプを表示
    -m, --message MSG   コミットメッセージを指定
    -f, --force         強制実行（確認をスキップ）
    --dry-run          実際のコミット・プッシュを行わず、計画のみ表示
    -v, --verbose       詳細出力

EXAMPLES:
    # 基本的な同期
    ./sync-knowledge.sh
    
    # カスタムコミットメッセージ
    ./sync-knowledge.sh -m "Add new knowledge base entries"
    
    # ドライラン
    ./sync-knowledge.sh --dry-run
    
    # 強制実行
    ./sync-knowledge.sh --force

EOF
}

# 前提条件チェック
check_prerequisites() {
    info "前提条件をチェックしています..."
    
    # ディレクトリの存在確認
    if [[ ! -d "$KNOWLEDGE_DIR" ]]; then
        error_exit "ナレッジディレクトリが見つかりません: $KNOWLEDGE_DIR"
    fi
    
    # ディレクトリに移動
    cd "$KNOWLEDGE_DIR" || error_exit "ディレクトリに移動できません: $KNOWLEDGE_DIR"
    
    # gitリポジトリかチェック
    if [[ ! -d ".git" ]]; then
        error_exit "gitリポジトリではありません: $KNOWLEDGE_DIR"
    fi
    
    # gitコマンドの存在確認
    if ! command -v git &> /dev/null; then
        error_exit "gitがインストールされていません"
    fi
    
    success "前提条件チェック完了"
}

# git状態の確認
check_git_status() {
    info "git状態を確認しています..."
    
    # 現在のブランチ確認
    local current_branch=$(git branch --show-current)
    if [[ "$current_branch" != "$REQUIRED_BRANCH" ]]; then
        warning "現在のブランチは $current_branch です（推奨: $REQUIRED_BRANCH）"
    fi
    
    # リモートの存在確認
    if ! git remote | grep -q origin; then
        error_exit "originリモートが設定されていません"
    fi
    
    # 変更の確認
    if git diff-index --quiet HEAD --; then
        if [[ -z "$(git status --porcelain)" ]]; then
            warning "変更がありません。コミットは不要です"
            return 1
        fi
    fi
    
    success "変更が検出されました"
    return 0
}

# 変更内容の表示
show_changes() {
    info "変更内容を表示しています..."
    
    echo -e "\n${BOLD}📋 変更されたファイル:${NC}"
    git status --porcelain | while read -r line; do
        echo -e "${CYAN}  $line${NC}"
    done
    
    echo -e "\n${BOLD}📊 変更統計:${NC}"
    local added=$(git status --porcelain | grep -c "^A" || echo "0")
    local modified=$(git status --porcelain | grep -c "^M" || echo "0")
    local deleted=$(git status --porcelain | grep -c "^D" || echo "0")
    local untracked=$(git status --porcelain | grep -c "^??" || echo "0")
    
    echo -e "${GREEN}  追加: $added${NC}"
    echo -e "${YELLOW}  変更: $modified${NC}"
    echo -e "${RED}  削除: $deleted${NC}"
    echo -e "${CYAN}  未追跡: $untracked${NC}"
}

# コミットメッセージの生成
generate_commit_message() {
    local custom_message="$1"
    
    if [[ -n "$custom_message" ]]; then
        echo "$custom_message"
        return
    fi
    
    # 自動的にコミットメッセージを生成
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local added=$(git status --porcelain | grep -c "^A" || echo "0")
    local modified=$(git status --porcelain | grep -c "^M" || echo "0")
    local deleted=$(git status --porcelain | grep -c "^D" || echo "0")
    local untracked=$(git status --porcelain | grep -c "^??" || echo "0")
    
    local message="Knowledge base sync - $timestamp"
    
    if [[ $added -gt 0 ]] || [[ $untracked -gt 0 ]]; then
        message="$message\n\n新規追加: $((added + untracked)) ファイル"
    fi
    
    if [[ $modified -gt 0 ]]; then
        message="$message\n変更: $modified ファイル"
    fi
    
    if [[ $deleted -gt 0 ]]; then
        message="$message\n削除: $deleted ファイル"
    fi
    
    message="$message\n\n🤖 Generated with Claude Code sync-knowledge.sh"
    
    echo -e "$message"
}

# git操作の実行
execute_git_operations() {
    local commit_message="$1"
    local dry_run="$2"
    
    info "git操作を実行しています..."
    
    if [[ "$dry_run" == "true" ]]; then
        info "ドライラン: 以下のコマンドを実行予定:"
        echo "  git add ."
        echo "  git commit -m \"$(echo -e "$commit_message" | head -1)\""
        echo "  git push origin $(git branch --show-current)"
        return 0
    fi
    
    # ステージング
    info "変更をステージングしています..."
    git add .
    
    # コミット
    info "コミットを作成しています..."
    git commit -m "$commit_message"
    
    # プッシュ
    info "リモートにプッシュしています..."
    git push origin "$(git branch --show-current)"
    
    success "git操作完了"
}

# ユーザー確認
confirm_operation() {
    local commit_message="$1"
    local force="$2"
    
    if [[ "$force" == "true" ]]; then
        return 0
    fi
    
    echo -e "\n${BOLD}🚀 実行予定の操作:${NC}"
    echo -e "${CYAN}  1. 全ての変更をステージング${NC}"
    echo -e "${CYAN}  2. コミット作成${NC}"
    echo -e "${CYAN}  3. リモートにプッシュ${NC}"
    
    echo -e "\n${BOLD}📝 コミットメッセージ:${NC}"
    echo -e "${YELLOW}$(echo -e "$commit_message" | head -3)${NC}"
    
    echo -e "\n実行しますか？ [y/N]: \c"
    read -r response
    
    case "$response" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            info "操作がキャンセルされました"
            exit 0
            ;;
    esac
}

# メイン処理
main() {
    local custom_message=""
    local force="false"
    local dry_run="false"
    local verbose="false"
    
    # オプション解析
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -m|--message)
                custom_message="$2"
                shift 2
                ;;
            -f|--force)
                force="true"
                shift
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            -v|--verbose)
                verbose="true"
                shift
                ;;
            -*)
                error_exit "不明なオプション: $1"
                ;;
            *)
                error_exit "不明な引数: $1"
                ;;
        esac
    done
    
    # メイン処理実行
    check_prerequisites
    
    if ! check_git_status; then
        exit 0
    fi
    
    show_changes
    
    local commit_message=$(generate_commit_message "$custom_message")
    
    if [[ "$dry_run" != "true" ]]; then
        confirm_operation "$commit_message" "$force"
    fi
    
    execute_git_operations "$commit_message" "$dry_run"
    
    if [[ "$dry_run" != "true" ]]; then
        success "ナレッジベースの同期が完了しました"
        echo -e "${CYAN}リポジトリ: $KNOWLEDGE_DIR${NC}"
        echo -e "${CYAN}ブランチ: $(git branch --show-current)${NC}"
    fi
}

# スクリプト実行
main "$@"