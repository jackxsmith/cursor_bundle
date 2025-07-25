#!/usr/bin/env bash
# Todo Integration for Comprehensive Logging
# Provides integration between TodoWrite tool and comprehensive logging system

set -euo pipefail
IFS=$'\n\t'

# Source comprehensive logging if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/comprehensive_logging.sh" ]]; then
    source "$SCRIPT_DIR/comprehensive_logging.sh"
fi

# Todo tracking functions
track_todo_creation() {
    local todo_content="$1"
    local status="${2:-pending}"
    local priority="${3:-medium}"
    local todo_id="${4:-$(date +%s)}"
    local context="${5:-${FUNCNAME[1]:-unknown}}"
    
    log_todo "CREATE" "$todo_id" "$todo_content" "$status" "$priority" "$context"
    log_update "TODO_CREATED" "" "$todo_content" "$context" "id=$todo_id status=$status priority=$priority"
}

track_todo_update() {
    local todo_id="$1"
    local old_status="$2"
    local new_status="$3"
    local todo_content="$4"
    local priority="${5:-medium}"
    local context="${6:-${FUNCNAME[1]:-unknown}}"
    
    log_todo "UPDATE" "$todo_id" "$todo_content" "$new_status" "$priority" "$context"
    log_update "TODO_STATUS_CHANGE" "$old_status" "$new_status" "$context" "id=$todo_id content=$todo_content"
}

track_todo_completion() {
    local todo_id="$1"
    local todo_content="$2"
    local priority="${3:-medium}"
    local context="${4:-${FUNCNAME[1]:-unknown}}"
    
    log_todo "COMPLETE" "$todo_id" "$todo_content" "completed" "$priority" "$context"
    log_update "TODO_COMPLETED" "pending/in_progress" "completed" "$context" "id=$todo_id content=$todo_content"
}

track_todo_deletion() {
    local todo_id="$1"
    local todo_content="$2"
    local reason="${3:-removed}"
    local context="${4:-${FUNCNAME[1]:-unknown}}"
    
    log_todo "DELETE" "$todo_id" "$todo_content" "deleted" "medium" "$context"
    log_update "TODO_DELETED" "active" "deleted" "$context" "id=$todo_id reason=$reason"
}

# Progress tracking
track_progress() {
    local task_name="$1"
    local current_step="$2"
    local total_steps="$3"
    local step_description="${4:-}"
    local context="${5:-${FUNCNAME[1]:-unknown}}"
    
    local percentage=$((current_step * 100 / total_steps))
    local progress_info="step=$current_step/$total_steps ($percentage%)"
    
    log_update "PROGRESS_UPDATE" "" "$task_name" "$context" "$progress_info description=[$step_description]"
    log_comprehensive "INFO" "Progress: $task_name ($percentage%)" "$context" "$progress_info"
}

# Milestone tracking
track_milestone() {
    local milestone_name="$1"
    local milestone_type="${2:-completed}"  # started, completed, failed
    local description="${3:-}"
    local context="${4:-${FUNCNAME[1]:-unknown}}"
    
    log_update "MILESTONE_$milestone_type" "" "$milestone_name" "$context" "description=[$description]"
    log_comprehensive "INFO" "Milestone $milestone_type: $milestone_name" "$context" "type=$milestone_type"
}

# Export functions
export -f track_todo_creation track_todo_update track_todo_completion track_todo_deletion
export -f track_progress track_milestone