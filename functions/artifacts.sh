#!/bin/bash
# Artifact generation functions for cursor_bundle

# Create release artifacts
create_artifacts() {
    local version="$1"
    local output_dir="${2:-artifacts}"
    
    if [ -z "$version" ]; then
        echo "Version is required for artifact creation" >&2
        return 1
    fi
    
    echo "Creating artifacts for version $version..." >&2
    
    # Create output directory
    mkdir -p "$output_dir"
    
    local base_name="cursor_bundle_${version}"
    local success_count=0
    local total_count=0
    
    # Create source archive
    ((total_count++))
    if create_source_archive "$version" "$output_dir/$base_name"; then
        ((success_count++))
    fi
    
    echo "Artifacts created: $success_count/$total_count" >&2
    
    if [ $success_count -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

# Create source code archive
create_source_archive() {
    local version="$1"
    local base_name="$2"
    
    echo "Creating source archive..." >&2
    
    # Create tar with exclusions
    if tar --exclude=".git" --exclude="node_modules" --exclude="build" --exclude="dist" --exclude="*.log" -czf "${base_name}_source.tar.gz" .; then
        echo "Source archive created: ${base_name}_source.tar.gz" >&2
        return 0
    else
        echo "Failed to create source archive" >&2
        return 1
    fi
}