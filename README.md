Developer README.md

Development status: Fortnightly update (11/03/23)

VUL-FT - Very U(gly, Unrolled, Unabstracted, and Fast) Lua Full Takeover for Dota 2

==Installing==

Please see the README.steam file for install instructions. If you have git, you can
'git clone https://github.com/Yewchi/vulft.git' while in the directory:

	<%STEAM_DIR%>steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots

Alternatively, press the probably green "Code" button above, and download the repo
as a zip, and unzip it to the same folder stated above.

==Project workflow==

Project workspaces can be viewed in the vim sessions (enter g then CTRL+T to tab through):

	vim -S .taskwf
	vim -S .anwf
	vim -S .syswf
	vim -S .herowf
	
or alternatively in bash
	. .wf

==Full-takeover==

I need to explain why I overrode the mode_x.lua files for a full-takeover bot:
I'm unable to make the bots pick up river bounty runes. I've tried many silly things. So
the full takeover is conducted by forcing mode_roam into a 100% desire state, running the
bots within 'roam', and disabling the full-takeover by setting roam's desire to 0% for a
bot near a river bounty rune when it is available, allowing the bots to engage default
behaviour for less than a second, hopefully long enough to pick up the rune, but short
enough to prevent any major behavioural shifts. After the 0:00 minute runes are seen to be
missing or a hard-coded cut-off time in the early game (the 'other' water rune is broken),
bot_generic is signaled to override Think(). So the bots spend less than a second on
default mode, and the hook is removed to be a total override after the bounty runes.

I might keep the bots in the flippable hook at some point in the future so that extra runes
and water runes can always be picked up with this method. I would rather make proof of
concept of the full-takeover and also of the hookable behaviour at the same time, for now.
However, if this is the solution followed, it might mean other problems in the future;
item management being interrupted by default bots being the most likely.

==Dotabuff data integration==

I wrote a dotabuff data ripper which means that I can automate item and talent builds
based on recent behaviour at the top of ranked. So, if gyrocopter support is a meme build
that is used half of games, then the scoring would be increased for gyro to be given a
support role.

However, the itemization is not completed and is a static rip of the most recent Dotabuff
Guide (i.e. a recent match build). It was hoped to separate the item builds into logic
around the role chosen, and also to detect commonly-taken-with items. There is also no
taken-with logic in the skill build, and the resulting skill and talent build is
whatever most resembles all 5 recent matches the most. This means a hero in a support
role that showed most recently a core match on Dotabuff may build core items, or
inversely a core may end up with a support match's build, at least for now.

yet to summon any demons from the pit of hell for parsing html in C.

Update frequency will be based on subs, I guess. We still lose to RMM.. we used to win,
but it was because of split pushing, a total accident that penetrated a weakness in
wombo combo style bots. Now, the bots 'play better', but lose out to RMM's strong desire
for taking objectives -- Something VUL doesn't really understand yet. 13/10/22

==Lua==

This codebase is very stubborn about disobeying coding practices that Lua expects of it's
programmers, in order to improve performance. Modules/Files might be very messy where
abstraction would make things neat. If it looks like garbage it's because I'm thinking
about functional overhead.

==Optimizing isn't finished==

Let me know if this runs poorly on your computer, or worse than other bots.

https://steamcommunity.com/sharedfiles/filedetails/?id=2872725543

Vector mathematics do not use the Valve API wherever possible --
I'm quite sure they are Valves compiled and optimized C++ -- I did this because
I wanted to improve my vector mathematics.

==Future progress==

Bots aren't done, they can be much better and include grander strategy, but it's a
lot of work and my main motivation currently is "it's something to do." If I could
make a job out of this I'd be all over it.

==Support==

Please shoot me an email for any questions or to support the project:
zyewchi@gmail.com

If you would like to support the project, my paypal is on the above email with the
goofy robot icon. Support means I can justify more time to make them better. But
also just a nice comment on the workshop page helps a lot.

==Contact==

	zyewchi@gmail.com -- Mike
	
Always happy to answer any technical questions about the project.
