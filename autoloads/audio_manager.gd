extends Node

# AudioManager Autoload
# Manager defines the Bus and controls playback, limiting max SFX to avoid overlaps, pitch variations, and cooldowns.
# Music management offers cross fades, audio ducking, and simple management.

@export var ui_click : AudioStream = null
@export var ui_hover : AudioStream = null
@export var ui_error : AudioStream = null
@export var burn_sfx : AudioStream = null

@export_group("Tension")
@export_range(1.0, 1.3, 0.01) var tension_pitch_max : float = 1.08
@export_range(20.0, 2000.0, 1.0) var tension_highpass_hz : float = 350.0
@export_range(0.5, 4.0, 0.1) var tension_curve : float = 1.5
@export_range(-60.0, 0.0, 0.5) var fire_calm_db : float = -28.0
@export_range(-60.0, 0.0, 0.5) var fire_peak_db : float = -8.0
@export_range(0.0, 1.0, 0.01) var siren_start : float = 0.7
@export_range(-60.0, 0.0, 0.5) var siren_peak_db : float = -16.0

@onready var ambient_fire : AudioStreamPlayer = $AmbientFire
@onready var ambient_siren : AudioStreamPlayer = $AmbientSiren

var tension : float = 0.0
var highpass : AudioEffectHighPassFilter = null

#region music vars
const MUSIC_AUDIO_PLAYER_COUNT : int = 2

var current_music_player : int = 0
var music_players : Array[ AudioStreamPlayer ] = []
var music_bus : String = "Music"
var music_fade_duration : float = 0.5

var is_music_ducked: bool = false
var current_duck_db: float = 0.0
var duck_tween: Tween
#endregion 

#region SFX vars
const SFX_COOLDOWN_MS: int = 45
const MAX_CONCURRENT_SAME_SOUND: int = 2
const DEFAULT_SFX_POOL_SIZE: int = 16

var sfx_players: Array[AudioStreamPlayer] = []
var sfx_index: int = 0
var sfx_bus : String = "SFX"
var ui_bus : String = "UI"
var sound_cooldowns: Dictionary = {}
var sound_counts: Dictionary = {}
#endregion 

# Volume levels
var master_volume: float = 0.8
var music_volume: float = 0.7
var sfx_volume: float = 0.8
var ui_volume: float = 0.8

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	_setup_music_pool()
	_setup_sfx_pool()
	highpass = AudioServer.get_bus_effect(AudioServer.get_bus_index(music_bus), 0) as AudioEffectHighPassFilter
	set_tension(0.0)
	
func _setup_music_pool() -> void:
	for i in MUSIC_AUDIO_PLAYER_COUNT:
		var audioplayer = AudioStreamPlayer.new()
		add_child( audioplayer )
		audioplayer.bus = music_bus
		music_players.append ( audioplayer )
		audioplayer.volume_db=-80

func _setup_sfx_pool() -> void:
	for i in DEFAULT_SFX_POOL_SIZE:
		var audioplayer = AudioStreamPlayer.new()
		add_child( audioplayer )
		audioplayer.bus = sfx_bus
		sfx_players.append ( audioplayer )

## Call duck_music( true ) when pausing/opening menus and duck_music( false ) when closing.
func duck_music(ducked: bool, duck_amount_db: float = -12.0, fade_duration: float = 0.25) -> void:
	is_music_ducked = ducked
	current_duck_db = duck_amount_db if ducked else 0.0
	if music_players[current_music_player] == null or not music_players[current_music_player].playing:
		return
	if duck_tween and duck_tween.is_valid():
		duck_tween.kill()
	duck_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	duck_tween.tween_property(music_players[current_music_player], "volume_db", current_duck_db, fade_duration)

## Call play_music( file ) from wherever you want to change the music.  Menus have Exports to set Music file.
func play_music( _audio : AudioStream ) -> void:
	if _audio == music_players[current_music_player].stream and music_players[current_music_player].playing:
		return
	
	var _old_player : AudioStreamPlayer = music_players[ current_music_player ]
	current_music_player+=1
	if current_music_player > 1:
		current_music_player=0
	
	var _current_player : AudioStreamPlayer = music_players[ current_music_player ]
	_current_player.stream = _audio
	_play_and_fade_in( _current_player )
	_fade_out_and_stop( _old_player )
	pass

func _play_and_fade_in ( _audioplayer : AudioStreamPlayer ) -> void:
	_audioplayer.play()
	var tween : Tween = create_tween()
	tween.tween_property( _audioplayer, 'volume_db', 0, music_fade_duration )
	pass

func _fade_out_and_stop ( _audioplayer : AudioStreamPlayer ) -> void:
	var tween : Tween = create_tween()
	tween.tween_property( _audioplayer, 'volume_db', -80, music_fade_duration )
	await tween.finished
	_audioplayer.stop()
	pass

func set_master_volume(_volume: float):
	master_volume = clamp(_volume, 0.0, 1.0)
	_update_volumes()
	
func set_music_volume(_volume: float):
	music_volume = clamp(_volume, 0.0, 1.0)
	_update_volumes()

func set_sfx_volume(_volume: float):
	sfx_volume = clamp(_volume, 0.0, 1.0)
	_update_volumes()

func set_ui_volume(_volume: float):
	ui_volume = clamp(_volume, 0.0, 1.0)
	_update_volumes()

func _update_volumes():
	# Convert linear volume to decibels
	var master_player = AudioServer.get_bus_index("Master")
	if master_volume >= 0:
		AudioServer.set_bus_volume_db(master_player, linear_to_db(master_volume))
	else:
		AudioServer.set_bus_volume_db(master_player, 0)
	
	var music_player = AudioServer.get_bus_index("Music")
	if music_volume >= 0:
		AudioServer.set_bus_volume_db(music_player, linear_to_db(music_volume))
	else:
		AudioServer.set_bus_volume_db(music_player, 0)
	
	var sfx_player = AudioServer.get_bus_index("SFX")
	if sfx_volume >= 0:
		AudioServer.set_bus_volume_db(sfx_player, linear_to_db(sfx_volume))
	else:
		AudioServer.set_bus_volume_db(sfx_player, 0)

	var ui_player = AudioServer.get_bus_index("UI")
	if ui_volume >= 0:
		AudioServer.set_bus_volume_db(ui_player, linear_to_db(ui_volume))
	else:
		AudioServer.set_bus_volume_db(ui_player, 0)

## Call play_sfx ( file ) to play the audio file to the SFX bus.  You can change pitch and bus manually.
func play_sfx( _sound: AudioStream, pitch_scale_range: float = 0.08, bus_override: String = "SFX") -> void:
	if !_sound is AudioStream:
		printerr("Not valid Audio: ",str(_sound))
		return
	var sound_id : String = ""
	sound_id = _sound.resource_path
	if sound_id.is_empty():
		sound_id = str(_sound.get_instance_id())
		
	# SFX Concurrency Limiter: check play cooldown
	var now : float = Time.get_ticks_msec()
	if sound_cooldowns.has(sound_id):
		var last_time : int = sound_cooldowns[sound_id]
		if now - last_time < SFX_COOLDOWN_MS:
			var count : int = sound_counts.get(sound_id, 0)
			if count >= MAX_CONCURRENT_SAME_SOUND:
				return
			sound_counts[sound_id] = count + 1
		else:
			sound_counts[sound_id] = 1
	else:
		sound_counts[sound_id] = 1

	sound_cooldowns[sound_id] = now
	# Grab next player in pool
	var player: AudioStreamPlayer = sfx_players[sfx_index]
	sfx_index = (sfx_index + 1) % sfx_players.size()

	player.stop()
	player.stream = _sound
	player.bus = bus_override

	if pitch_scale_range > 0.0:
		player.pitch_scale = randf_range(1.0 - pitch_scale_range, 1.0 + pitch_scale_range)
	else:
		player.pitch_scale = 1.0

	player.play()

## Call play_ui () to play the default click sound, "click", "hover", or "error" can also be passed.
func play_ui( _sound : String = "click"):
	match _sound.to_lower():
		"click": play_sfx(ui_click,0.02,ui_bus)
		"hover": play_sfx(ui_hover,0.02,ui_bus)
		"error": play_sfx(ui_error,0.02,ui_bus)
	pass

func set_tension(value: float) -> void:
	tension = clampf(value, 0.0, 1.0)
	var eased : float = pow(tension, tension_curve)
	for player in music_players:
		player.pitch_scale = lerpf(1.0, tension_pitch_max, eased)
	if highpass:
		highpass.cutoff_hz = lerpf(20.0, tension_highpass_hz, eased)
	ambient_fire.volume_db = lerpf(fire_calm_db, fire_peak_db, eased)
	var siren_t : float = clampf(inverse_lerp(siren_start, 1.0, tension), 0.0, 1.0)
	ambient_siren.volume_db = lerpf(-80.0, siren_peak_db, siren_t)

func start_ambience() -> void:
	if !ambient_fire.playing:
		ambient_fire.play()
	if !ambient_siren.playing:
		ambient_siren.play()

func stop_ambience() -> void:
	ambient_fire.stop()
	ambient_siren.stop()

func play_burn() -> void:
	if burn_sfx:
		play_sfx(burn_sfx, 0.15)
