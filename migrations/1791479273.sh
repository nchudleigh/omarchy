echo "Preserve Voxtype as the default for existing dictation users"

backend_config="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/dictation-backend"
if [[ ! -e $backend_config ]] && omarchy-pkg-present voxtype-bin; then
  mkdir -p "${backend_config%/*}"
  printf '%s\n' voxtype > "$backend_config"
fi
