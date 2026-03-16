#!/usr/bin/env sh

# --- Safety ---
set -eu

# --- Configuration ---
GRUB_CONFIG="/etc/default/grub"
DOTFILE_DIR="$HOME/.config/many-grub"
SHARED_DIR="$HOME/.local/share/many-grub"
GRUB_BACKUP_DIR="$SHARED_DIR/backup"
INSTALLED_THEME_DIR="$SHARED_DIR/themes"

if [ -f "/boot/grub/grub.cfg" ]; then
    GRUB_MKCFG_TARGET="/boot/grub/grub.cfg"
elif [ -f "/boot/grub2/grub.cfg" ]; then
    GRUB_MKCFG_TARGET="/boot/grub2/grub.cfg"
else
    echo "[-] Could not detect grub.cfg location"
    exit 1
fi

# --- Core Utils ---
setup_dirs() {
    mkdir -p "$DOTFILE_DIR" "$SHARED_DIR" "$GRUB_BACKUP_DIR" "$INSTALLED_THEME_DIR"
}

print_sucess() { printf "[+] %s\n" "$1"; }
print_info() { printf "[*] %s\n" "$1"; }
print_err()    { printf "[-] %s\n" "$1" >&2; }
error_exit()   { print_err "$1"; exit 1; }

backup_grub() {
    timestamp=$(date +%Y%m%d_%H%M%S)
    cp "$GRUB_CONFIG" "$GRUB_BACKUP_DIR/grub.bak_$timestamp" \
        || error_exit "Failed to backup GRUB config."
}

get_last_backup() {
    last=""
    for item in "$GRUB_BACKUP_DIR"/grub.bak_*; do
        [ -f "$item" ] || continue
        if [ -z "$last" ] || [ "$item" -nt "$last" ]; then
            last="$item"
        fi
    done
    echo "$last"
}

set_grub_line() {
    key="$1"
    value="$2"
    # Support for commented out line (#GRUB_THEME)
    if grep -q "^#\?$key=" "$GRUB_CONFIG"; then
        sudo sed -i "s|^#\?$key=.*|$key=\"$value\"|" "$GRUB_CONFIG"
    else
        echo "$key=\"$value\"" | sudo tee -a "$GRUB_CONFIG" > /dev/null
    fi
}

apply_grub_changes() {
    print_info "Updating GRUB configuration..."
    sudo grub-mkconfig -o "$GRUB_MKCFG_TARGET" || error_exit "grub-mkconfig failed."
}

# --- Logic ---
add_theme() {
    src_dir="${1%/}"
    [ -d "$src_dir" ] || error_exit "Source directory does not exist: $src_dir"
    [ -f "$src_dir/theme.txt" ] || error_exit "theme.txt not found in $src_dir"

    src_name="$(basename "$src_dir")"
    target="$INSTALLED_THEME_DIR/$src_name"

    [ -d "$target" ] && error_exit "Theme already installed: $src_name"

    print_sucess "Adding theme: $src_name"

    cp -r "$src_dir" "$INSTALLED_THEME_DIR/"

    print_info "Theme installed to: $INSTALLED_THEME_DIR/$src_name"
}

set_theme() {
    theme="$1"
    [ -z "$theme" ] && error_exit "Usage: set [THEME_NAME]"
    
    theme_path="$INSTALLED_THEME_DIR/$theme/theme.txt"
    [ -f "$theme_path" ] || error_exit "Theme '$theme' not installed."

    set_grub_line "GRUB_THEME" "$theme_path"
    print_sucess "Theme set to: $theme"
}

is_url() {
    case "$1" in
        http://*|https://*)
            return 0
        ;;
        *)
            return 1
        ;;
    esac
}

download_theme() {
    url="$1"
    tmp="$(mktemp -d)"

    print_sucess "Downloading theme..."

    if command -v curl >/dev/null 2>&1; then
        curl -L "$url" -o "$tmp/theme.zip"
    elif command -v wget >/dev/null 2>&1; then
        wget "$url" -O "$tmp/theme.zip"
    else
        error_exit "Need curl or wget to download themes"
    fi

    unzip "$tmp/theme.zip" -d "$tmp"
    echo "$tmp"
}

download_git_like_theme() {
    url="$1"
    name="$(basename "$url")"
    tmp="$(mktemp -d)"
    tmp_repo=$tmp/$name
    print_info "Cloning $url into $tmp_repo"
    git clone "$url" "$tmp_repo" || error_exit "git clone failed, is this a valid git like url"
    print_sucess "Successfully cloned url into \"$tmp_repo\""
    echo "$tmp_repo"
}

detect_theme_dir() {
    found_paths=$(find "$1" -maxdepth 5 -type f -name "theme.txt" -exec dirname {} \;)

    if [ -z "$found_paths" ]; then
        error_exit "No theme.txt found in $1"
    fi

    printf "%s\n" "$found_paths"
}

# --- Commands ---
cmd_current() {
    grep "^#\?GRUB_THEME=" "$GRUB_CONFIG" | cut -d'"' -f2
}

cmd_install() {
    add_theme "$1" || exit 1
    theme_name="$(basename "${1%/}")"
    cmd_set "$theme_name"
}

cmd_git_add() {
    repo="$(download_git_like_theme "$1" | tail -n 1)"
    themes_found="$(detect_theme_dir "$repo")"
    tmp="$(mktemp -d)"
    printf "%s\n" "$themes_found" | while IFS= read -r item; do
        print_info "Detected : $item"

        clean_item="$(echo "$item" | sed "s|^/tmp/tmp.[^/]*/||")"
        final_item="$(echo "$clean_item" | tr "/"  "-")"

        mv "$item" "$tmp/$final_item"

        cmd_add "$tmp/$final_item"
    done
}

cmd_random() {
    theme=$(ls "$INSTALLED_THEME_DIR" | shuf -n 1)
    print_info "Feeling lucky... selected: $theme"
    cmd_set "$theme"
}

cmd_add() {
    add_theme "$1"
}

cmd_set() {
    backup_grub
    set_theme "$1"
    apply_grub_changes
}

cmd_restore() {
    last="$(get_last_backup)"
    [ -z "$last" ] && error_exit "No backup found."
    
    sudo cp "$last" "$GRUB_CONFIG"
    apply_grub_changes
    print_sucess "Restored: $(basename "$last")"
}

cmd_list() {
    printf "Installed themes:\n"
    for dir in "$INSTALLED_THEME_DIR"/*; do
        [ -d "$dir" ] || continue
        printf "  • %s\n" "$(basename "$dir")"
    done


}

cmd_backups() {
    printf "Backup list:\n"
    for file in "$GRUB_BACKUP_DIR"/grub.bak_*; do
        [ -f "$file" ] || continue
        printf "  • %s\n" "$(basename "$file")"
    done
}

cmd_custom() {
    file="$1"
    [ -f "$file" ] || error_exit "Custom file '$file' not found."

    backup_grub
    set_grub_line "GRUB_THEME" "$file"
    apply_grub_changes

    print_sucess "Done! GRUB_THEME set to: $file"
}

cmd_preview() {
    theme="$1"
    theme_dir="$INSTALLED_THEME_DIR/$theme"

    [ -d "$theme_dir" ] || error_exit "Theme '$theme' not installed."

    preview_path=""

    for name in preview screenshot screenshots background; do
        for ext in png jpg jpeg; do
            path="$theme_dir/$name.$ext"
            if [ -f "$path" ]; then
                preview_path="$path"
                break 2
            fi
        done
    done

    if [ -z "$preview_path" ]; then
        preview_path="$(find "$theme_dir" -type f \( -iname "*preview*" -o -iname "*screenshot*" \) | head -n 1)"
    fi
    
    [ -z "$preview_path" ] && error_exit "No preview available for '$theme'"

    print_sucess "Opening preview: $(basename "$preview_path")"
    xdg-open "$preview_path"
}

# --- Infrastructure ---
print_help() {
    cat << EOF
many-grub: A GRUB theming utility

Usage: many-grub [COMMAND] [ARG...]

Commands:
    add [DIR]       Add a theme to the local store
    git-add [URL]   Add a theme from a git compatible remote
    install [DIR]   Add, set, and apply a theme
    set [NAME]      Apply an already added theme
    list            Show installed themes
    custom [FILE]   Set a custom path to \`theme.txt\`
    current         Show the path of the current theme
    backups         Show available config backups
    restore         Restore the most recent backup
    random          Set a random theme
    help            Show this message
EOF
}

dispatch() {
    raw_cmd="$1"
    clean_cmd=$(echo "$raw_cmd" | tr '-' '_')
    
    shift

    func="cmd_$clean_cmd"

    if command -v "$func" >/dev/null 2>&1; then
        "$func" "$@"
    else
        print_err "Unknown command: $raw_cmd (tried $func)"
        exit 1
    fi
}

main() {
    setup_dirs
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        print_help
        exit 0
    fi
    dispatch "$@"
}

main "$@"