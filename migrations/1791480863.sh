echo "Invite Voxtype users to try Superwhisper, now the default dictation"

# Existing accounts finished first-run before Superwhisper became the default,
# so the only invitation they ever saw was Voxtype's. Post-update hooks run
# later in this same update, after the shell restart, so the invitation appears
# without waiting for another one and is not lost to that restart. The hook
# decides whether to notify.
omarchy-hook-install post-update "$OMARCHY_PATH/install/user/first-run/try-superwhisper.hook"
