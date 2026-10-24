# Godot 4 Game Jam Starter Kit

A battle-tested, production-ready starter kit for Godot 4.x (v4.3 / v4.4 / v4.7+).
Designed so you can spend your 48–72 game jam hours building fun gameplay, instead of re-inventing menus, audio managers, jump physics, camera shake, and settings menus from scratch.

## 60-Second Quickstart
Open Godot 4: 
-Click Import
-Select the folder containing project.godot.

Press F5 (Run Project):
-Click anywhere on the Click to Start screen (this unlocks browser audio for web builds).
-Click through menus to explore setup

## Explore the Showcase Playground:

## Controls & Debugging Shortcuts
Action	Keyboard / Mouse
Move	W, A, S, D or Arrow Keys
Pause Game	Escape	
Instant Jam Restart	R (Instantly reloads gameplay)

## How to Build Your Jam Game in 5 Minutes

### Connect Your Level to the Main Menu
Create your new level scene (e.g. res://scenes/levels/level_1.tscn).
Open res://scenes/menus/main_menu.gd and change:

func _on_play_pressed() -> void:
	SceneManager.fade_scene("res://scenes/main.tscn")

That's it! Your game now has a full title screen, options menu, and game over screen wired up automatically.
To add in the Pause Menu, add it under your HUD/Canvas Layer in your level.

## Copy-Paste Systems Cheatsheet

Everything in this starter kit is designed to be called with a single line of clean GDScript.

### 1. Audio Manager (AudioManager)

All audio routes through a calibrated safe bus layout (Master set to -6 dB to prevent deafening players on itch.io).

Play UI Sounds
**Available: "click", "hover", "error"**
AudioManager.play_ui("error")
These can be customized in the \autoloads\audio_manager.tscn Scene

Play custom audio file
AudioManager.play_sfx(preload("res://my_sound.wav"))

Play with custom pitch variance (e.g. 0.08 range) and volume offset
AudioManager.play_sfx(preload("res://my_sound.wav"), 0.1, -2.0)

Crossfade music smoothly
AudioManager.play_music(preload("res://my_music.ogg"))

Duck music during pause/menus (-12 dB relative attenuation)
AudioManager.duck_music(true)   # Menu opened
AudioManager.duck_music(false)  # Menu closed

### 2. Scene Transitions (SceneManager)

Smooth fade-to-black scene change
SceneManager.fade_scene("res://scenes/levels/level_2.tscn")

Smooth wipe fade-to-black scene change (To the Right for example)
SceneManager.fade_scene("res://scenes/levels/level_2.tscn", Vector2.RIGHT)

Instant reload current level
SceneManager.reload_current_scene()

Reload last gameplay level (used on Game Over retry)
SceneManager.reload_last_gameplay_scene()
(Pressing R at any time during gameplay triggers an instant reload for rapid level testing).

## Project Directory Structure

res://
-actors/
 -enemies/               # Enemy Scenes and Files
  -players/              # Player Scenes and Files
-assets/
 -audio/                 # Music and SFX files
 -fonts/                 # Font files
  -ui/                   # Icons and backgrounds
-autoload/
 -audio_manager.gd       # Buses, crossfade, pitch variance, concurrency limiter
 -audio_manager.tscn     # Autoload Scene with @exports to override default sounds
 -event_manager.gd       # Central decoupled signal bus
 -save_manager.gd        # ConfigFile persistence (Audio, Video, Max FPS, etc)
 -scene_manager.gd       # Fade transitions & instant reload
 -scene_manager.tscn     # ColorRects used to complete directional fades
-components/
 -combat/                # Place holder
 -juice/                 # Place holder
-scenes/
 -levels/
  -playground.gd         # Sample Level Script
  -playground.tscn       # Sample Scene with Pause Menu
 -menus/
  -click_to_start.tscn   # Web AudioContext unlocker (run/main_scene)
  -credits.tscn          # Auto-scrolling credits screen
  -credits.txt           # Plain-text source file for easy editing
  -game_over_menu.tscn   # Try Again (R), Main Menu
  -how_to_play.tscn      # Controls & objective card
  -main_menu.tscn        # Play, Options, How to Play, Credits, Quit
  -options_menu.tscn     # Volumes, Fullscreen, VSync, Max FPS dropdown
  -pause_menu.tscn       # In-game pause overlay
-systems/
 -hud/
  -floating_text/        # Place holder
  -health_bar/           # Place holder
 -state_machine/         # Place holder
 -ui/
  -panel_container.theme # Theme for all the buttons/Panels in the template
  -ui_button.gd          # UI Button Class to map Audio and Grow/Shrink
-web_export/             # Place holder for Exported Project
-default_bus_layout.tres # Master, Music, SFX, UI buses
-export_presets.cfg      # Single-threaded web export preset
-project.godot           # Pre-configured input map, autoloads, resolution
-Submission_Checklist.md # Pre-jam triage & itch.io publishing checklist

## Publishing to itch.io (Web Export)
Pre-configured Preset: 
Open Project.
Click Export. 

Audio Unlocking: The main scene is set to click_to_start.tscn to satisfy browser autoplay restrictions.

Publishing Checklist: Read SUBMISSION_CHECKLIST.md for recommended embed dimensions (1280x720), thumbnail specs, and last-minute pre-jam sanity audits.

## License
This starter kit is released under the MIT License. Use it for free in any personal, commercial, or game jam project. No attribution required (though a shoutout or Tip is always appreciated!).
