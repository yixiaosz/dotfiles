#!/usr/bin/env bash
SESSION_NAME="main"

if [[ -n "$TMUX" ]]; then
    exec "${SHELL:-/bin/bash}"
fi

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    exec tmux attach -t "$SESSION_NAME"
fi

tmux new-session -d -s "$SESSION_NAME" -n homepage
tmux new-window -t "$SESSION_NAME" -n extra1
tmux new-window -t "$SESSION_NAME" -n extra2
tmux new-window -t "$SESSION_NAME" -n ssh
tmux select-window -t "$SESSION_NAME:0"
exec tmux attach -t "$SESSION_NAME"