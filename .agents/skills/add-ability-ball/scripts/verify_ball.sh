#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/../../../.." && pwd)"
project_dir="${1:-$project_root}"
ball_id="${2:-}"
godot_bin="${GODOT_BIN:-godot}"

if [[ ! -f "$project_dir/project.godot" ]]; then
	echo "Ability Ball project not found: $project_dir" >&2
	exit 2
fi

if [[ -n "$ball_id" ]]; then
	if [[ ! "$ball_id" =~ ^[a-z][a-z0-9]*(_[a-z0-9]+)*$ ]]; then
		echo "Ball ID must use lowercase snake case: $ball_id" >&2
		exit 2
	fi
	ball_dir="$project_dir/scripts/balls/$ball_id"
	for required_file in module.gd visual.gd; do
		if [[ ! -f "$ball_dir/$required_file" ]]; then
			echo "Missing required ball file: $ball_dir/$required_file" >&2
			exit 2
		fi
	done
	ability_resource="$({
		sed -nE 's|^[[:space:]]*const[[:space:]]+AbilityScript[[:space:]]*:=[[:space:]]*preload\("res://([^\"]+)"\).*|\1|p' "$ball_dir/module.gd"
	} | head -n 1)"
	if [[ -z "$ability_resource" ]]; then
		echo "Ball module does not declare AbilityScript preload: $ball_dir/module.gd" >&2
		exit 2
	fi
	ability_file="$project_dir/$ability_resource"
	case "$ability_file" in
		"$ball_dir"/*.gd) ;;
		*)
			echo "Ball AbilityScript must stay inside its own directory: $ability_resource" >&2
			exit 2
			;;
	esac
	if [[ ! -f "$ability_file" ]]; then
		echo "Missing declared ball ability file: $ability_file" >&2
		exit 2
	fi
fi

if ! command -v "$godot_bin" >/dev/null 2>&1; then
	echo "Godot executable not found: $godot_bin" >&2
	exit 2
fi

"$godot_bin" --headless --path "$project_dir" --editor --quit
"$godot_bin" --headless --path "$project_dir" --script res://tests/test_architecture.gd
"$godot_bin" --headless --path "$project_dir" --script res://tests/test_battle.gd
"$godot_bin" --headless --path "$project_dir" --script res://tests/test_roster_battle.gd
"$godot_bin" --headless --path "$project_dir" --script res://tests/test_roster_view.gd
"$godot_bin" --headless --path "$project_dir" --script res://tests/test_battle_logger.gd
"$godot_bin" --headless --path "$project_dir" --quit-after 120
