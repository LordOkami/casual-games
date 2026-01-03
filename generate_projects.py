#!/usr/bin/env python3
"""
Script to generate all 16 independent Godot 4.5.1 casual game projects.
Each game is a standalone project with its own copy of shared files.
"""

import os
import shutil

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TEMPLATE_DIR = os.path.join(BASE_DIR, "_template")

GAMES = [
    {
        "folder": "01_flappy_clone",
        "name": "Flappy Clone",
        "description": "Tap to fly through pipes",
        "color": "#e63946"
    },
    {
        "folder": "02_stack_tower",
        "name": "Stack Tower",
        "description": "Stack blocks perfectly",
        "color": "#f4a261"
    },
    {
        "folder": "03_color_switch",
        "name": "Color Switch",
        "description": "Pass through matching colors",
        "color": "#2a9d8f"
    },
    {
        "folder": "04_endless_runner",
        "name": "Endless Runner",
        "description": "Run and jump obstacles",
        "color": "#264653"
    },
    {
        "folder": "05_2048",
        "name": "2048",
        "description": "Slide and combine numbers",
        "color": "#e9c46a"
    },
    {
        "folder": "06_snake",
        "name": "Snake",
        "description": "Classic snake game",
        "color": "#4caf50"
    },
    {
        "folder": "07_breakout",
        "name": "Breakout",
        "description": "Destroy blocks with ball",
        "color": "#9c27b0"
    },
    {
        "folder": "08_tap_dash",
        "name": "Tap Dash",
        "description": "Tap at turns to change direction",
        "color": "#00bcd4"
    },
    {
        "folder": "09_ball_bounce",
        "name": "Ball Bounce",
        "description": "Timing-based bouncing",
        "color": "#ff5722"
    },
    {
        "folder": "10_whack_mole",
        "name": "Whack-a-Mole",
        "description": "Tap targets quickly",
        "color": "#795548"
    },
    {
        "folder": "11_doodle_jump",
        "name": "Doodle Jump",
        "description": "Jump on platforms upward",
        "color": "#8bc34a"
    },
    {
        "folder": "12_pong",
        "name": "Pong",
        "description": "Classic paddle game vs AI",
        "color": "#3f51b5"
    },
    {
        "folder": "13_memory_match",
        "name": "Memory Match",
        "description": "Match card pairs",
        "color": "#673ab7"
    },
    {
        "folder": "14_fruit_slice",
        "name": "Fruit Slice",
        "description": "Swipe to slice fruits",
        "color": "#ff9800"
    },
    {
        "folder": "15_tetris",
        "name": "Tetris",
        "description": "Classic falling blocks",
        "color": "#009688"
    },
    {
        "folder": "16_bubble_pop",
        "name": "Bubble Pop",
        "description": "Pop bubbles before they escape!",
        "color": "#00bcd4"
    }
]

PROJECT_GODOT_TEMPLATE = '''; Engine configuration file.
; Godot 4.5.1

config_version=5

[application]

config/name="{name}"
config/description="{description}"
run/main_scene="res://scenes/main_menu.tscn"
config/features=PackedStringArray("4.5", "Mobile")
config/icon="res://icon.svg"

[autoload]

GameManager="*res://autoload/game_manager.gd"
AudioManager="*res://autoload/audio_manager.gd"

[display]

window/size/viewport_width=720
window/size/viewport_height=1280
window/size/mode=2
window/stretch/mode="viewport"
window/stretch/aspect="keep"
window/handheld/orientation=1

[input]

tap={{
"deadzone": 0.5,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":1,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":1,"canceled":false,"pressed":true,"double_click":false)]
}}
swipe_left={{
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":97,"location":0,"echo":false,"script":null)]
}}
swipe_right={{
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":100,"location":0,"echo":false,"script":null)]
}}
swipe_up={{
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":119,"location":0,"echo":false,"script":null)]
}}
swipe_down={{
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":83,"key_label":0,"unicode":115,"location":0,"echo":false,"script":null)]
}}

[rendering]

renderer/rendering_method="mobile"
textures/vram_compression/import_etc2_astc=true
'''

def create_project(game):
    """Create a complete independent Godot project for a game."""
    project_dir = os.path.join(BASE_DIR, game["folder"])

    # Create directories
    os.makedirs(os.path.join(project_dir, "autoload"), exist_ok=True)
    os.makedirs(os.path.join(project_dir, "scenes"), exist_ok=True)
    os.makedirs(os.path.join(project_dir, "assets"), exist_ok=True)

    # Copy template files
    for item in ["autoload", "scenes", "icon.svg"]:
        src = os.path.join(TEMPLATE_DIR, item)
        dst = os.path.join(project_dir, item)
        if os.path.isdir(src):
            if os.path.exists(dst):
                shutil.rmtree(dst)
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)

    # Create project.godot
    project_godot = PROJECT_GODOT_TEMPLATE.format(
        name=game["name"],
        description=game["description"]
    )
    with open(os.path.join(project_dir, "project.godot"), "w") as f:
        f.write(project_godot)

    # Update main_menu.tscn with game-specific values
    menu_path = os.path.join(project_dir, "scenes", "main_menu.tscn")
    with open(menu_path, "r") as f:
        content = f.read()

    content = content.replace('game_name = "Game Name"', f'game_name = "{game["name"]}"')
    content = content.replace('primary_color = Color(0.9, 0.22, 0.27, 1)', f'primary_color = Color("{game["color"]}")')

    with open(menu_path, "w") as f:
        f.write(content)

    print(f"Created: {game['folder']} - {game['name']}")

def main():
    print("Generating 16 independent Godot 4.5.1 projects...\n")

    for game in GAMES:
        create_project(game)

    print("\nDone! Each project is in its own folder.")
    print("Open any project.godot file with Godot 4.5.1 to start editing.")

if __name__ == "__main__":
    main()
