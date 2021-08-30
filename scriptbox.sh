#!/bin/sh

#_sb_### Function list ###_sb_#
scriptlist=""

#_sb_### Start: scriptbox ###_sb_#
scriptbox(){
	local shebang='#!/bin/sh'
	local usagetext='USAGE: scriptbox [scriptname [arguments]...]
   or: scriptbox install   [symlink]       <dir>
   or: scriptbox add       <path/to/script>
   or: scriptbox pack      <path/to/script>  [path/to/other/script]...
   or: scriptbox remove    <script name>
   or: scriptbox replace   <script name>     <path/to/script>
   or: scriptbox unpack    <dir>
   or: scriptbox pop       <script name>
   or: scriptbox wrap      <path/to/script>
   or: scriptbox base
   or: scriptbox list
   or: scriptbox usage
   or: scriptbox examples
   or: scriptbox version
   or: scriptbox help'

	local helptext='scriptbox (inspired by BusyBox) is a script that encapsulates other
scripts for portability. It contains the logic required to add and remove scripts
(see "add", "remove", "replace" and "pack" commands), produce a slim version of itself,
containing no other scripts ("base" command), produce links to each of its scripts ("install"),
and spit out standalone versions of the scripts it contains ("pop" and "unpack").'

	local examples='EXAMPLES
  scriptbox add <path/to/script.sh>
	  add a script to the box

  scriptbox pack myscripts/*
	  add all of the scripts in the "myscripts" directory

  find myscripts/ -type f -name "*.sh" -not -name "_*" | scriptbox.sh pack
	  add all of the scripts under the "myscripts" directory, excluding ones that start
	  with an underscore:

  scriptbox install --symlink /usr/local/bin
	  create a named symlink in /usr/local/bin for each script in the scriptbox'

	local version="scriptbox version 1.8"
	local tmpfile=/tmp/scriptbox
	
	sb_help(){
		local list="$(sb_list_compact)"
		if [ -n "$list" ]; then
			printf "%s\n\n%s\n\n%s\n\n%s\n\n%s\n" "$version" "$helptext" "$usagetext" "$examples" "$(sb_list_compact)"
		else
			printf "%s\n\n%s\n\n%s\n\n%s\n" "$version" "$helptext" "$usagetext" "$examples"
		fi
		exit 0
	}

	# sb_list prints the currently defined scripts in alphabetical order, one per line
	sb_list(){
		printf "%s" "$scriptlist" | tr " " "\n" | sort
	}

	# sb_list_compact prints a nicely formatted list of the currently defined functions
	sb_list_compact(){
		local list=$(sb_list | tr "\n" " " | \
		sed 's/ /, /g ; s/, $//g' | \
		fold -sw 70 | sed 's/^/	/g')
		[ -n "$list" ] && printf "%s\n%s\n" "CURRENTLY DEFINED SCRIPTS" "$list"
	}

	# sb_die prints a message to stderr and exits with error code 1
	sb_die(){ printf "%s\n" "$1" 1>&2; exit 1; }

	# sb_exit prints a message and exits with error code 0
	sb_exit(){ printf "%s\n" "$1"; exit 0; }
	
	# sb_linenum returns the line number at which the script ($2) starts or ends ($1)
	sb_linenum(){
		case "$1" in
			"start") local pattern="#_sb_### Start: $2" ;;
			"end") local pattern="#_sb_### End: $2" ;;
			"") local pattern="$2" ;;
			*) sb_die "Could not find line number of pattern: $2, invalid prefix: $1"
		esac
		grep -Fn -m 1 "$pattern" $boxpath | cut -d ':' -f 1
	}

	# sb_contains returns whether or not the box contains the function
	# with name equal to $1
	sb_contains(){
		printf "%s" "$1" | grep -Fq '-' && return 1
		printf "%s" "$scriptlist" | grep -Fqw "$1"
	}

	# sb_base prints from the start of the scriptbox function to
	# the end of the file, it also prints the leading comment.
	sb_base(){
		tail -n +"$(sb_linenum "start" "scriptbox")" "$boxpath"
	}

	# sb_print_head prints the head of the scriptbox file, it expects
	# a string containing functions to include as $1
	sb_print_head(){
		printf "%s\n\n%s\n%s\n\n" \
				"$shebang" "#_sb_### Function list ###_sb_#" \
				"scriptlist=\"$1\""
	}

	# sb_print_headless prints the contents of the scriptbox file (minus the head)
	# if $2 is provided, it reads from $2 instead of the current box file
	sb_print_headless(){
		local boxbodystart="$(sb_linenum "start")"
		if [ -n "$1" ]; then
			printf "%s" "$1" | tail -n+$boxbodystart
		else
			tail -n+$boxbodystart $boxpath
		fi
	}

	# sb_pop prints the selected function as a standalone script
	# it expects $1 to be the name of a function
	sb_pop(){
		sb_contains "$1" || sb_die "No matching script ($1)"
		local funcstart=$(sb_linenum "start" "$1" + 2)
		local funcend=$(sb_linenum "end" "$1")
		local funcstart=$(($funcstart + 2))
		local funcend=$(($funcend - 2))
		local func=$(head -n"$funcend" $boxpath| tail -n+"$funcstart" | sed 's/^	//g')
		printf "%s\n\n%s\n" "$shebang" "$func"
	}

	# sb_install creates a link to itself for each of its functions (scripts) in the
	# target directory. Each link is named after a function/script.
	sb_install(){
		case "$1" in
			"s"|"symlink"|"-s"|"--symlink")
				local installdir="$2"
				local linkopts="-sv" ;;
			*)
				local installdir="$1"
				local linkopts="-v" ;;
		esac

		if [ ! -r "$installdir" -o ! -d "$(realpath $installdir 2>/dev/null)" ]; then
			sb_die "You must provide a path to install to (and it must be readable)"
		fi
		for i in $scriptlist; do
			ln $linkopts "$boxpath" "$(realpath $installdir)/$i"
		done
	}

	# sb_wrap prepares a script for inclusion in the box, by stripping shebang
	# and encapsulating the body in a function. It expects a function name to assign
	# to it as $1 and the path to the script as $2
	sb_wrap(){
		[ -n "$1" -a -n "$2" ] && local name="$1" \
							   || sb_die "You must provide a name and the path to the script"

		[ -r "$2" ] || sb_die "Invalid script ($2), does it exist and is it readable?"

		local indentedbody="$(tail -n +2 $2 | sed 's/^/	/g')"

		printf "%s\n%s\n%s\n%s\n%s\n" \
				"#_sb_### Start: $name ###_sb_#" \
				"$name(){" "$indentedbody" "}" \
				"#_sb_### End: $name ###_sb_#"
	}

	# sb_validate takes a file name as input and validates it for inclusion in the box
	sb_validate(){
		[ -r "$1" ] || sb_die "Error: could not find/read script ($1)."
		local lineone="$(head -n1 $1 | xargs)"
		[ "$lineone" = "$shebang" ] || sb_die "Error in first line of script: \"$1\", expected: \"$shebang\", found: \"$lineone\""
		local scriptname="$(basename $1 | rev | cut -d '.' -f 2- | rev | sed 's/-/_/g')"
		sb_contains "$scriptname" && sb_die "Error: trying to add script \"$scriptname\" but a script with this name already exists in the box."
	}

	# sb_add creates a new box with the target script included
	# the new box is printed to stdout. It expects a path to a script as $1.
	sb_add(){
		sb_validate "$1"
		local scriptname="$(basename $1 | rev | cut -d '.' -f 2- | rev | sed 's/-/_/g')"
		# xargs to squeeze whitespace and remove leading and trailing
		scriptlist="$(printf "%s" "$scriptname $scriptlist" | xargs)"
		sb_print_head "$scriptlist" > $tmpfile
		printf "%s\n\n" "$(sb_wrap $scriptname $1)" >> $tmpfile
		sb_print_headless >> $tmpfile
		cp $tmpfile $boxpath && exit
	}

	# sb_remove creates a new version of the box with the target script removed
	sb_remove(){
		sb_contains "$1" || sb_die "No matching script ($1)"
		local newscriptlist="$(printf "%s" "$scriptlist" | sed "s/\b$1\b//g" | tr -s ' ')"

		# Collect lines before the start of the function (excluding the head) and
		# after the end of the function, then print the head followed by this new body
		local topstart="$(sb_linenum "start")"
		local topend="$(( $(sb_linenum "start" "$1") - 1 ))"
		local botstart="$(( $(sb_linenum "end" "$1") + 1 ))"

		local top="$(head -n "$topend" $boxpath | tail -n +$topstart)"
		local bot="$(tail -n +"$botstart" $boxpath)"

		# If the removed function is the first in the script, an extra blank line
		# would appear without this
		if [ $topstart -gt $topend ]; then
			sb_print_head "$newscriptlist" | head -n -1 > $tmpfile
		else
			sb_print_head "$newscriptlist" > $tmpfile
		fi

		[ -n "$top" ] && printf "%s\n" "$top" >> $tmpfile
		[ -n "$bot" ] && printf "%s\n" "$bot" >> $tmpfile
		scriptlist="$newscriptlist"
		cp $tmpfile $boxpath
	}

	# sb_replace replaces the script named $1 with the external script named $2
	sb_replace(){
		sb_remove "$1"
		sb_add "$2"
	}

	# sb_pack creates a new box from the list of scripts passed to it.
	# The new box is printed to stdout. It expects a string of paths to
	# scripts as $1
	sb_pack(){
		[ -z "$1" ] && sb_die "You must provide the path to at least one script to include"
		for i in "$@"; do
			sb_validate "$i"
			local scriptname="$(basename $i | rev | cut -d '.' -f 2- | rev | sed 's/-/_/g')"

			[ -z "$newscriptlist" ] && local newscriptlist="$scriptname" \
									|| local newscriptlist="$newscriptlist $scriptname"

			local newscript="$(sb_wrap "$scriptname" "$i")"
			[ -z "$newbox" ] && local newbox="$(printf "%s\n\n" "$newscript")" \
							 || local newbox="$(printf "%s\n\n%s\n" "$newbox" "$newscript")"
		done

		sb_print_head "$newscriptlist" > $tmpfile
		printf "%s\n%s\n" "$newbox" "$(sb_base)" >> $tmpfile
		cp $tmpfile $boxpath
	}

	# sb_unpack creates creates a script from each of the scripts in the box.
	# The scripts are placed in the directory specified by $1
	sb_unpack(){
		local errmsg="You must provide a directory to unpack to"
		[ -n "$1" ] || sb_die "$errmsg"
		[ -r "$1" -a -d "$(realpath $1)" ] || sb_die "$errmsg (and it must be readable)"

		# Opting to loop twice to avoid interrupting in the middle, being left with a partial unpack
		for i in $scriptlist; do
			local file="$(realpath $1)/$i"	
			[ -f "$file" ] && sb_die "File exists, rename, move or delete it ($file)"
		done

		for i in $scriptlist; do
			local file="$(realpath $1)/$i"	
			sb_pop "$i" > $file
		done
	}

	sb_replicate(){
		if [ -n "$1" ]; then
			local fpath="$(realpath $1)"
			[ -f $fpath ] && sb_die "Error: file \"$fpath\" exists, refusing to overwrite."
		else
			local fpath=/dev/stdout
		fi
		sb_print_head > $fpath
		sb_base >> $fpath
	}

	### Entry point ###
	calledas=$(basename "$0")
	boxpath=$(realpath "$0")

	# If input for the command was not provided then search in pipe
	[ -z "$2" -a -p /dev/stdin ] && set -- "$1" $(cat)

	# If the name of the script matches one of its listed functions (scripts),
	# run that function
	if sb_contains "$calledas"; then
		$calledas "$@"
	elif [ -n "$1" ] && sb_contains "$1"; then
		local script="$1"
		shift; $script "$@"
	else
		case "$1" in
			"add"|     "--add"|     "-a")  shift; sb_add "$@" ;;
			"remove"|  "--remove"|  "-d")  shift; sb_remove "$@" ;;
			"replace"| "--replace"| "-r")  shift; sb_replace "$@" ;;
			"install"| "--install"| "-i")  shift; sb_install "$@" ;;
			"pack"|    "--pack"|    "-p")  shift; sb_pack "$@" ;;
			"unpack"|  "--unpack"|  "-u")  shift; sb_unpack "$1" ;;
			"wrap"|    "--wrap"|    "-w")  shift; sb_wrap "$1" "$2" ;;
			"pop"|     "--pop"|     "-o")  shift; sb_pop "$1" ;;
			"base"|    "--base"|    "-b")  shift; sb_replicate "$1" ;;
			"help"|    "--help"|    "-h")  sb_help ;;
			"list"|    "--list"|    "-l")  sb_exit "$(sb_list)" ;;
			"usage"|   "--usage"|   "-u")  sb_exit "$usagetext" ;;
			"version"| "--version"| "-v")  sb_exit "$version" ;;
			"examples"|"--examples"|"-e")  sb_exit "$examples" ;;
			"")                            sb_die "$usagetext" ;;
			*)                             sb_die "No matching script ($1)" ;;
		esac
	fi
}
#_sb_### End: scriptbox ###_sb_#

scriptbox "$@"
exit
