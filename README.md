Developer README.md

Development status: Fortnightly update (18/11/22)

VUL-FT - Very U(gly, Unrolled, Unabstracted, and Fast) Lua Full Takeover for Dota 2

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

==Lua is frustrating==

The code is generally okay but due to the scale, very messy. I have strong feelings about
the overhead that Lua provides when calling functions and switching file contexts--the
way that it takes a mile-long step away from C data handling--not because it is
unnessesary and not to ignore accessible community content creation and safety, but
because it is unfortunate when asking "How often will I call this function?" and the
answer may be "Often enough to unroll the function anew for each instance of use, and to
abandon functional abstraction standards; or adhering to standards would see us with
10 more functions inside of this function, and most computation spent on overhead." To
strain, I hate this code-base, because it's meant to be lean and mean but it has to be
bloated, it begs to be cleaned up.

Additionally, using a C library funciton like band() intead of a self-written locally
indexed Math_BinaryAnd() was an order of magnitude improvement (for that single
operation). There is a reason these C for Lua libraries have been written. I double
checked my work. I made the BinaryAnd func just return the argument value. Still huge
overhead.

Opposing all of this, vector mathematics do not use the Valve API wherever possible --
I'm quite sure they are Valves compiled and optimized C++ -- I did this because
I wanted to improve my vector mathematics.

==Problem of scope==

The bots are at 'about 1/2' of their intended macro and micro strength, and 'maybe 3/4'
of my own computational limit target. So there would be a hell of a lot more to do on
this project. The task system I designed allows the tacking-on of additional tasks
like the strength of a knotted rope, computationally. Every other task added fights for
analytical CPU time like uniquely-coloured gumballs falling through the machine 5 at a
time or per frame, so quite a few more things could be added, re-prioritized (like
increasing the weight of that colour gumball) and look like a very colourful gumball
machine, and much more formidable bot. However, the gumball queue can be flooded if
too many task priorities are set to the first list ('analyze me' this is re-prioritizing)
too often.

One negative effect of the system is that tasks will usually be assessed multiple frames
in a row, but they are being filtered down to lower priority lists while they are not
reprioritizing, and as long as things are calibrated well enough, it gives the
opportunity for other tasks to get bonus analytics as the other tasks get pushed to lists
below.

CPU usage naturally drops on slower computers, but tasks tend to receive about the same
percentage of CPU time. The slower the computer, the more the tasks rely on real-time
reprioritization to receive consideration.

In a redesign I would pressurize the metaphorical gumballs to pop into the analytical
loop over time so that priority deltas didn't have to be so hand-crafted. Even a simple
value that starts at large arbitrary negative P and increases by a static value scaled to
a priority per frame, sorting tasks during priority increases, then running the top 5
tasks and putting them back at -P.

woo

Thank you for reading,

==Contact==

	zyewchi@gmail.com -- Mike
	
Always happy to answer any technical questions about the project.
