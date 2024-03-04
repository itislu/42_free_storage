#!/bin/bash

current_dir=$(pwd -P)
sgoinfre_root="/sgoinfre/goinfre/Perso/$USER"
sgoinfre_alt="/nfs/sgoinfre/goinfre/Perso/$USER"
sgoinfre="$sgoinfre_root"
sgoinfre_permissions=$(stat -c "%A" "$sgoinfre")

# Exit codes
success=0
no_args=12
user_abort=1
unknown_option=2
permission_reminder=3
invalid_path=4
not_exist=5
already_freed=6
symbolic_link=7
conflict=8
no_space_left=9
mv_error=10
restore_error=11

exit_code=$success

# Colors and styles
sty_res="\e[0m"
sty_bol="\e[1m"
sty_und="\e[4m"
sty_red="\e[31m"
sty_bri_red="\e[91m"
sty_bri_gre="\e[92m"
sty_bri_yel="\e[93m"
sty_bri_blu="\e[94m"
sty_bri_cya="\e[96m"

header="\
               ${sty_bol}${sty_bri_yel}📁  42free  📁${sty_res}"
tagline="\
           ${sty_bol}${sty_bri_yel}Never run \`ncdu\` again${sty_res}"
delim_small="\
      --------------------------------"
delim_big="\
    ${sty_und}                                    ${sty_res}"

print_error="${sty_bol}${sty_bri_red}ERROR:${sty_res}"
print_warning="${sty_bol}${sty_bri_yel}WARNING:${sty_res}"
print_success="${sty_bol}${sty_bri_gre}SUCCESS:${sty_res}"

msg_manual="\
$header
$tagline
$delim_big

The files get moved from '$HOME' to '$sgoinfre'.

A symbolic link is left behind in the original location.
You only need to run 42free once for every directory or file you want to free the space of.
All programs will then access them through the symlink and they will accumulate their space outside of your home directory.

$delim_small

${sty_und}Usage:${sty_res} ${sty_bol}42free target1 [target2 ...]${sty_res}
    The target paths can be absolute or relative to your current directory.
    42free will automatically detect if an argument is the source or the destination.

${sty_und}Options:${sty_res} You can pass options anywhere in the arguments.
    -r, --reverse  Reverse the operation and move the directories or files
                   back to their original location in home.
    -s, --suggest  Display some suggestions to move and exit.
    -h, --help     Display this help message and exit.
    -v, --version  Display version information and exit.
    --             Stop interpreting options.

${sty_und}Exit codes:${sty_res}
    0: Success
    1: User aborted
    2: Unknown option

$delim_small

To contribute, report bugs or share improvement ideas, visit ${sty_und}${sty_bri_blu}https://github.com/itislu/42free${sty_res}.

"

msg_suggest="\
${sty_bol}Some suggestions to move:${sty_res}
   ~/.cache
   ~/.local/share/Trash
   ~/.var/app/*/cache"

msg_version="\
${sty_bol}42free v1.0.0${sty_res}
A script made for 42 students to move directories or files to free up storage.
For more information, visit ${sty_und}${sty_bri_blu}https://github.com/itislu/42free${sty_res}."

msg_sgoinfre_permissions="\
$print_warning The permissions of your personal sgoinfre directory are not set to '${sty_bol}rwx------${sty_res}'.
They are currently set to '${sty_bol}$sgoinfre_permissions${sty_res}'.
It is ${sty_bol}highly${sty_res} recommended to change the permissions so that other students cannot access the files you will move to sgoinfre."

msg_sgoinfre_permissions_keep="Keeping the permissions of '$sgoinfre' as '$sgoinfre_permissions'."

prompt_continue="Do you still wish to continue? (${sty_bol}y${sty_res}/${sty_bol}n${sty_res})"
prompt_continue_with_rest="Do you wish to continue with the other arguments? (${sty_bol}y${sty_res}/${sty_bol}n${sty_res})"
prompt_change_permissions="Do you wish to change the permissions of '$sgoinfre' to '${sty_bol}rwx------${sty_res}'? (${sty_bol}y${sty_res}/${sty_bol}n${sty_res})"
prompt_replace="Do you wish to replace it? (${sty_bol}y${sty_res}/${sty_bol}n${sty_res})"

# Automatically detects the size of the terminal window and preserves word boundaries at the edges
pretty_print()
{
    printf "%b" "$1" | fmt -sw $(tput cols)
}

# Prompt the user for confirmation
prompt_user()
{
    pretty_print "$1"
    read -rp "> "
    if [[ ! $REPLY =~ ^[Yy](es)?$ ]]; then
        return 1
    fi
    return 0
}

print_skip_arg()
{
    pretty_print "Skipping '$1'."
}

restore_after_mv_error()
{
    local source_path=$1
    local target_base=$2
    local stderr

    if ! mv -f "$source_path" "$target_base" 2>/dev/null; then
        # If mv fails, fall back to cp and rm
        if stderr=$(cp -RPf --preserve=all "$source_path" "$target_base" 2>&1); then
            # If cp is successful, try to remove the source
            stderr=$(rm -rf "$source_path" 2>&1)
        fi
    fi
    echo "$stderr"
}

# Check if the script received any targets
if [ $# -eq 0 ]; then
    pretty_print "$msg_manual"
    exit $no_args
fi

# Process options
args=()
args_amount=0
reverse=false
while (( $# )); do
    case "$1" in
        -r|--reverse)
            reverse=true
            ;;
        -s|--suggest)
            # Print some suggestions
            pretty_print "$msg_suggest"
            exit $success
            ;;
        -h|--help)
            # Print help message
            pretty_print "$msg_manual"
            exit $success
            ;;
        -v|--version)
            # Print version information
            pretty_print "$msg_version"
            exit $success
            ;;
        --)
            # End of options
            shift
            while (( $# )); do
                args+=("$1")
                args_amount=$((args_amount + 1))
                shift
            done
            break
            ;;
        -*)
            # Unknown option
            pretty_print "Unknown option: '$1'"
            exit $unknown_option
            ;;
        *)
            # Non-option argument
            args+=("$1")
            args_amount=$((args_amount + 1))
            ;;
    esac
    shift
done

# Set positional parameters to non-option arguments
#set -- "${args[@]}"

# Check if the permissions of user's sgoinfre directory are rwx------
if ! $reverse && [ "$sgoinfre_permissions" != "drwx------" ]; then
    pretty_print "$msg_sgoinfre_permissions"
    if prompt_user "$prompt_change_permissions"; then
        if chmod 700 "$sgoinfre"; then
            pretty_print "$print_success The permissions of '$sgoinfre' have been changed to '${sty_bol}rwx------${sty_res}'."
        else
            pretty_print "$print_error Failed to change the permissions of '$sgoinfre'."
            if ! prompt_user "$prompt_continue"; then
                exit $user_abort
            fi
            exit_code=$permission_reminder
            pretty_print "$msg_sgoinfre_permissions_keep"
        fi
    else
        pretty_print "$msg_sgoinfre_permissions_keep"
    fi
fi

# Check which direction the script should move the directories or files
if ! $reverse; then
    source_base="$HOME"
    target_base="$sgoinfre"
    target_name="sgoinfre"
    max_size=30
    operation="moved"
    outcome="freed"
else
    source_base="$sgoinfre"
    target_base="$HOME"
    target_name="home"
    max_size=5
    operation="moved back"
    outcome="reclaimed"
fi

# Print header
pretty_print "$header"
pretty_print "$delim_big"
echo

# Loop over all arguments
args_index=0
for arg in "${args[@]}"; do
    args_index=$((args_index + 1))

    # Print a delimiter if not the first iteration
    if [ -n "$arg_path" ]; then
        pretty_print "$delim_small"
    fi

    # Check if argument is an absolute or relative path
    if [[ "$arg" = /* ]]; then
        arg_path="$arg"
        invalid_path_msg="$print_error Absolute paths have to lead to a path in your ${sty_bol}home${sty_res} or ${sty_bol}sgoinfre${sty_res} directory."
    else
        arg_path="$current_dir/$arg"
        invalid_path_msg="$print_error The current directory is not in your ${sty_bol}home${sty_res} or ${sty_bol}sgoinfre${sty_res} directory."
    fi

    # Make sure all mount points of sgoinfre work
    if [[ "$arg_path" = $sgoinfre_alt/* ]]; then
        sgoinfre="$sgoinfre_alt"
    else
        sgoinfre="$sgoinfre_root"
    fi

    # Update variables with updated sgoinfre path
    if ! $reverse; then
        target_base="$sgoinfre"
    else
        source_base="$sgoinfre"
    fi

    # Construct the source and target paths
    if [[ "$arg_path" = $source_base/* ]]; then
        source_path="$arg_path"
        source_subpath="${source_path#"$source_base/"}"
        target_path="$target_base/$source_subpath"
        target_subpath="${target_path#"$target_base/"}"
    elif [[ "$arg_path" = $target_base/* ]]; then
        target_path="$arg_path"
        target_subpath="${target_path#"$target_base/"}"
        source_path="$source_base/$target_subpath"
        source_subpath="${source_path#"$source_base/"}"
    else
        # If the result is neither in the source nor target base directory, skip the argument
        pretty_print "$invalid_path_msg"
        print_skip_arg "$arg"
        exit_code=$invalid_path
        continue
    fi

    # Construct useful variables from the paths
    source_dirpath=$(dirname "$source_path")
    source_basename=$(basename "$source_path")
    target_dirpath=$(dirname "$target_path")
    target_basename=$(basename "$target_path")

    # Check if the source directory or file exists
    if [ ! -e "$source_path" ]; then
        pretty_print "$print_error '${sty_bri_red}$source_path${sty_res}' does not exist."
        exit_code=$not_exist
        continue
    fi

    # Check if the source file is a symbolic link
    if [ -L "$source_path" ]; then
        # If the source directory or file has already been moved to sgoinfre, skip it
        if ! $reverse && [[ "$(readlink "$source_path")" =~ ^($sgoinfre_root|$sgoinfre_alt)/ ]]; then
            pretty_print "'${sty_bol}${sty_bri_cya}$source_basename${sty_res}' has already been moved to sgoinfre."
            pretty_print "It is located at '$(readlink "$source_path")'."
            print_skip_arg "$arg"
            exit_code=$already_freed
            continue
        fi
        pretty_print "$print_warning '${sty_bol}${sty_bri_cya}$source_basename${sty_res}' is a symbolic link."
        if ! prompt_user "$prompt_continue"; then
            print_skip_arg "$arg"
            exit_code=$symbolic_link
            continue
        fi
    fi

    # When moving files back to home, first remove the symbolic link
    if $reverse && [ -L "$target_path" ]; then
        rm "$target_path"
    # Check if an existing directory or file would get replaced
    elif [ -e "$target_path" ]; then
        pretty_print "$print_warning '${sty_bol}$source_subpath${sty_res}' already exists in the $target_name directory."
        if ! prompt_user "$prompt_replace"; then
            print_skip_arg "$arg"
            exit_code=$conflict
            continue
        fi
    fi

    # Get the current size of the target directory
    if [ -z "$target_dir_size_in_bytes" ]; then
        pretty_print "Getting the current size of the $target_name directory..."
        target_dir_size_in_bytes=$(du -sb "$target_base" 2>/dev/null | cut -f1)
    fi

    # Get the size of the directory or file to be moved
    size="$(du -sh "$source_path" 2>/dev/null | cut -f1)B"
    size_in_bytes=$(du -sb "$source_path" 2>/dev/null | cut -f1)

    # Get the size of any target that will be replaced
    existing_target_size_in_bytes="$(du -sb "$target_path" 2>/dev/null | cut -f1)"

    # Convert max_size from GB to bytes
    max_size_in_bytes=$((max_size * 1024 * 1024 * 1024))

    # Check if the target directory would go above its maximum recommended size
    if (( target_dir_size_in_bytes + size_in_bytes - existing_target_size_in_bytes > max_size_in_bytes )); then
        pretty_print "$print_warning This operation would cause the ${sty_bol}$target_name${sty_res} directory to go above ${sty_bol}${max_size}GB${sty_res}."
        if ! prompt_user "$prompt_continue"; then
            print_skip_arg "$arg"
            if [ $exit_code -eq $success ]; then
                exit_code=$no_space_left
            fi
            continue
        fi
    fi

    pretty_print "Moving '${sty_bol}$source_subpath${sty_res}' to ${sty_bol}$target_name${sty_res}..."

    # Temporarily move any existing directory or file to a backup location
    target_backup="$target_path~42free_backup_existing_files~"  #TODO Make sure to get unique backup name
    mv -n "$target_path" "$target_backup" 2>/dev/null

    # Create the parent directories for the target path
    mkdir -p "$(dirname "$target_path")"

    # Move the directory or file
    if ! stderr=$(mv -f "$source_path" "$target_base" 2>&1); then
        pretty_print "$print_error Could not fully move '${sty_bol}$source_basename${sty_res}' to '${sty_bol}$target_dirpath${sty_res}'."
        pretty_print "$stderr."
        exit_code=$mv_error

        if ! $reverse; then
            pretty_print "Try to close all programs and try again."
            # Move everything back
            if ! stderr=$(restore_after_mv_error "$target_path" "$source_base"); then
                pretty_print "$print_error Could not fully restore '${sty_bol}$target_basename${sty_res}' to '${sty_bol}$source_dirpath${sty_res}'."
                pretty_print "$stderr."
                pretty_print "Try to move it manually."
                exit_code=$restore_error
            else
                pretty_print "'${sty_bol}$target_basename${sty_res}' fully restored to '${sty_bol}$source_dirpath${sty_res}'."
                mv -n "$target_backup" "$target_path" 2>/dev/null
        else
            pretty_print "Try to move the rest manually."
        fi

        # If not last argument, ask user if they want to continue with the other arguments
        if [ args_index -lt args_amount ]; then
            if ! prompt_user "$prompt_continue_with_rest"; then
                # TODO Improve msgs to user
                exit $user_abort
            fi
        fi

        # Force recalculation of the target directory size in next iteration
        unset target_dir_size_in_bytes
        continue
    fi

    pretty_print "$print_success '${sty_bri_yel}$source_basename${sty_res}' successfully $operation to '${sty_bri_gre}$target_dirpath${sty_res}'."

    # If reverse flag is not active, leave a symbolic link behind
    if ! $reverse; then
        ln -s "$target_path" "$source_path"
        pretty_print "Symbolic link left behind."
    else
      # If reverse flag is active, delete empty parent directories
        first_dir_after_base="$source_base/${arg%%/*}"
        find "$first_dir_after_base" -type d -empty -delete 2>/dev/null
        if [ -d "$first_dir_after_base" ] && [ -z "$(ls -A "$first_dir_after_base")" ]; then
            rmdir "$first_dir_after_base"
        fi
    fi

    # Remove any backups
    rm -rf "$target_backup" 2>/dev/null

    # Update the size of the target directory
    target_dir_size_in_bytes=$((target_dir_size_in_bytes + size_in_bytes - existing_target_size_in_bytes))

    # Print result
    pretty_print "${sty_bol}$size${sty_res} $outcome."
done

exit $exit_code
