#!/usr/bin/env bash

# Copyright 2011 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# This script creates the .zip, index, and configuration files for running
# godoc on app-engine.
#
# If an argument is provided it is assumed to be the app-engine godoc directory.
# Without an argument, $APPDIR is used instead. If GOROOT is not set, the
# current working directory is assumed to be $GOROOT. Various sanity checks
# prevent accidents.
#
# The script creates a .zip file representing the $GOROOT file system
# and computes the correspondig search index files. These files are then
# copied to $APPDIR. A corresponding godoc configuration file is created
# in $APPDIR/appconfig.go.

ZIPFILE=godoc.zip
INDEXFILE=godoc.index
SPLITFILES=index.split.
CONFIGFILE=godoc/appconfig.go

error() {
	echo "error: $1"
	exit 2
}

getArgs() {
	if [ -z $GOROOT ]; then
		GOROOT=$(pwd)
		echo "GOROOT not set, using cwd instead"
	fi
	if [ -z $APPDIR ]; then
		if [ $# == 0 ]; then
			error "APPDIR not set, and no argument provided"
		fi
		APPDIR=$1
		echo "APPDIR not set, using argument instead"
	fi
	
	# safety checks
	if [ ! -d $GOROOT ]; then
		error "$GOROOT is not a directory"
	fi
	if [ ! -x $GOROOT/src/cmd/godoc/godoc ]; then
		error "$GOROOT/src/cmd/godoc/godoc does not exist or is not executable"
	fi
	if [ ! -d $APPDIR ]; then
		error "$APPDIR is not a directory"
	fi
	if [ ! -e $APPDIR/app.yaml ]; then
		error "$APPDIR is not an app-engine directory; missing file app.yaml"
	fi
	if [ ! -d $APPDIR/godoc ]; then
		error "$APPDIR is missing directory godoc"
	fi

	# reporting
	echo "GOROOT = $GOROOT"
	echo "APPDIR = $APPDIR"
}

cleanup() {
	echo "*** cleanup $APPDIR"
	rm $APPDIR/$ZIPFILE
	rm $APPDIR/$INDEXFILE
	rm $APPDIR/$SPLITFILES*
	rm $APPDIR/$CONFIGFILE
}

makeZipfile() {
	echo "*** make $APPDIR/$ZIPFILE"
	zip -q -r $APPDIR/$ZIPFILE $GOROOT -i \*.go -i \*.html -i \*.css -i \*.js -i \*.txt -i \*.c -i \*.h -i \*.s -i \*.png -i \*.jpg -i \*.sh -i \*.ico
}

makeIndexfile() {
	echo "*** make $APPDIR/$INDEXFILE"
	OUT=/tmp/godoc.out
	$GOROOT/src/cmd/godoc/godoc -write_index -index_files=$APPDIR/$INDEXFILE -zip=$APPDIR/$ZIPFILE 2> $OUT
	if [ $? != 0 ]; then
		error "$GOROOT/src/cmd/godoc/godoc failed - see $OUT for details"
	fi
}

splitIndexfile() {
	echo "*** split $APPDIR/$INDEXFILE"
	split -b8m $APPDIR/$INDEXFILE $APPDIR/$SPLITFILES
}

makeConfigfile() {
	echo "*** make $APPDIR/$CONFIGFILE"
	cat > $APPDIR/$CONFIGFILE <<EOF
package main

// GENERATED FILE - DO NOT MODIFY BY HAND.
// (generated by $GOROOT/src/cmd/godoc/setup-godoc-app.bash)

const (
	// .zip filename
	zipFilename = "$ZIPFILE"

	// goroot directory in .zip file
	zipGoroot = "$GOROOT"

	// glob pattern describing search index files
	// (if empty, the index is built at run-time)
	indexFilenames = "$SPLITFILES*"
)
EOF
}

getArgs "$@"
cleanup
makeZipfile
makeIndexfile
splitIndexfile
makeConfigfile

echo "*** setup complete"