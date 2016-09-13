#!/bin/bash

#twdoc
#
# This tool generates tiddlers containing some comments read from some library files.
#
# The present file is not a library but is used as an example: this paragraph appears
# between markers ``twdoc ... /twdoc``, so it will be included in the general tiddler
# about this file. Similarly, a few ``twdoc ... /twdoc`` blocks are used to describe
# the functions below and each will be included in a different tiddler.
#
# See also [[DocGenerationCommand]].
#
# EM Sept 2016
#
#/twdoc

progName="generate-tw-doc-lib.sh"

linePrefix="\#"
twDocStart="#twdoc"
twDocEnd="#/twdoc"

debug=0

wikiName="tw-doc-tmp-node-wiki"
tags=""
removePathPrefix=""
tiddlerPrefix=""

#twdoc usage
#
# Prints the usual help message.
#
#/twdoc
function usage {
  echo
  echo "Usage: $progName [options] <html wiki file> "
  echo
  echo "  Generates the 'tiddlers' containing specific parts of some text"
  echo "  files, marked 'twdoc ... /twdoc'. Intended to generate documentation"
  echo "  about the functions inside the source code of a library (in a "
  echo "  vaguely similar way as javadoc, for example)."
  echo "  Then adds/updates this content in the documentation wiki"
  echo "  supplied as parameter."
  echo "  The list of source files (e.g. libraries) is read from STDIN."
  echo
  echo "  Options:"
  echo "    -h this help"
  echo "    -t <tags> tags to be added to every generated tiddler (TW syntax)"
  echo "    -p <line prefix> line prefix for comments where twdoc can be found"
  echo "       default: '$linePrefix'"
  echo "    -r <path prefix> remove this prefix from the filename before using"
  echo "       it as title."
  echo "    -n <tiddler name prefix> add this prefix to every tiddler title."
  echo "    -d debug mode, don't delete the working directory."
  echo
}


#twdoc extractTWDocFromLib $tiddlerName $libTiddlerFile
#
# Extracts all the content from a library file read from STDIN, and writes the
# corresponding tiddlers.
#
# * ``$tiddlerName`` is the name of the main tiddler, where ``twdoc`` comments without any specific title are written.
# * ``$libTiddlerFile`` is the filename of the main tiddler.
# 
# each ``twdoc`` comment with a title is written to a specific tiddler with
# this title, prefixed by the main tiddler name and tagged with the main
# tiddler.
#
#/twdoc
#
function extractTWDocFromLib {
    tiddlerName="$1"
    libTiddlerFile="$2"

    path=$(dirname "$libTiddlerFile")

    currentDest=""
    inside=0
    lineNo=1
    while read line; do
#	echo "DEBUG line='$line' inside=$inside; '${line:0:${#twDocEnd}}' == '$twDocEnd'?" 1>&2
	if [ "${line:0:${#twDocStart}}" == "$twDocStart" ]; then # start of twdoc section
#	    echo "DEBUG START" 1>&2
	    if [ $inside -eq 1 ]; then
		echo "Warning: already inside twdoc section line $lineNo" 1>&2
	    fi
	    inside=1
	    possibleTitle=${line:${#twDocStart}}
	    if [ ! -z "$possibleTitle" ]; then
		possibleTitle=$(echo "$possibleTitle" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		currentDest="$path/$(echo "${tiddlerName}_$possibleTitle" | tr '/' '_' | tr ' ' '_' | tr '?' '_' ).tid"
#		echo "DEBUG START SUB; currentDest='$currentDest'" 1>&2
		writeCreatedTodayField >"$currentDest"
		echo "title: ${tiddlerName}/$possibleTitle" >>"$currentDest"
		echo "tags: [[$tiddlerName]]" >>"$currentDest"
		echo "type: text/vnd.tiddlywiki" >>"$currentDest"
		echo ""  >>"$currentDest"
		
	    else
		currentDest="$libTiddlerFile"
	    fi
	elif [ "${line:0:${#twDocEnd}}" == "$twDocEnd" ]; then # end of twDoc section
#	    echo "DEBUG END" 1>&2
	    if [ $inside -eq 0 ]; then
		echo "Warning: already outside twdoc section line $lineNo" 1>&2
	    fi
	    inside=0
	else 
	    if [ $inside -eq 1 ]; then
#		echo "DEBUG adding '${line#$prefix}' to $currentDest"
#		echo "DEBUG {line#$linePrefix}=${line#$linePrefix}"
		echo "${line#$linePrefix}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' >>"$currentDest"
	    fi
	fi
	lineNo=$(( $lineNo + 1 ))
    done
    if [ $inside -eq 1 ]; then
	echo "Warning: twdoc section left open line $lineNo" 1>&2
    fi
}


#twdoc writeCreatedTodayField
#
# Prints the current date/time in TW format.
#
#/twdoc
function writeCreatedTodayField {
    theDate=$(date +"%Y%m%d%H%M%S")
    echo "created: ${theDate}000"
}



OPTIND=1
while getopts 'ht:p:r:dn:' option ; do
    case $option in
	"t" ) tags="$OPTARG";;
	"p" ) linePrefix="$OPTARG";;
	"r" ) removePathPrefix="$OPTARG";;
	"n" ) tiddlerPrefix="$OPTARG";;
	"d" ) debug=1;;
        "h" ) usage
              exit 0;;
        "?" )
            echo "Error, unknow option." 1>&2
            printHelp=1;;
    esac
done
shift $(($OPTIND - 1))
if [ $# -ne 1 ]; then
    echo "Error: expecting 1 args." 1>&2
    printHelp=1
fi
if [ ! -z "$printHelp" ]; then
    usage 1>&2
    exit 1
fi

htmlWikiFile="$1"

workDir=$(mktemp -d)

cp "$htmlWikiFile" "$workDir"
pushd "$workDir" >/dev/null
tiddlywiki "$wikiName" --init server >/dev/null # create temporary node.js wiki 
tiddlywiki "$wikiName" --load $(basename "$htmlWikiFile") >/dev/null # convert standalone to tid files
popd >/dev/null

while read libFile; do
    tiddlerName="${tiddlerPrefix}${libFile#$removePathPrefix}"
#    echo "DEBUG: libFile='$libFile', removePathPrefix='$removePathPrefix', tiddlerName='$tiddlerName'" 1>&2
    tiddlerFile=$(echo "$tiddlerName" | tr '/' '_')
    targetTiddler="$workDir/$wikiName/tiddlers/$tiddlerFile.tid"
#    echo "DEBUG tiddlerName=$tiddlerName; tiddlerFile=$tiddlerFile; targetTiddler=$targetTiddler" 1>&2
    writeCreatedTodayField >"$targetTiddler"
    echo "title: $tiddlerName" >>"$targetTiddler"
    echo "tags: $tags" >>"$targetTiddler"
    echo "type: text/vnd.tiddlywiki" >>"$targetTiddler"
    echo ""  >>"$targetTiddler"
    cat "$libFile" | extractTWDocFromLib "$tiddlerName" "$targetTiddler"
done

pushd "$workDir" >/dev/null
tiddlywiki "$wikiName" --rendertiddler "$:/plugins/tiddlywiki/tiddlyweb/save/offline" "output.html" text/plain >/dev/null
popd >/dev/null

resHtmlFile="$workDir/$wikiName/output/output.html"
if [ -s "$resHtmlFile" ]; then
    rm -f "htmlWikiFile"
    mv "$resHtmlFile" "$htmlWikiFile"
else
    echo "An error happened, no result wiki file '$resHtmlFile' found." 1>&2
    exit 2
fi

if [ $debug -eq 0 ]; then
    rm -rf "$workDir"
else
    echo "DEBUG MODE: working directory '$workDir' not deleted."  1>&2
fi
