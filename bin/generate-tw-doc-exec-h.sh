#!/bin/bash

#source common-lib.sh
#source file-lib.sh

progName="generate-tw-doc-exec-h.sh"

wikiName="tw-doc-tmp-node-wiki"
tags=""
debug=0

function usage {
  echo
  echo "Usage: $progName [options] <html wiki file> "
  echo
  echo "  Generates the 'tiddlers' containing some executable scripts help"
  echo "  messages and adds/updates this content in the documentation wiki"
  echo "  supplied as parameter."
  echo "  The list of executable files for which the help message should"
  echo "  be printed is read from STDIN."
  echo
  echo
  echo "  Options:"
  echo "    -h this help"
  echo "    -t <tags> tags to be added to every generated tiddler (TW syntax)"
  echo
}


function writeCreatedTodayField {
    theDate=$(date +"%Y%m%d%H%M%S")
    echo "created: ${theDate}000"
}



OPTIND=1
while getopts 'ht:d' option ; do
    case $option in
	"t" ) tags="$OPTARG";;
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

while read executableFile; do
    tiddlerName=$(basename "$executableFile")
    rm -f "$workDir/$wikiName/tiddlers"/$tiddlerName.* # to overwrite any previous version with .txt and .meta (don't completely understand this new stuff in TW 5.1.14)
    targetTiddler="$workDir/$wikiName/tiddlers/$tiddlerName.txt.tid"
    writeCreatedTodayField >"$targetTiddler"
    echo "title: $tiddlerName" >>"$targetTiddler"
    echo "tags: $tags" >>"$targetTiddler"
    echo "type: text/plain" >>"$targetTiddler"
    echo ""  >>"$targetTiddler"
    eval "$executableFile -h" >> "$targetTiddler"
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
