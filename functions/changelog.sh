#!/bin/bash
# Changelog generation functions for cursor_bundle

# Generate changelog from git history
generate_changelog() {
    local version="$1"
    local since_tag="$2"
    local output_file="${3:-CHANGELOG.md}"
    
    if [ -z "$version" ]; then
        echo "Version is required for changelog generation" >&2
        return 1
    fi
    
    echo "Generating changelog for version $version..." >&2
    
    # Get commit range
    local commit_range=""
    if [ -n "$since_tag" ] && git rev-parse "$since_tag" >/dev/null 2>&1; then
        commit_range="${since_tag}..HEAD"
    else
        commit_range="HEAD"
    fi
    
    # Create changelog entry
    local changelog_entry=""
    changelog_entry+="## [$version] - $(date +%Y-%m-%d)\n\n"
    
    # Get commits and add them
    changelog_entry+="### Changes\n"
    while IFS= read -r commit; do
        local msg=$(echo "$commit" | cut -d' ' -f2-)
        local hash=$(echo "$commit" | cut -d' ' -f1)
        changelog_entry+="- $msg ($hash)\n"
    done < <(git log --oneline "$commit_range" 2>/dev/null | head -10)
    
    # Create or update changelog file
    if [ ! -f "$output_file" ]; then
        cat > "$output_file" << EOF
# Changelog

All notable changes to this project will be documented in this file.

EOF
        echo -e "$changelog_entry" >> "$output_file"
    else
        # Insert new entry after header
        local temp_file=$(mktemp)
        awk -v new_entry="$changelog_entry" '
            /^# Changelog/ { 
                print
                getline
                print
                getline
                print
                print new_entry
                next 
            }
            { print }
        ' "$output_file" > "$temp_file"
        mv "$temp_file" "$output_file"
    fi
    
    echo "Changelog updated: $output_file" >&2
}