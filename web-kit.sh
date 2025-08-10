#!/usr/bin/env bash
set -euo pipefail

# ./html_server.sh - Armbian Config V2 module

html_server() {
	case "${1:-}" in
		help|-h|--help)
			_about_html_server
			;;
		index)
			# Generate an HTML index of SVG files
			_html_server_index
			[[ "${2:-}" == "serve" ]] && _html_server_main
			;;
		icon)
			# Generate a set of icons from SVG files
			_icon_set_from_svg
			;;
		server)
			# Start a simple HTTP server using Python
			_html_server_main "${2:-.}"
			;;
		*)
			_about_html_server
			;;
	esac
}

_html_server_main() {
	# Use a default directory
	local DIR="${1:-.}"
	# Run Python web server for HTTP (CGI dropped for now)
	echo "Starting Python web server"
	python3 -m http.server 8080 &

	PYTHON_PID=$!

	echo "Python web server started with PID $PYTHON_PID"
	echo "You can access the server at http://localhost:8080/$DIR"
	echo "Press any key to stop the server..."
	read -r -n 1 -s
	echo "Stopping the server..."
	if ! kill -0 "$PYTHON_PID" 2>/dev/null; then
		echo "Server is not running or already stopped."
		exit 0
	fi
	kill "$PYTHON_PID" && wait "$PYTHON_PID" 2>/dev/null
	if [[ $? -eq 0 ]]; then
		echo "Server stopped successfully."
	else
		echo "Failed to stop the server."
		exit 1
	fi
	echo "Test complete"
}

_html_server_index() {
	# Directory containing SVGs
	SVG_DIR="./images/scalable"
	# Output HTML file
	OUTPUT="./index.html"

	{
	echo "<!DOCTYPE html>"
	echo "<html><head><meta charset='UTF-8'><title>Armbian logos</title></head><body>"
	echo "<img src=\"$SVG_DIR/armbian-tux_v1.5.svg\" alt=\"armbian-tux_v1.5.svg\" width=\"128\" height=\"128\">"
	echo "<img src=\"$SVG_DIR/armbian_logo_v2.svg\" alt=\"armbian_logo_v2.svg\" width=\"512\" height=\"128\">"
	echo "<h1>Armbian Logos and Icons</h1>"

	cat <<EOF
	<p>We've put together some logos and icons for you to use in your articles and projects.</p>
EOF

	local SIZES=(16 32 64 128 256 512)
	for file in "$SVG_DIR"/*.svg; do
		[[ -e "$file" ]] || continue
		name=$(basename "$file" .svg)
		echo "<hr>"
		echo "<a href=\"$file\">"
		echo "  <img src=\"$file\" alt=\"$name.svg\" width=\"64\" height=\"64\">"
		echo "</a>"
		echo "<p>Download PNG:</p><ul>"
		for sz in "${SIZES[@]}"; do
		#share/icons/hicolor/
			echo "  <li><a href=\"share/icons/hicolor/${sz}x${sz}/${name}.png\">${sz}x${sz} ${name}.png</a></li>"
		done
		echo "</ul>"
	done

cat <<EOF
	<p>All logos are licensed under the <a href="https://creativecommons.org/licenses/by-sa/4.0/">CC BY-SA 4.0</a> license.</p>
	<p>For more information, please refer to the <a href="https://www.armbian.com/brand/">Armbian Brand Guidelines</a>.</p>
</body></html>
EOF
	} > "$OUTPUT"

	echo "HTML file created: $OUTPUT"
}

_icon_set_from_svg() {

# Directory containing SVGs
SRC_DIR="images/scalable"
# List of desired sizes
SIZES=(16 32 64 128 256 512)

# Check for ImageMagick's convert command
if ! command -v convert &> /dev/null; then
	echo "Error: ImageMagick 'convert' command not found."
	read -p "Would you like to install ImageMagick using 'sudo apt install imagemagick'? [Y/n] " yn
	case "$yn" in
		[Yy]* | "" )
		echo "Installing ImageMagick..."
		sudo apt update && sudo apt install imagemagick
		if ! command -v convert &> /dev/null; then
			echo "Installation failed or 'convert' still not found. Exiting."
			exit 1
		fi
		;;
		* )
		echo "Cannot proceed without ImageMagick. Exiting."
		exit 1
	;;
	esac
fi

# Check if source directory exists
if [ ! -d "$SRC_DIR" ]; then
	echo "Error: Source directory '$SRC_DIR' does not exist."
	exit 1
fi

# Check if SVGs exist in the source directory
shopt -s nullglob
svg_files=("$SRC_DIR"/*.svg)
if [ ${#svg_files[@]} -eq 0 ]; then
	echo "Error: No SVG files found in '$SRC_DIR'."
	exit 1
fi
shopt -u nullglob

# Loop over each SVG file in the scalable directory
for svg in "${svg_files[@]}"; do
	# Extract the base filename without extension
	base=$(basename "$svg" .svg)
	# For each size, generate the PNG in the corresponding directory
	for size in "${SIZES[@]}"; do
		OUT_DIR="icons/${size}x${size}"
		mkdir -p "$OUT_DIR"
		OUT_FILE="${OUT_DIR}/${base}.png"
		# Only generate if missing or source SVG is newer
		if [[ ! -f "$OUT_FILE" || "$svg" -nt "$OUT_FILE" ]]; then
			convert -background none -resize ${size}x${size} "$svg" "$OUT_FILE"
		if [ $? -eq 0 ]; then
			echo "Generated $OUT_FILE"
		else
			echo "Failed to convert $svg to $OUT_FILE"
		fi
	fi
	done
done

}
_about_html_server() {
	cat <<EOF
Usage: html_server <command> [options]

Commands:

    help   - Show this help message
    icon   - 
    index  -
    server -
     

Examples:
	# Show help
	web-kit help


Notes:
	- All commands should accept '--help', '-h', or 'help' for details, if implemented.
	- Intended for use with the config-v2 menu and scripting.
	- Keep this help message up to date if commands change.

EOF
}

### START ./html_server.sh - Armbian Config V2 test entrypoint

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	# --- Capture and assert help output ---
	help_output="$(html_server help)"
	echo "$help_output" | grep -q "Usage: html_server" || {
		echo "fail: Help output does not contain expected usage string"
		echo "test complete"
		exit 1
	}
	# --- end assertion ---
	html_server "$@"
fi

### END ./html_server.sh - Armbian Config V2 test entrypoint
