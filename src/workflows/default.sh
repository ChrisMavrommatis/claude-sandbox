# Netvolution default workflow profile for bashrc.
# Loaded by ~/.bashrc.d/workflow.sh inside the claude-sandbox WSL distro
#
# __PROJECTS_DRVFS__ are replaced at install/apply time by 
# - Install-ClaudeSandbox.ps1
# - Change-Workflow.ps1
# Do not change these tokens - edit sandbox-config.ps1 to change the paths.

# === Paths (injected at install via token replacement) =============================
PROJECTS_DRVFS="__PROJECTS_DRVFS__" # e.g. D:\Projects
PROJECTS_INDEX="$HOME/.cache/projects.index"

PROJECTS_HOME="$HOME/projects"



# === Project Indexer ================================================================
PROJECTS_LIST_MOUNT="/mnt/projects_list"

# Scans PROJECTS_DRVFS and writes a list of project names to PROJECTS_INDEX.
# Mount is temporary - unmounted immediately after scanning.
index-projects() {
    local already_mounted=false
    if mountpoint -q "$PROJECTS_LIST_MOUNT" 2>/dev/null; then
        already_mounted=true
    else
        sudo mkdir -p "$PROJECTS_LIST_MOUNT"
        sudo mount -t drvfs "$PROJECTS_DRVFS" "$PROJECTS_LIST_MOUNT" \
            -o uid=1000,gid=1000,umask=022,ro \
            || { echo "Failed to mount ${PROJECTS_DRVFS}"; return 1; }
    fi

    mkdir -p "$(dirname "$PROJECTS_INDEX")"
    ls -1 "$PROJECTS_LIST_MOUNT" > "$PROJECTS_INDEX"
    local count; count=$(wc -l < "$PROJECTS_INDEX")
    [[ "$already_mounted" == false ]] && sudo umount "$PROJECTS_LIST_MOUNT"

    echo "Index updated - $count projects found:"
    sed 's/^/   /' "$PROJECTS_INDEX"
}

# == Mount Project ================================================================
mount-project() {
    local project="$1"
    local mode="${2:---rw}"
    [[ -z "$project" ]] && { echo "Usage: mount-project <project> [--ro|--rw]" >&2; return 1; }
    
    local project_path="$PROJECTS_HOME/$project"
    local winpath="$PROJECTS_DRVFS\\$project"

    local opts="uid=1000,gid=1000,umask=022"
    [[ "$mode" == "--ro" ]] && opts+=",ro"
    [[ "$mode" == "--rw" ]] && opts+=",metadata"


    mkdir -p "$project_path"

    # Already mounted? remount if mode differs
    if mountpoint -q "$project_path" 2>/dev/null; then
        local current_mode
        current_mode=$(findmnt -T $project_path  | grep -oE 'ro,|rw,' | sed 's/,//')
        if [[ "$current_mode" == "$mode" ]]; then
            echo "Project '$project' is already mounted with mode $mode"
            return 0
        else
            sudo umount "$project_path"
        fi
    fi 

    sudo mount -t drvfs "$winpath" "$project_path" -o $opts \
        || { echo "Failed to mount project '$project' at '$project_path'"; return 1; }

    echo "Project '$project' mounted at '$project_path'($mode)"
}

# === Unmount Project ================================================================
unmount-project() {
    local project="$1"
    [[ -z "$project" ]] && { echo "Usage: unmount-project <project>" >&2; return 1; }
    
    local project_path="$PROJECTS_HOME/$project"

    # cd out of the project if currently inside
    [[ "$PWD" == "$project_path"* ]] && cd "$PROJECTS_HOME"

    if mountpoint -q "$project_path" 2>/dev/null; then
        sudo umount "$project_path" \
            || { echo "Failed to unmount project '$project' at '$project_path'"; return 1; }
        echo "Project '$project' unmounted from '$project_path'"
    else
        echo "Project '$project' is not currently mounted"
    fi
}

# === Switch Project ==============================================================

switch-project() {
    local project="$1"
    [[ -z "$project" ]] && { echo "Usage: switch-project <project>" >&2; return 1; }
    
    local project_path="$PROJECTS_HOME/$project"

    if mountpoint -q "$project_path" 2>/dev/null; then
        mount-project "$project" --rw \
            || { echo "Failed to remount project '$project' with rw access"; return 1; }
    else
        mount-project "$project" --rw \
            || { echo "Failed to mount project '$project' with rw access"; return 1; }
    fi

    cd "$project_path" || { echo "Failed to cd into project '$project' at '$project_path'"; return 1; }
}

# === Tab completion ================================================================
_projects_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    [[ -f "$PROJECTS_INDEX" ]] && \
        COMPREPLY=($(compgen -W "$(cat "$PROJECTS_INDEX")" -- "$cur"))
}
complete -F _projects_complete mount-project unmount-project switch-project 

# === Welcome Message ==================================================================
_welcome() {
    local claude_ver; claude_ver=$(claude --version 2>/dev/null || echo "unknown")
    local G='\033[1;32m'  # bold green
    local C='\033[1;36m'  # bold cyan
    local D='\033[2m'     # dim
    local N='\033[0m'     # reset

    echo ""
    printf "${G}"
    cat << 'BANNER'
 __      _____ _    ___ ___  __  __ ___ 
 \ \    / / __| |  / __/ _ \|  \/  | __|
  \ \/\/ /| _|| |_| (_| (_) | |\/| | _| 
   \_/\_/ |___|____\___\___/|_|  |_|___|

BANNER
    printf "${N}"
    printf "  ${D}Claude Sandbox  |  $(whoami)@$(hostname)  |  Claude $claude_ver${N}\n"
    echo ""
    printf "  ${C}Project${N}\n"
    printf "    index-projects              Scan and index Windows projects\n"
    printf "    switch-project <name>       Mount + cd into a project (RW)\n"
    printf "    mount-project <name> --rw   Mount read-write\n"
    printf "    mount-project <name> --ro   Mount read-only\n"
    printf "    unmount-project <name>      Unmount a project\n"
    echo ""
    printf "  ${C}Claude${N}\n"
    printf "    claude                                            Interactive\n"
    printf "    claude --dangerously-skip-permissions             No prompts\n"
    printf "    claude --sandbox                                  Sandboxed\n"
    printf "    claude --sandbox --dangerously-skip-permissions   Sandboxed, no prompts\n"
    echo ""
}
_welcome