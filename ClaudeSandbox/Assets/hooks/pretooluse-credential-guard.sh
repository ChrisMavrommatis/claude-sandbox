#!/usr/bin/env bash
# PreToolUse hook: block reads of credential file patterns
# Claude Code passes tool name and input as JSON to stdin.
# Exit 2 to block, exit 0 to allow.

input=$(cat)
tool=$(echo "$input" | grep -oP '"tool_name"\s*:\s*"\K(?:\\.|[^"])*' 2>/dev/null)

# -- File-based tools (Read / Edit / Write) --

if [[ "$tool" == "Read" || "$tool" == "Edit" || "$tool" == "Write" ]]; then
    path=$(echo "$input" | grep -oP '"file_path"\s*:\s*"\K(?:\\.|[^"])*' 2>/dev/null)

    # Block Kubernetes config by path -- standard location uses filename "config"
    # which is too generic to block by name alone
    if [[ "$path" == *"/.kube/config" ]] || [[ "$path" == *"/.kube/config.d/"* ]]; then
        echo "Blocked: Kubernetes config file ($path)" >&2
        exit 2
    fi

    # Block by filename pattern
    patterns=(
        ".env"
        ".env.*"
        "*.pem"
        "*.key"
        "*.p12"
        "*.pfx"
        "*credentials*"
        "*secret*"
        "*.token"
        "id_rsa"
        "id_ed25519"
        "*.ovpn"
        "kubeconfig"
        "kube.config"
        "*.kubeconfig"
    )

    filename=$(basename "$path")
    for pattern in "${patterns[@]}"; do
        if [[ "$filename" == $pattern ]]; then
            echo "Blocked: credential file pattern matched ($filename)" >&2
            exit 2
        fi
    done

    exit 0
fi

# -- Bash tool: match credential file extensions/names in the command string --

if [[ "$tool" == "Bash" ]]; then
    cmd=$(echo "$input" | grep -oP '"command"\s*:\s*"\K(?:\\.|[^"])*' 2>/dev/null)

    # Block by extension or known credential filename appearing in the command
    bash_patterns=(
        '\.env\b'
        '\.pem\b'
        '\.key\b'
        '\.p12\b'
        '\.pfx\b'
        '\.token\b'
        '\.ovpn\b'
        '\.kubeconfig\b'
        '\bid_rsa\b'
        '\bid_ed25519\b'
        '\bkubeconfig\b'
        '\bkube\.config\b'
        '\bcredentials\b'
        '\bsecret\b'
    )

    for pattern in "${bash_patterns[@]}"; do
        if echo "$cmd" | grep -qE "$pattern"; then
            echo "Blocked: credential file pattern in bash command" >&2
            exit 2
        fi
    done

    # Block Kubernetes config path in command
    if echo "$cmd" | grep -qE '\.kube/config'; then
        echo "Blocked: Kubernetes config path in bash command" >&2
        exit 2
    fi

    exit 0
fi

exit 0
