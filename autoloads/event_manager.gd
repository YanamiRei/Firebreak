extends Node

# Event Bus Autoload
# Decouples systems by providing centralized signals for combat, camera, input, and UI.

@warning_ignore_start("unused_signal")

# Combat & Juice Signals

# Player & Gameplay Signals
signal player_died()

# Input & Navigation Signals
signal fullscreen_toggled(is_fullscreen: bool)
signal max_fps_changed(max_fps: int)
signal level_restarted()
signal resolution_updated()
#signal input_device_changed(is_gamepad: bool)

@warning_ignore_restore("unused_signal")
