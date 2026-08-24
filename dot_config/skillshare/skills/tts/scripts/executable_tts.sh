#!/usr/bin/env bash

set -euo pipefail

usage() {
	printf '%s\n' 'Usage: tts.sh --output PATH [--input-file PATH | -- TEXT] [--voice NAME] [--rate WPM] [--force]'
}

output=''
input_file=''
voice=''
rate=''
force=false
text_parts=()

while (($# > 0)); do
	case "$1" in
		-o | --output)
			(($# >= 2)) || { printf '%s\n' 'Missing value for --output.' >&2; exit 2; }
			output=$2
			shift 2
			;;
		-f | --input-file)
			(($# >= 2)) || { printf '%s\n' 'Missing value for --input-file.' >&2; exit 2; }
			input_file=$2
			shift 2
			;;
		-v | --voice)
			(($# >= 2)) || { printf '%s\n' 'Missing value for --voice.' >&2; exit 2; }
			voice=$2
			shift 2
			;;
		-r | --rate)
			(($# >= 2)) || { printf '%s\n' 'Missing value for --rate.' >&2; exit 2; }
			rate=$2
			shift 2
			;;
		--force)
			force=true
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		--)
			shift
			text_parts+=("$@")
			break
			;;
		-*)
			printf 'Unknown option: %s\n' "$1" >&2
			usage >&2
			exit 2
			;;
		*)
			text_parts+=("$1")
			shift
			;;
	esac
done

if [[ -z "$output" ]]; then
	printf '%s\n' 'Missing required --output path.' >&2
	usage >&2
	exit 2
fi

case "$output" in
	*.wav | *.WAV) ;;
	*)
		printf '%s\n' 'Output path must end in .wav.' >&2
		exit 2
		;;
esac

if [[ -n "$input_file" && ${#text_parts[@]} -gt 0 ]]; then
	printf '%s\n' 'Use either --input-file or text arguments, not both.' >&2
	exit 2
fi

if [[ -n "$input_file" && ! -f "$input_file" ]]; then
	printf 'Input file does not exist: %s\n' "$input_file" >&2
	exit 2
fi

output_dir=$(dirname "$output")
output_name=$(basename "$output")
mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd -P)
output="$output_dir/$output_name"

if [[ -e "$output" && "$force" != true ]]; then
	printf 'Output file already exists: %s\n' "$output" >&2
	printf '%s\n' 'Pass --force to replace it.' >&2
	exit 2
fi

temp_output=$(mktemp "$output_dir/.tts-output.XXXXXX")
temp_input=''

cleanup() {
	rm -f "$temp_output"
	if [[ -n "$temp_input" ]]; then
		rm -f "$temp_input"
	fi
}
trap cleanup EXIT

say_args=(
	--output-file="$temp_output"
	--file-format=WAVE
	--data-format=LEI16@24000
)

if [[ -n "$voice" ]]; then
	say_args+=(--voice="$voice")
fi

if [[ -n "$rate" ]]; then
	say_args+=(--rate="$rate")
fi

if [[ -n "$input_file" ]]; then
	[[ -s "$input_file" ]] || { printf '%s\n' 'Input file is empty.' >&2; exit 2; }
	say_args+=(--input-file="$input_file")
elif ((${#text_parts[@]} > 0)); then
	text="${text_parts[*]}"
	[[ -n "$text" ]] || { printf '%s\n' 'Text is empty.' >&2; exit 2; }
	say_args+=("$text")
else
	temp_input=$(mktemp "${TMPDIR:-/tmp}/tts-input.XXXXXX")
	command cat >"$temp_input"
	[[ -s "$temp_input" ]] || { printf '%s\n' 'Text is empty.' >&2; exit 2; }
	say_args+=(--input-file="$temp_input")
fi

/usr/bin/say "${say_args[@]}"

if [[ ! -s "$temp_output" ]] || ! /usr/bin/afinfo "$temp_output" >/dev/null 2>&1; then
	printf '%s\n' 'Speech synthesis did not produce a valid audio file.' >&2
	exit 1
fi

mv -f "$temp_output" "$output"
printf '%s\n' "$output"

