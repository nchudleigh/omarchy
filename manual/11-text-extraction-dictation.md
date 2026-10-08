# Text Extraction & Dictation

### Text Extraction

Hit `Super + Ctrl + PrtScr` to select a region on the screen for text extraction. The tesseract open source OCR model will then quickly convert that selection into text and place it on the clipboard. Then you just hit `Super + V` to paste.

This is very helpful for grabbing addresses out of image footers or phone numbers embedded in website headlines.

 ![text-extraction](images/text-extraction.webp)

### Dictation

Install [Superwhisper](https://superwhisper.com/), the default, or [Voxtype](https://voxtype.io/) through _Setup > Defaults > Dictation_ in the Omarchy menu. Selecting a backend installs it if needed and makes it the default for dictation. Voxtype loads a base English model that takes up 150MB; change the model with `voxtype setup model` and other settings through `~/.config/voxtype/config.toml`. Superwhisper opens its settings to choose cloud or local processing, and OPR keeps the application updated.

Once installed, you dictate by holding down `Right Alt` or `F9`, or by toggling with `Super + Ctrl + X`, and the dictated text will appear in the focused input area. These shortcuts are enabled only after selecting a backend. Right Alt also starts dictation when used in a modifier chord; use Left Alt for those chords. On keyboard layouts where Right Alt is AltGr, use `F9` to keep AltGr available for typing.

Select or switch your backend through Setup > Defaults > Dictation. The backend installer configures it and saves the selection. Run `omarchy default dictation` to see which one is selected. Dictation requires an explicit selection.

Omarchy loads the selected backend's desktop integration automatically. No Superwhisper configuration is needed in `~/.config/hypr/`.

Custom bindings and scripts can use `omarchy dictation start`, `omarchy dictation stop`, and `omarchy dictation toggle`. The selected backend handles the recording and transcription. The first time Superwhisper is selected, its own shortcuts are set to Omarchy's keys, `Super + Ctrl + X` to toggle and `Right Alt` to hold, and Superwhisper handles those keys itself; `F9` stays Omarchy's push-to-talk. Change them in Superwhisper's settings; selecting Superwhisper again keeps your choice. Its cancellation shortcut stays available.

Additional backends can integrate without changing Omarchy. Provide an executable named `omarchy-dictation-<backend>` on PATH that accepts `start`, `stop`, and `toggle` and returns promptly, with a nonzero status on failure. Its installer configures the provider and calls `omarchy-dictation-set-backend <backend>` after successful setup. This stops the previous backend and saves the selection atomically; `stop` must succeed when the provider is idle or unavailable. Backend names use lowercase letters, digits, and hyphens. Provide `omarchy-install-dictation-<backend>` for setup; `omarchy default dictation <backend>` launches it. Add a Defaults menu entry through an Omarchy menu extension to call that selector. Optional desktop integration can live in `${XDG_CONFIG_HOME:-$HOME/.config}/<backend>/shortcuts.lua`.
