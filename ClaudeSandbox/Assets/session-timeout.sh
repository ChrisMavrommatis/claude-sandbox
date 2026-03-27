# Session timeout - auto-close idle shells
# Deployed by Install-Sandbox. Value set at install time.
# __SESSION_TIMEOUT__ is replaced with the configured value (0 = disabled).

if [ "__SESSION_TIMEOUT__" -gt 0 ] 2>/dev/null; then
    readonly TMOUT=__SESSION_TIMEOUT__
    export TMOUT
fi
