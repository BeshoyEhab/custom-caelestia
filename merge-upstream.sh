#!/bin/bash
# merge-upstream.sh - Compare and merge upstream caelestia changes
# Usage: ./merge-upstream.sh [command]
# Commands:
#   diff [file]    - Show diff for a specific file (or all)
#   list           - List all changed files
#   merge [file]   - Merge a specific file from upstream
#   merge-all      - Merge all changed files (with backup)
#   status         - Show summary of changes

UPSTREAM="shell/upstream"
SHELL="shell"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

list_changes() {
    echo -e "${BLUE}Files changed in upstream:${NC}"
    echo "================================"
    
    # Compare key directories
    for dir in components services modules/nexus utils; do
        if [ -d "$UPSTREAM/$dir" ] && [ -d "$SHELL/$dir" ]; then
            echo -e "\n${YELLOW}=== $dir ===${NC}"
            diff -rq "$SHELL/$dir" "$UPSTREAM/$dir" 2>/dev/null | grep -v "\.git" | sed "s|$SHELL/||g" | sed "s|$UPSTREAM/||g" || true
        fi
    done
}

show_diff() {
    local file="$1"
    if [ -z "$file" ]; then
        echo "Usage: $0 diff <path/file.qml>"
        return 1
    fi
    
    local our_file="$SHELL/$file"
    local up_file="$UPSTREAM/$file"
    
    if [ ! -f "$our_file" ] && [ ! -f "$up_file" ]; then
        echo -e "${RED}File not found in either location: $file${NC}"
        return 1
    fi
    
    if [ ! -f "$our_file" ]; then
        echo -e "${GREEN}NEW FILE (only in upstream): $file${NC}"
        echo "-------------------------------------------"
        cat "$up_file"
        return 0
    fi
    
    if [ ! -f "$up_file" ]; then
        echo -e "${YELLOW}LOCAL ONLY (not in upstream): $file${NC}"
        return 0
    fi
    
    echo -e "${BLUE}Diff: $file${NC}"
    echo "=================================="
    diff -u "$our_file" "$up_file" | head -100
    if [ $(diff -u "$our_file" "$up_file" | wc -l) -gt 100 ]; then
        echo -e "\n${YELLOW}... (showing first 100 lines, use full diff for more)${NC}"
    fi
}

merge_file() {
    local file="$1"
    local up_file="$UPSTREAM/$file"
    local our_file="$SHELL/$file"
    
    if [ ! -f "$up_file" ]; then
        echo -e "${RED}File not found in upstream: $file${NC}"
        return 1
    fi
    
    if [ -f "$our_file" ]; then
        echo -e "${YELLOW}Backing up local file: $our_file -> $our_file.bak${NC}"
        cp "$our_file" "$our_file.bak"
    fi
    
    echo -e "${GREEN}Merging: $file${NC}"
    mkdir -p "$(dirname "$our_file")"
    cp "$up_file" "$our_file"
    echo -e "${GREEN}Done. Review changes and commit.${NC}"
}

merge_all() {
    echo -e "${BLUE}Merging all upstream changes with backups...${NC}"
    
    for dir in components services modules/nexus utils; do
        if [ -d "$UPSTREAM/$dir" ]; then
            echo -e "\n${YELLOW}Merging $dir...${NC}"
            find "$UPSTREAM/$dir" -type f -name "*.qml" | while read -r file; do
                local rel="${file#$UPSTREAM/}"
                merge_file "$rel"
            done
        fi
    done
    
    echo -e "\n${GREEN}All files merged with .bak backups.${NC}"
    echo "Review changes with: git diff"
    echo "Commit when ready: git add -A && git commit"
}

show_status() {
    echo -e "${BLUE}Upstream Sync Status${NC}"
    echo "===================="
    
    echo -e "\n${YELLOW}Summary of differences:${NC}"
    for dir in components services modules/nexus utils; do
        if [ -d "$UPSTREAM/$dir" ] && [ -d "$SHELL/$dir" ]; then
            local changed=$(diff -rq "$SHELL/$dir" "$UPSTREAM/$dir" 2>/dev/null | grep -v "\.git" | wc -l)
            local new=$(diff -rq "$SHELL/$dir" "$UPSTREAM/$dir" 2>/dev/null | grep "Only in $UPSTREAM" | wc -l)
            local removed=$(diff -rq "$SHELL/$dir" "$UPSTREAM/$dir" 2>/dev/null | grep "Only in $SHELL" | wc -l)
            local modified=$(diff -rq "$SHELL/$dir" "$UPSTREAM/$dir" 2>/dev/null | grep "differ" | wc -l)
            echo -e "  $dir: $modified modified, $new new, $removed local-only"
        fi
    done
}

case "${1:-help}" in
    list)
        list_changes
        ;;
    diff)
        show_diff "$2"
        ;;
    merge)
        merge_file "$2"
        ;;
    merge-all)
        merge_all
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: $0 {list|diff|merge|merge-all|status} [file]"
        echo ""
        echo "Commands:"
        echo "  list           - List all changed files"
        echo "  diff <file>    - Show diff for a specific file"
        echo "  merge <file>   - Merge a specific file from upstream"
        echo "  merge-all      - Merge all changed files (with backup)"
        echo "  status         - Show summary of changes"
        ;;
esac