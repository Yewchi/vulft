#!/bin/bash

VULFT_RELEASE_DIR=
VULFT_WORKING_COPY_DIR=
VULFT_DEBUG_ALLOWED=
VULFT_TARGET=
VULFT_STAGED=
VULFT_SUCCESS=

VULFT_STEAM_DESCRIPTION=../steamdesc

VULFT_STAGED_DIR="../.bots.staged.d"
VULFT_FAILED_DIR="../.bots.testfailedstaging.d"

PRINT_USAGE() {
	printf "USAGE: ./clear_for_release.sh [--WORKSHOP||--GIT]\n "
	printf "\tChecks for a valid release state for the specified target\n "
	printf "\tand removes lua debug delimited code for the workshop."

}

VULFT_RELEASE_SAVE_PREFIX=
VULFT_RECENT_RELEASE_SUFFIX=".release.d"
VULFT_PREVIOUS_RELEASE_SUFFIX=".previousrelease.d"

VULFT_GIVE_ALL_READMES="all"

#VULFT_GIT_README="README.md"

LANG_TBL_STEAM_MD_TO_CONV=("README.md" "README-Chinese.zho.md" "README-Russian.rus.md")
LANG_TBL_MD_PROVIDED=("$VULFT_GIVE_ALL_READMES" "README-Chinese.zho.md" "README-Russian.rus.md")
LANG_TBL_STAY_SAFE_HUMAN=(0 1 1)
LANG_TBL_README_GIVEN_NAME=("README.md" "安装说明" "инструкции по установке") # 'README' might be weird in other languages
LANG_TBL_LOCALE=("en" "zh" "ru")
LANG_TBL_WORKSHOP_IMG_LANG=("" "中文" "Русский")
LANG_TBL_WORKSHOP_IMG_FONT=("arialb.ttf" "malgunbd.ttf" "arialb.ttf")

CURR_LOCALE=

this_convert_file=
PRINT_CONVERT_STEAM_TO_MD() {
	#todo [h1](.)[/h1] -> ## \1
	cat $this_convert_file | sed 's/^\[url=\([^\]*\)\]\([^\[]*\)\[\/url\]/\[\2\](\1)/g'
}
PRINT_CONVERT_MD_TO_STEAM() {
	lines=$(cat $this_convert_file | grep -nZe "^[#*]" | sed 's/\([\d]*\):.*/\1/g')
	headeredit=""
	for l in $lines; do
		headeredit="$headeredit$l,${l}bm;"
	done
	if ! [[ -z $headeredit ]]; then
		headeredit="${headeredit}b;:m;s/^[#]*\(.*\)/\[h1\]\1\[\/h1\]/g"
	fi
	cat $this_convert_file | sed 's/\w*\[\([^\]*]\)(\([^)]*\))/\[url=\2\]\1\[\/url\]/g; s/\]\[/\[/g; s/<br\/>//g; s/!\[url=\([^'"]"']*\)\].*\[\/url\]/\[img\]\1\[\/img\]/g; s/^> //g; '"$headeredit"
}

WORKSHOP_RETURN_TO_LOCAL_DEV() {
	if [[ $VULFT_STAGED == "true" ]] && [[ $VULFT_TARGET == "WORKSHOP" ]]; then
		if [[ $VULFT_SUCCESS == "true" ]]; then
			# SUCCESS
			echo " -- Returning to pre-script copy -- "
			sleep 1
			read -p "mv -v $VULFT_STAGED_DIR $VULFT_RELEASE_DIR ..." reply_safe
			mv -v $VULFT_STAGED_DIR $VULFT_RELEASE_DIR

			read -p "Update the local dev script version to '$VERSION_SET' ?: " reply
			if [[ $reply == [Yy] ]]; then
				echo "Pushing the development version up.."
				sed -i -e "s/VERSION = \"v[0-9]*\.[0-9]*.*/VERSION = \"$VERSION_SET\"/g" $VULFT_RELEASE_DIR/lib_util/util.lua
				echo
			fi
		else
			# FAILED
			echo " -- Returning to pre-script copy -- "
			if [[ -d $VULFT_FAILED_DIR ]]; then
				read -p "Delete old $VULFT_FAILED_DIR?" do_delete
				if [[ $do_delete =~ ^[Yy] ]]; then
					echo "deleting $VULFT_FAILED_DIR"
					read -p "rm -rf $VULFT_FAILED_DIR ..." reply_safe
					rm -rf $VULFT_FAILED_DIR
				fi
			fi
			sleep 1
			read -p "mv -v $VULFT_RELEASE_DIR $VULFT_FAILED_DIR ..." reply_safe
			mv -v $VULFT_RELEASE_DIR $VULFT_FAILED_DIR
			echo "moving staged dev back to $VULFT_RELEASE_DIR"
			sleep 1
			read -p "mv -v $VULFT_STAGED_DIR $VULFT_RELEASE_DIR ..." reply_safe
			mv -v $VULFT_STAGED_DIR $VULFT_RELEASE_DIR
		fi
	fi
	echo " --            done              -- "
}

PROMPT_UPLOAD_STORE_LANGUAGE_RELEASE() {
	next_cont=$(head -c 3 /dev/urandom | base64)
	while (true); do
		read -p "~~SUCCESS~~ Open Dota 2 - Workshop Tools and upload to the '$CURR_LOCALE' workshop before you enter the text '$next_cont'. Do NOT upload after entering that text:" reply 
		if [[ $reply == "$next_cont" ]]; then
			break;
		fi
		echo "Nope... Interrupting now will leave the vscripts folder in staging limbo."
	done

	compound_saved_dir="$VULFT_RELEASE_SAVE_PREFIX.$CURR_LOCALE"
	vulft_recent_release_dir="$compound_saved_dir$VULFT_RECENT_RELEASE_SUFFIX"
	vulft_previous_release_dir="$compound_saved_dir$VULFT_PREVIOUS_RELEASE_SUFFIX"
	
	echo " -- Saving '$CURR_LOCALE' release -- "
	sleep 1
	read -p "rm -rf $vulft_previous_release_dir ..." reply_safe
	rm -rf $vulft_previous_release_dir
	sleep 1
	read -p "mv -v $vulft_recent_release_dir $vulft_previous_release_dir ..." reply_safe
	mv -v $vulft_recent_release_dir $vulft_previous_release_dir
	sleep 1
	read -p "cp -r $VULFT_RELEASE_DIR $vulft_recent_release_dir ..." reply_safe
	cp -r $VULFT_RELEASE_DIR $vulft_recent_release_dir
	sleep 1

	echo " --        '$CURR_LOCALE' done          -- "
}

ITERATE_PACKAGE_WORKSHOP_LANGUAGE() {
	indexlang=0

	echo
	read -p "enter current Dota 2 vers: " reply
	dota2_vers_string=$reply
	echo

	echo "- Removing any existing READMEs -"
	ls $VULFT_RELEASE_DIR/README* -C1
	sleep 1
	read -p "rm $VULFT_RELEASE_DIR/README* ..." reply_safe
	rm $VULFT_RELEASE_DIR/README*

	echo "- Make working folder copy -"
	read -p "rm -r $VULFT_WORKING_COPY_DIR" reply_safe
	rm -r $VULFT_WORKING_COPY_DIR
	read -p "cp -r $VULFT_RELEASE_DIR $VULFT_WORKING_COPY_DIR" reply_safe
	cp -r $VULFT_RELEASE_DIR $VULFT_WORKING_COPY_DIR

	while [[ $indexlang -lt ${#LANG_TBL_LOCALE} ]]; do
		CURR_LOCALE="${LANG_TBL_LOCALE[$indexlang]}"
		md_provided="${LANG_TBL_MD_PROVIDED[$indexlang]}"
		locale="${LANG_TBL_LOCALE[$indexlang]}"
		md_steam_conv="${LANG_TBL_STEAM_MD_TO_CONV[$indexlang]}"
		main_readme_given_name="${LANG_TBL_README_GIVEN_NAME[$indexlang]}"
		stay_safe_human="${LANG_TBL_STAY_SAFE_HUMAN[$indexlang]}"
		workshop_img_lang_txt="${LANG_TBL_WORKSHOP_IMG_LANG[$indexlang]}"
		workshop_img_lang_font="${LANG_TBL_WORKSHOP_IMG_FONT[$indexlang]}"

		echo "- Packing for language: '$locale' -"
		read -p "sed -i 's/^LOCALE = .*/LOCALE = $locale/g' $VULFT_RELEASE_DIR/lib_util/util.lua" reply_safe
		sed -i 's/^LOCALE = .*/LOCALE = \"'"$locale"'\"/g' $VULFT_RELEASE_DIR/lib_util/util.lua

		if [[ $stay_safe_human -eq 1 ]]; then
			echo "- Stay Safe Human -"
			read -p "for f in \$(find $VULFT_RELEASE_DIR); do sed -i 's/\sgithub[^\s]*//g; s/\sgitlab[^\s]*//g' \$f; done"
			for f in $(find $VULFT_RELEASE_DIR); do
				sed -i 's/\sgithub[^\s]*//g; s/\sgitlab[^\s]*//g' $f;
			done
		fi

		for readme_given in LANG_TBL_README_GIVEN_NAME; do
			check_readme="$VULFT_RELEASE_DIR/$readme_given"
			if [[ -f $check_readme ]]; then
				echo "removing $check_readme"
				sleep 1
				read -p "rm $check_readme ..." reply_safe
				rm $check_readme
			fi
		done
		
		echo "README to include: '$md_provided'"

# string comparison. [[ ( $num1 -eq $num2 ) ]] for arithmetic, using [[ $str1 -eq $str2 ]]
# -- will invalid if there are '.' symbols
		if [[ ( "$md_provided" == "$VULFT_GIVE_ALL_READMES" ) ]]; then
			echo "- Including additional language READMEs -"
			sleep 1
			read -p "cp README-*.*.md $VULFT_RELEASE_DIR/. ..." reply_safe
			cp README-*.*.md $VULFT_RELEASE_DIR/.
			echo "- Assuming steam README is preferred README - '$md_steam_conv'; copying -"
			if ! [[ -f $md_steam_conv ]]; then
				echo "Error - README not found!!!"
			fi
			read -p "PRINT_CONVERT_MD_TO_STEAM > $VULFT_STEAM_DESCRIPTION" reply_safe
			this_convert_file=$md_steam_conv
			PRINT_CONVERT_MD_TO_STEAM > $VULFT_STEAM_DESCRIPTION
			cp $VULFT_STEAM_DESCRIPTION ../bots/$main_readme_given_name
		else
			read -p "cp $md_provided ../bots/$main_readme_given_name ..." reply_safe
			cp $md_provided ../bots/$main_readme_given_name
			read -p "PRINT_CONVERT_MD_TO_STEAM > $VULFT_STEAM_DESCRIPTION" reply_safe
			this_convert_file=$md_steam_conv
			PRINT_CONVERT_MD_TO_STEAM > $VULFT_STEAM_DESCRIPTION
		fi

		echo
		cat $VULFT_STEAM_DESCRIPTION
		echo

		echo "- Creating workshop upload image -"
		read -p "ffmpeg -i vulft_wide_novers.jpg -vf \"drawtext=text='$dota2_vers_string':fontcolor=0x66BB22:fontsize=250:x=(w-text_w)/2:y=130:fontfile=/c/Windows/fonts/arialbi.ttf\" $VULFT_RELEASE_DIR/workshop.jpg" reply_safe
		ffmpeg -i vulft_wide_novers.jpg -vf "drawtext=text='$dota2_vers_string':fontcolor=0x66BB22:fontsize=250:x=(w-text_w)/2:y=130:fontfile=/c/Windows/fonts/arialbi.ttf" $VULFT_RELEASE_DIR/workshop.jpg
		echo "ws img lang text: $workshop_img_lang_txt"
		if [[ -n $workshop_img_lang_txt ]]; then
			read -p "ffmpeg -i $VULFT_RELEASE_DIR/workshop.jpg -vf \"drawtext=text='$workshop_img_lang_txt':fontcolor=0x66BB22:fontsize=175:x=(w-text_w)/8:y=880:fontfile=/c/Windows/fonts/$workshop_img_lang_font\" $VULFT_RELEASE_DIR/workshop2.jpg" reply_safe
			ffmpeg -i $VULFT_RELEASE_DIR/workshop.jpg -vf "drawtext=text='$workshop_img_lang_txt':fontcolor=0x66BB22:fontsize=175:x=(w-text_w)/8:y=880:fontfile=/c/Windows/fonts/$workshop_img_lang_font" $VULFT_RELEASE_DIR/workshop2.jpg
			rm $VULFT_RELEASE_DIR/workshop.jpg
			mv $VULFT_RELEASE_DIR/workshop2.jpg $VULFT_RELEASE_DIR/workshop.jpg
		fi

		PROMPT_UPLOAD_STORE_LANGUAGE_RELEASE

		read -p "Continue?: " reply
		if [[ $reply =~ ^[Nn] ]]; then
			break;
		fi
		indexlang=$(echo "$indexlang + 1" | bc -l)
		if [[ $indexlang -lt ${#LANG_TBL_LOCALE} ]]; then
			read -p "rm $VULFT_RELEASE_DIR" reply_safe
			rm -r $VULFT_RELEASE_DIR
			read -p "cp -r $VULFT_WORKING_COPY_DIR $VULFT_RELEASE_DIR" reply_safe
			cp -r $VULFT_WORKING_COPY_DIR $VULFT_RELEASE_DIR
		fi
	done
}

START_CHECK() {
	printf "/VUL-FT/ RUN CHECK(\"$CHECK\") . . .\n"
}

NOT_OKAY_EXIT() {
	FAILED=true

	printf "/VUL-FT/ FAILED CHECK(\"$CHECK\") ...NOT RELEASABLE. \n\t\"$CHECK_MSG\"\n\n"

	WORKSHOP_RETURN_TO_LOCAL_DEV

	read -p 'NOT RELEASABLE. Press return to exit: '
	exit;
}

OKAY() {
	printf "/VUL-FT/ FIN CHECK(\"$CHECK\") ...OKAY. \n\t\"$CHECK_MSG\"\n\n"
}

CHECK_SCRIPT_CALL_IS_VALID() {
	CHECK="is the call environment valid for this script"
	START_CHECK

	if [[ -d ../bots ]] && [[ -f ../vulft/clear_for_release.sh ]]; then
		OKAY
	else
		CHECK_MSG="Please place the folder containing this script in '%%vscripts%%/vulft/<this_script>.sh' and run the script from it's folder\n\tvscripts must also contain a 'bots' folder"
		NOT_OKAY_EXIT
	fi
}

CHECK_DEBUG_IS_OKAY() {
	CHECK="lib_util/util.lua DEBUG = false"
	START_CHECK

	if ! [[ -z $VULFT_DEBUG_ALLOWED ]]; then
		CHECK_MSG="DEBUG = true is allowed for target, continuing.."
		OKAY
		return;
	fi

	debug=$(grep "DEBUG =" $VULFT_RELEASE_DIR/lib_util/util.lua)
	echo found "$debug"
	if [[ $debug =~ 'DEBUG = false' ]]; then
		OKAY
		return;
	elif [[ $debug =~ 'DEBUG = true' ]]; then
		set_debug=
		read -p "Debug line found, set to?: " set_debug
		echo $set_debug
		if [[ "DEBUG = $set_debug" =~ 'DEBUG = false' ]]; then
			echo "debug set to off at $VULFT_RELEASE_DIR/lib_util/util.lua"
			sed -i -e "s/DEBUG =.*/DEBUG = $set_debug/g" $VULFT_RELEASE_DIR/lib_util/util.lua
			OKAY
			return;
		fi
	fi

	CHECK_MSG="DEBUG = true is NOT allowed for target"
	NOT_OKAY_EXIT
}

REMOVE_DEV_LUA_LINES() {
	find $VULFT_RELEASE_DIR/ -type f | xargs grep -e "\-\-\[\[DEV\]\]"
	echo
	read -p "Remove '--[[DEV]]' lines?: " reply
	if ! [[ $reply =~ ^[Nn] ]]; then
		printf " -- Removing '--[[DEV]]' lines in Lua files --\n"
		find $VULFT_RELEASE_DIR/ -type f -name "*.lua" | xargs sed -i -e 's/\-\-\[\[DEV\]\].*//g'
		printf " --                 done                    --\n\n"
	fi
}

FIND_AND_EDIT_DATES() {
	files=$(find . -name "README*")
	for f in $files; do
		echo "$f"
		dates=$(grep -o "[0-9][0-9]\/[0-9][0-9]\/[0-9][0-9]" README.md)
		n=0
		for d in $dates; do
			echo "$d"
			m=0
			for e in $dates; do
				echo "$e"
				if [[ $m -ne $n ]]; then
					echo "$m is not $n"
				fi
				m=$(echo "$m+1" | bc -l)
			done
			n=$(echo "$n+1" | bc -l)
		done
	done
}

RUN() {
	if [[ $1 == "--WORKSHOP" ]] || [[ $1 == "--WS" ]]; then
		echo "/VUL-FT/ Steam Workshop releasable state:"
		VULFT_TARGET=WORKSHOP
		VULFT_RELEASE_DIR="../bots"
		VULFT_WORKING_COPY_DIR="../.bots.workingcopy.d"
		VULFT_RELEASE_SAVE_PREFIX="../.bots"

		size_info=$(du -sh $VULFT_RELEASE_DIR) 
		printf "Size\tDir\n$size_info\n\n"

		CHECK_SCRIPT_CALL_IS_VALID

		read -p "THIS SCRIPT DEFINITELY HAS BUGS... PRESS RETURN TO ACKNOWLEDGE THE BUGS..." reply_safe

		CHECK="confirm no unix swap files"
		START_CHECK
		open_files=$(find $VULFT_RELEASE_DIR -type f -name ".*.sw*")
		if ! [[ -z $open_files ]]; then
			echo
			echo "Found open files:"
			echo $open_files
			echo
			CHECK_MSG="You have open files in '$VULFT_RELEASE_DIR':"
			NOT_OKAY_EXIT
		else
			OKAY
		fi

		echo "Removing old $VULFT_STAGED_DIR"
		read -p "rm -rf $VULFT_STAGED_DIR ..." reply_safe
		rm -rf $VULFT_STAGED_DIR
		echo "mkdir $VULFT_STAGED_DIR"
		mkdir $VULFT_STAGED_DIR
		echo "cp $VULFT_RELEASE_DIR/. $VULFT_STAGED_DIR/."
		read -p "cp $VULFT_RELEASE_DIR/. $VULFT_STAGED_DIR/. -r ..." reply_safe
		cp $VULFT_RELEASE_DIR/. $VULFT_STAGED_DIR/. -r

		VULFT_STAGED=true

		printf " -- Removing workflow files -- \n"
		read -p "find $VULFT_RELEASE_DIR/ -type f -name \".*wf\" -print | xargs rm -vf ..." reply_safe
		find $VULFT_RELEASE_DIR/ -type f -name ".*wf" -print | xargs rm -vf
		printf " --          done           -- \n\n"

		CHECK_DEBUG_IS_OKAY

	#	CHECK="provide steam README doc"
	#	START_CHECK
	#	if ! [[ -f README.steam ]]; then
	#		read -p "There is no README.steam at $(pwd). Continue without a doc?: " reply
	#		if ! [[ $reply =~ ^[Yy] ]]; then
	#			NOT_OKAY_EXIT
	#		fi
	#		echo "... Continuing with supplying a README"
	#	else
	#		cp -v README.steam $VULFT_RELEASE_DIR/README
	#	fi
	#	OKAY

		CHECK="remove DEV code"
		START_CHECK
		REMOVE_DEV_LUA_LINES
		OKAY

		CHECK="upgrade minor VERSION from recent"
		START_CHECK
		VERSION_LINE=$(grep -w "VERSION = " $VULFT_RELEASE_DIR/lib_util/util.lua)
		VERSION_FULL=$(echo "$VERSION_LINE" | sed -r 's/[^0-9]*([0-9]*)\.([0-9]*).*/\1\.\2/g')
		MAJOR_VERSION=$(echo "$VERSION_FULL" | sed -r 's/\.[0-9]*$//g')
		MINOR_VERSION=$(echo "$VERSION_FULL" | sed -r 's/^[0-9]*\.//g')
		read -p "Found '$VERSION_LINE' '$VERSION_FULL', MAJOR '$MAJOR_VERSION' MINOR '$MINOR_VERSION'. Upgrade MINOR?" reply
		if [[ $reply =~ ^[Yy] ]]; then
			MINOR_VERSION=$(($MINOR_VERSION+1))
		fi
		VERSION_SET="v$MAJOR_VERSION.$MINOR_VERSION"

		DATE=$(date -u +%y%m%d)

		read -p "Ammend date? $VERSION_SET-$DATE" reply
		if [[ $reply =~ ^[Yy] ]]; then
			VERSION_SET="$VERSION_SET-$DATE"
		fi
		echo "Using VERSION = \"$VERSION_SET\""
		sed -i -e "s/VERSION = \"v[0-9]*\.[0-9]*.*/VERSION = \"$VERSION_SET\"/g" $VULFT_RELEASE_DIR/lib_util/util.lua
		OKAY

		CHECK="bot reload succeeds"
		START_CHECK
		find $VULFT_RELEASE_DIR/ -type f -name "*.lua" | xargs sed -i -e 's/\-\-\[\[TESTTRUE\]\].*/if 1 then/g'
		read -p "Go run dota_bot_reload_scripts in console in game. Let a game play out in full. Are the bots okay?: " reply
		if ! [[ $reply =~ ^[Yy] ]]; then
			NOT_OKAY_EXIT
		fi
		OKAY

		# Language workshop packaging
		ITERATE_PACKAGE_WORKSHOP_LANGUAGE

	##	if [[ -f $VULFT_GIT_README ]]; then
	##		tabchar=$'\n'
	##		echo "############# PRE .MD-TO-STEAM FILE### ###############"
	##		head -n 3 $VULFT_GIT_README | sed 's/\(.*\)/'"\\${tabchar}"'\1/g'
	##		echo "..."
	##		tail -n 7 $VULFT_GIT_README | sed 's/\(.*\)/'"\\${tabchar}"'\1/g'
	##		echo "############# ######################### ###############"
	##		echo "The git $VULFT_GIT_README file will be placed in the release folder. It is also the mardown README for git."
	##
	##		read -p "Edit $VULFT_GIT_README?: " reply
	##		if [[ $reply == [Yy] ]]; then
	##			vim README.md
	##		fi
	##		
	##		cp $VULFT_GIT_README $VULFT_RELEASE_DIR/README
	##		this_convert_file=$VULFT_GIT_README
	##		echo "########### CONVERT TO STEAM FORMATTING ###############"
	##		PRINT_CONVERT_MD_TO_STEAM
	##		echo "########### ########################### ###############"
	##	else
	##		echo -n "\'README.steam\' not found in the local directory"; sleep 1; echo -n ". "; sleep 1; echo -n ". "; sleep 1; echo -n ". "
	##		echo "... Ignoring."
	##	fi

		VULFT_SUCCESS=true
	elif [[ $1 == "--GIT" ]]; then
		echo "/VUL-FT/ Git project commitable state:"
		VULFT_TARGET=GIT
		VULFT_RELEASE_DIR=../vulft

		CHECK_SCRIPT_CALL_IS_VALID

		CHECK_DEBUG_IS_OKAY

		REMOVE_DEV_LUA_LINES

		VULFT_SUCCESS=true
	elif [[ $1 == "--steamtomd" ]]; then
		this_convert_file=$2
		PRINT_CONVERT_STEAM_TO_MD
	elif [[ $1 == "--mdtosteam" ]]; then
		this_convert_file=$2
		PRINT_CONVERT_MD_TO_STEAM
	else
		FIND_AND_EDIT_DATES
		PRINT_USAGE
		exit;
	fi
	exit;
}
if [[ 1 ]]; then
	trap "echo ''; read -p 'Caught SIGINT, cleaning up...' reply_safe; trap SIGINT; WORKSHOP_RETURN_TO_LOCAL_DEV; exit" SIGINT
	#
	RUN $1 $2 $3 $4 $5; WORKSHOP_RETURN_TO_LOCAL_DEV
fi
