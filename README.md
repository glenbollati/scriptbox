# Scriptbox
Scriptbox (inspired by [BusyBox](https://www.busybox.net/)) is a shell script that encapsulates other shell scripts for portability. It contains the logic required to add and remove scripts (see `add`, `remove`, `replace` and `pack` commands), produce a slim version of itself containing no other scripts (`base`) and spit out links to each of its scripts (`install`), as well as standalone versions of the scripts it contains (`pop` and `unpack`). The scripts are stored internally as functions.

It is a POSIX shell script (tested against BusyBox's `ash`) and depends only on common tools included within a typical BusyBox binary (`cut`, `realpath`, `basename`, `head`, *etc*). 

## Usage

```
	    scriptbox [scriptname [arguments]...]
	or: scriptbox install   [symlink]          <dir>
	or: scriptbox add       <path/to/script>
	or: scriptbox pack      <path/to/script>  [path/to/other/script] ...
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
	or: scriptbox help
```

## Examples

```
scriptbox add <path/to/script.sh>
	add a script to the box

scriptbox pack myscripts/*
	add all of the scripts in the "myscripts" directory

find myscripts/ -type f -name "*.sh" -not -name "_*" | scriptbox.sh pack
	add all of the scripts under the "myscripts" directory, excluding ones that start
	with an underscore:

scriptbox install --symlink /usr/local/bin
	create a named symlink in /usr/local/bin for each script in scriptbox
```

## A recommended addition: `msb`

I find it useful to include a script to quickly jump to a function (script) within scriptbox for modification, my version is the following one-liner, which I save as `msb`:

```sh
sudo vi +"/^$@.*(){" $(which scriptbox) -c 'normal zt'
```

I've included it as a separate script.

## Quirks

### #!/bin/sh

Scriptbox was designed with portability in mind, the shebang therefore points to `/bin/sh`. Since this is usually a POSIX shell (not bash), including bashisms in your scripts will cause errors by default.

If you want to include bash (or Zsh, or whatever) *-isms* , change the shebang on first line, as well as the `shebang` variable at the very start of the `scriptbox()` function; note that if you then `pop` scripts out of scriptbox, they will include the new shebang.

In short: you can not safely mix scripts meant to be executed by different shells within scriptbox.

### Add comments to the end of the file

You should not manually add anything (including comments) above the `scriptbox()` function - they will be overwritten when performing certain operations that modify the file (`add`, `remove`, *etc*). If you want to add comments, add them to the end of the file.
