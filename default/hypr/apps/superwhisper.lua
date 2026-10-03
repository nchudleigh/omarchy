-- Superwhisper animates its layer-shell surfaces itself.
hl.layer_rule({ match = { namespace = "^(superwhisper-edge-glow|superwhisper-indicator)$" }, no_anim = true, animation = "none" })
