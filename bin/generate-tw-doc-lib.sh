#!/bin/bash

#source common-lib.sh
#source file-lib.sh

progName="generate-tw-doc-lib.sh"

linePrefix="\#"
twDocStart="#twdoc"
twDocEnd="#/twdoc"

wikiName="tw-doc-tmp-node-wiki"
tags=""

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
  echo "    -p <line prefix> line prefix for comments where twdoc can be found"
  echo "       default: '$linePrefix'"
  echo
}


function extractTWDocFromLib {
    libName="$1"
    libTiddlerFile="$2"

 #   echo "DEBUG libName='$libName' ; libTiddlerFile='$libTiddlerFile'" 1>&2
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
		currentDest="$path/$(echo "${libName}_$possibleTitle" | tr '/' '_').tid"
#		echo "DEBUG START SUB; currentDest='$currentDest'" 1>&2
		writeCreatedTodayField >"$currentDest"
		echo "title: ${libName}/$possibleTitle" >>"$currentDest"
		echo "tags: [[$libName]]" >>"$currentDest"
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

function writeCreatedTodayField {
    theDate=$(date +"%Y%m%d%H%M%S")
    echo "created: ${theDate}000"
}



OPTIND=1
while getopts 'ht:p:' option ; do
    case $option in
	"t" ) tags="$OPTARG";;
	"p" ) linePrefix="$OPTARG";;
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
echo "DEBUG: workDir = $workDir"  1>&2

cp "$htmlWikiFile" "$workDir"
pushd "$workDir" >/dev/null
tiddlywiki "$wikiName" --init server >/dev/null # create temporary node.js wiki 
tiddlywiki "$wikiName" --load $(basename "$htmlWikiFile") >/dev/null # convert standalone to tid files
popd >/dev/null

while read libFile; do
    tiddlerName="$libFile"
    tiddlerFile=$(echo "$tiddlerName" | tr '/' '_')
    targetTiddler="$workDir/$wikiName/tiddlers/$tiddlerFile.tid"
    writeCreatedTodayField >"$targetTiddler"
    echo "title: $tiddlerName" >>"$targetTiddler"
    echo "tags: $tags" >>"$targetTiddler"
    echo "type: text/vnd.tiddlywiki" >>"$targetTiddler"
    echo ""  >>"$targetTiddler"
    cat "$libFile" | extractTWDocFromLib "$libFile" "$targetTiddler"
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
rm -rf "$workDir"
