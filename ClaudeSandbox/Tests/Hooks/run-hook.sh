#!/bin/bash
# Runs a PreToolUse hook with a fixture file as stdin and outputs the exit code.
# Usage: run-hook.sh <hook-path> <fixture-file>
bash "$1" < "$2" > /dev/null 2>&1
echo $?
