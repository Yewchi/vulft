VULFT - Full Takeover Bot Script. Highly dynamic fight behaviour. DotaBuff roles and item builds updated on: 19/09/23. Requires manual install into vscripts/bots folder (all recently released bots have this issue). VUL-FT has no affiliation with DotaBuff.

[url=https://steamcommunity.com/groups/VULFT/announcements/detail/6966546241858334331]Translations of This Page in Other Languages[/url]


[h1] == Manually installing ==[/h1]
VUL-FT currently will not work via subscription. It will revert to the default bots, it seems other recent bots have the same issue. I'm still investigating what is going wrong there. For now, it's necessary to manually install the bots.

Optional: Before setting VUL-FT as the local dev script, It may also be a good idea to backup your old 'vscript/bots' folder if you have another bot that you have stored there:
The local dev bot folder is located at
[drive]:/%Program Files%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots

0) rename bots folder to bots.old.
1) make a new folder named bots
2) copy the VUL-FT files from either github or the workshop folder into the new bots folder.


[h1] -- Via workshop local files: (the Valve-verified workshop files)[/h1]
After freshly subscribing, find the recent folder in
[drive]:/%Program Files%/Steam/steamapps/workshop/content/570/2872725543

and copy the contents of that folder to the bots folder at
[drive]:/%Program Files%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots/


[h1] -- Via Github: (updated by the creator)[/h1]
If you know how to use git you can manually download the bots from the [url=https://github.com/Yewchi/vulft]official VUL-FT Github[/url] and put them in
[drive]:/%Program Files%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots/


[h1] -- Running:[/h1]
After one of the above steps are complete, you can run the bots by navigating in-game to
Custom Lobbies -> Create -> Edit:
Under BOT SETTINGS change team bots to Local Dev Script (if you still want to fight the Valve bots, note that there is an option for "Default Bots" here as well)
Change SERVER LOCATION to LOCAL HOST (your computer).
Difficulty has no effect yet.
Press OK.
Join the top slot of either team.
Press START GAME.

Alternatively, you may use "Play VS Bots" option but not all heroes are implemented. Sorry about all of this, but it is just the effect of having to run the bots as a dev, rather than via the workshop.


[h1] == Features ==[/h1]

[img]https://steamuserimages-a.akamaihd.net/ugc/2028349340710795317/22D68EA70AEF6E343BBE3EBD5F1A3EF1C52F5A04/?imw=5000&imh=5000&ima=fit&impolicy=Letterbox&imcolor=%23000000&letterbox=false[/img]

Dynamic fight decision making.
More player-like.

[img]https://steamuserimages-a.akamaihd.net/ugc/2009206964554280836/186F1E4C8B555F0D06352C96399941EBBD9A29E5/?imw=5000&imh=5000&ima=fit&impolicy=Letterbox&imcolor=%23000000&letterbox=false[/img]

Orb Walking.
Advanced item management.
Automatically generated and filtered for error ward locations, if the map ever changes.
DotaBuff parser for averaged out of 5 game skill build, roles and an item build from Divine - Immortal players that week.
Basic jungling in downtime.
They may jungle self-deny in the early game if they get caught by the enemy.
Dynamic retreat, to friendly towers (unless the tower gets overrun), or to friendly allies in the direction of the allied fountain.
Bounty rune task allocation based on proximity, safety, fog, greed rating
Tower defense allocation based on required threat. (No 5-man deathballs because you looked rudely at a tower).
Lower CPU usage than other popular bots.
Bugs!

In addition. I promise this project's code is 100% functional offline and will stay that way. No networking API functions, ever.


[h1] == Error Report ==[/h1]
[url=https://steamcommunity.com/workshop/filedetails/discussion/2872725543/3648503910213521285/]Lua Error Dump (steam discussion link)[/url] -- Use this if you just want to quickly dump some console output.

[url=https://github.com/Yewchi/vulft]VUL-FT source code[/url] -- Public github

[h1] == Not yet implemented ==[/h1]
The player can only choose their lane and role in the first 30 seconds of a match.
Macro fight behaviour, initiator choice, grander strats like cutting losses, trading towers. They will assess the current aggressive plays being made and see if they think it's worth it for themselves, if an enemy is occupied attacking someone else. Enemy fight intent is tracked and loses magnitude based on facing direction, this allows allies to recognize trading without being attacked.
Player-to-bot ping communication.
Enemy vision assessments.
Dewarding.
Sentry and dust for enemy stealth.
Outposts.
Illusions are controlled by default behaviour. (But arc warden double is full-takeover).
Enemy fountain threat.
Avoid zones.
Response types for ability casts. (Rupture: Avoid unnecessary movement)
Structural enemy unit-health units. (tombstone, supernova)
Attacking and avoiding hero creep units. (Lycan wolves, Broodmother spiders)
Roshan.
Denying towers.


[h1] == Known issues ==[/h1]
Picking may over-select for core roles.
Middle lane may have a difficult time outplaying the opposing mid -- much better in safe or offlane where they can trade.
Some tasks are not well informed by threat analytics code, not all tasks use intelligent movement functions to adjust vectors around dangerous areas.
Junk is not correctly sold (DotaBuff meta parser is not complete, and there may be additional junk buys incorrectly parsed into the build, item builds are calculated for their combines, however, the junk is incorrectly evaluated and the wrong item may be sold when 9-slotted).

Many other things.

Runes for full-takeover bots:
[h1] -- bottom water runes cannot be picked up.[/h1]
[h1] -- river bounty runes cannot be picked up.[/h1]
[h1] -- any runes that are stacked up on by another bounty rune cannot be picked up.[/h1]
These three rune issues are all technically true, but there is a workaround in place. During the early stage of the game, the bots run as a partial takeover bot, all modes are set to do nothing, ability_item_usage state is set to 100% desire, and the bots use that as a hook to the full-takeover code. When they stand next to a rune, rune mode is engaged for a split second, in the hope that they will pick up the bounty rune. Once the runes are picked up, or after a short while, a handover is completed to cut the default bot code off completely and the bot_generic Think function is defined.


[h1] == Project State ==[/h1]
Alpha version. Please give feedback.
Is the project currently stable: Experimental, updated for 7.34c 19/09/23 (September 19)
Last DotaBuff meta update: 19/09/23


[h1] == Support ==[/h1]
Please shoot me an email for any questions or to support the project: 
zyewchi@gmail.com

If you would like to support the project, my paypal is on the above email with the goofy robot icon. Support means I can justify more time to make them better. But also just a nice comment on the workshop page helps a lot.

[h1] == Dev contact ==[/h1]
Michael - zyewchi@gmail.com
