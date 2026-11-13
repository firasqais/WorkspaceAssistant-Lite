#!/bin/zsh
# Double-click to build "Workspace Assistant Tutorial.doccarchive" next to this file.
# Participants double-click that archive to open the tutorial in Xcode.
cd "$(dirname "$0")"
OUT="Workspace Assistant Tutorial.doccarchive"
rm -rf "$OUT"
xcrun docc convert WorkspaceAssistant.docc \
  --fallback-display-name "Workspace Assistant" \
  --fallback-bundle-identifier au.edu.uts.WorkspaceAssistant.tutorial \
  --output-dir "$OUT" && echo "\nDone: $OUT" && open -R "$OUT"
