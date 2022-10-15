#!/bin/bash

VULFT_RELEASE_DIR=
VULFT_DEBUG_ALLOWED=
VULFT_TARGET=
VULFT_STAGED=
VULFT_SUCCESS=

PRINT_USAGE() {
	printf "USAGE: ./clear_for_release.sh [--WORKSHOP||--GIT]\n "
	printf "\tChecks for a valid release state for the specified target\n "
	printf "\tand removes lua debug delimited code for the workshop."
}

WORKSHOP_RETURN_TO_LOCAL_DEV() {
	if [[ $VULFT_STAGED == "true" ]] && [[ $VULFT_TARGET == "WORKSHOP" ]]; then
		if [[ $VULFT_SUCCESS == "true" ]]; then
			# SUCCESS
			next_cont=$(head -c 3 /dev/urandom | base64)
			while(true); do
				read -p "~~SUCCESS~~ Open Dota 2 - Workshop Tools and upload before you enter the text '$next_cont'. Do NOT upload after entering that text:" reply 
				if [[ $reply == "$next_cont" ]]; then
					break;
				fi
				echo "Nope... Did you UPLOAD!?"
			done
			
			echo " -- Returning to pre-script copy -- "
			rm -rf ../.bots.revertreleasable.d
			mv -v ../.bots.recentreleasable.d ../.bots.revertreleasable.d
			mv -v ../bots ../.bots.recentreleasable.d
			mv -v ../.bots.recentstaged.d ../bots
		else
			# FAILED
			echo " -- Returning to pre-script copy -- "
			if [[ -d ../.bots.recentfailedstaged.d ]]; then
				read -p "Delete old .bots.recentfailedstaged.d?" do_delete
				if [[ $do_delete =~ ^[Yy] ]]; then
					echo "deleting ../.bots.recentfailedstaged.d"
					rm -rf ../.bots.recentfailedstaged.d
					mv -v ../bots ../.bots.recentfailedstaged.d
					mv -v ../.bots.recentstaged.d ../bots
				fi
			else
				mv -v ../bots ../.bots.recentfailedstaged.d
				mv -v ../.bots.recentstaged.d ../bots
			fi
		fi
	fi
	echo " --            done              -- "
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

if [[ $1 == "--WORKSHOP" ]] || [[ $1 == "--WS" ]]; then
	echo "/VUL-FT/ Steam Workshop releasable state:"
	VULFT_TARGET=WORKSHOP
	VULFT_RELEASE_DIR="../bots"

	size_info=$(du -sh $VULFT_RELEASE_DIR) 
	printf "Size\tDir\n$size_info\n\n"

	CHECK_SCRIPT_CALL_IS_VALID

	CHECK="confirm no unix swap files"
	START_CHECK
	rm -rf ../.bots.recentstaged.d
	mkdir ../.bots.recentstaged.d
	VULFT_STAGED=true
	cp ../bots/. ../.bots.recentstaged.d/. -r

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

	printf " -- Removing workflow files -- \n"
	find $VULFT_RELEASE_DIR/ -type f -name ".*wf" -print | xargs rm -vf
	printf " --          done           -- \n\n"

	CHECK_DEBUG_IS_OKAY

	CHECK="provide steam README doc"
	START_CHECK
	if ! [[ -f README.steam ]]; then
		read -p "There is no README.steam at $(pwd). Continue without a doc?: " reply
		if ! [[ $reply =~ ^[Yy] ]]; then
			NOT_OKAY_EXIT
		fi
		echo "... Continuing with supplying a README"
	else
		cp -v README.steam $VULFT_RELEASE_DIR/README
	fi
	OKAY

	CHECK="remove DEV code"
	START_CHECK
	REMOVE_DEV_LUA_LINES
	OKAY

	CHECK="bot reload succeeds"
	START_CHECK
	find $VULFT_RELEASE_DIR/ -type f -name "*.lua" | xargs sed -i -e 's/\-\-\[\[TESTTRUE\]\].*/if 1 then/g'
	read -p "Go run dota_bot_reload_scripts in console in game. Let a game play out in full. Are the bots okay?: " reply
	if ! [[ $reply =~ ^[Yy] ]]; then
		NOT_OKAY_EXIT
	fi
	OKAY

	VULFT_SUCCESS=true

	WORKSHOP_RETURN_TO_LOCAL_DEV
elif [[ $1 == "--GIT" ]]; then
	echo "/VUL-FT/ Git project commitable state:"
	VULFT_TARGET=GIT
	VULFT_RELEASE_DIR=../vulft

	CHECK_SCRIPT_CALL_IS_VALID

	CHECK_DEBUG_IS_OKAY

	REMOVE_DEV_LUA_LINES

	VULFT_SUCCESS=true
else
	PRINT_USAGE
	exit;
fi
exit;
