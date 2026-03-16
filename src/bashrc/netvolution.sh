# Netvolution bashrc extension
# Loaded by ~/.bashrc.d/netvolution.sh inside the claude-sandbox WSL distro.
#
# __PROJECTS_DRVFS__ and __NETVOLUTION6_DRVFS__ are replaced at install/apply
# time by Install-ClaudeSandbox.ps1 / Apply-BashrcExtension.ps1.
# Do not change these tokens - edit sandbox-config.ps1 to change the paths.

PROJECTS_DRVFS="__PROJECTS_DRVFS__"
NETVOLUTION_DRVFS="__NETVOLUTION6_DRVFS__"

PROJECTS_LIST_MOUNT="$HOME/projects"
PROJECT_MOUNT="$HOME/current-project"
NETVOLUTION_MOUNT="$HOME/netvolution6"
PROJECTS_INDEX="$HOME/.cache/projects-index"

# === Project Indexer ================================================================
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

# === Project Switcher ==============================================================
# Unmounts the current project and mounts the selected one rw.
# Netvolution6 is always kept mounted ro at NETVOLUTION_MOUNT.
switch-project() {
    local project

    if [[ -z "$1" ]]; then
        if command -v fzf &>/dev/null; then
            project=$(cat "$PROJECTS_INDEX" | fzf --prompt="Select project: " --height=40%)
        else
            echo "Available projects:"
            mapfile -t dirs < "$PROJECTS_INDEX"
            local i=1
            for dir in "${dirs[@]}"; do
                echo "  [$i] $dir"
                ((i++))
            done
            read -rp "Enter number or name: " input
            if [[ "$input" =~ ^[0-9]+$ ]]; then
                project="${dirs[$((input-1))]}"
            else
                project="$input"
            fi
        fi
    else
        project="$1"
    fi

    [[ -z "$project" ]] && return 0

    local win_path="${PROJECTS_DRVFS}\\${project}"
    cd ~ || return 1

    if mountpoint -q "$PROJECT_MOUNT" 2>/dev/null; then
        echo "Unmounting previous project..."
        sudo umount "$PROJECT_MOUNT" || { echo "Failed to unmount"; return 1; }
    fi

    echo "Mounting ${win_path} -> ${PROJECT_MOUNT}..."
    sudo mount -t drvfs "${win_path}" "$PROJECT_MOUNT" \
        -o uid=1000,gid=1000,umask=022,metadata \
        || { echo "Mount failed - does ${PROJECTS_DRVFS}\\${project} exist?"; return 1; }

    if ! mountpoint -q "$NETVOLUTION_MOUNT" 2>/dev/null; then
        echo "Mounting Netvolution6 (ro)..."
        sudo mount -t drvfs "${NETVOLUTION_DRVFS}" "$NETVOLUTION_MOUNT" \
            -o uid=1000,gid=1000,umask=022,ro \
            || echo "Warning: could not mount Netvolution6 reference"
    fi

    cd $PROJECT_MOUNT || return 1
    echo ""
    echo "Active project : $project"
    echo "  rw -> $PROJECT_MOUNT"
    echo "  ro -> $NETVOLUTION_MOUNT"
}

# === Tab completion ================================================================
_switch_project_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    [[ -f "$PROJECTS_INDEX" ]] && \
        COMPREPLY=($(compgen -W "$(cat "$PROJECTS_INDEX")" -- "$cur"))
}
complete -F _switch_project_complete switch-project
