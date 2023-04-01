VULFT - Full Takeover Bot Script. Highly dynamic fight behaviour. DotaBuff roles and item builds updated on: 19/03/23. Requires manual install into vscripts/bots folder (all recently released bots have this issue). VUL-FT has no affiliation with DotaBuff.<br/>
<br/>
[Translations of This Page in Other Languages](https://github.com/Yewchi/vulft/blob/main/TRANSLATION.md)<br/>
<br/>
##== Manually installing ==<br/>
VUL-FT currently will not work via subscription. It will revert to the default bots, it seems other recent bots have the same issue. I'm still investigating what is going wrong there. For now, it's necessary to manually install the bots.<br/>
<br/>
Optional: Before setting VUL-FT as the local dev script, It may also be a good idea to backup your old 'vscript/bots' folder if you have another bot that you have stored there:<br/>
The local dev bot folder is located at<br/>
[drive]:/%Program Files%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots<br/>
0) rename bots folder to bots.old.<br/>
1) make a new folder named bots<br/>
2) copy the VUL-FT files from either github or the workshop folder into the new bots folder.<br/>
<br/>
###-- Via workshop local files: (the Valve-verified workshop files)<br/>
After freshly subscribing, find the recent folder in<br/>
[drive]:/%Program Files%/Steam/steamapps/workshop/content/570/2872725543<br/>
and copy the contents of that folder to the bots folder at<br/>
[drive]:/%Program Files%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots/<br/>
<br/>
###-- Via Github: (updated by the creator)<br/>
If you know how to use git you can manually download the bots from the [official VUL-FT Github](https://github.com/Yewchi/vulft) and put them in<br/>
[drive]:/%Program Files%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots/<br/>
<br/>
###-- Running:<br/>
After one of the above steps are complete, you can run the bots by navigating in-game to<br/>
Custom Lobbies -> Create -> Edit:<br/>
Under BOT SETTINGS change team bots to Local Dev Script (if you still want to fight the Valve bots, note that there is an option for "Default Bots" here as well)<br/>
Change SERVER LOCATION to LOCAL HOST (your computer).<br/>
Difficulty has no effect yet.<br/>
Press OK.<br/>
Join the top slot of either team.<br/>
Press START GAME.<br/>
<br/>
Alternatively, you may use "Play VS Bots" option but not all heroes are implemented. Sorry about all of this, but it is just the effect of having to run the bots as a dev, rather than via the workshop.<br/>
<br/>
##==Features==<br/>
![Animated gif of VUL-FT engaged in a teamfight](https://steamuserimages-a.akamaihd.net/ugc/2028349340710795317/22D68EA70AEF6E343BBE3EBD5F1A3EF1C52F5A04/?imw=5000&imh=5000&ima=fit&impolicy=Letterbox&imcolor=%23000000&letterbox=false)<br/>
Dynamic fight decision making.<br/>
More player-like.<br/>
![Animated gif of Muerta bot running from orb walking enemies](https://steamuserimages-a.akamaihd.net/ugc/2009206964554280836/186F1E4C8B555F0D06352C96399941EBBD9A29E5/?imw=5000&imh=5000&ima=fit&impolicy=Letterbox&imcolor=%23000000&letterbox=false)<br/>
Orb Walking.<br/>
Advanced item management.<br/>
Automatically generated and filtered for error ward locations, if the map ever changes.<br/>
DotaBuff parser for averaged out of 5 game skill build, roles and an item build from Divine - Immortal players that week.<br/>
Basic jungling in downtime.<br/>
They may jungle self-deny in the early game if they get caught by the enemy.<br/>
Dynamic retreat, to friendly towers (unless the tower gets overrun), or to friendly allies in the direction of the allied fountain.<br/>
Bounty rune task allocation based on proximity, safety, fog, greed rating<br/>
Tower defense allocation based on required threat. (No 5-man deathballs because you looked rudely at a tower).<br/>
Lower CPU usage than other popular bots.<br/>
Bugs!<br/>
<br/>
In addition. I promise this project's code is 100% functional offline and will stay that way. No networking API functions, ever.<br/>
<br/>
##==Error Report==<br/>
[Lua Error Dump (steam discussion link)](https://steamcommunity.com/workshop/filedetails/discussion/2872725543/3648503910213521285/) -- Use this if you just want to quickly dump some console output.<br/>
[VUL-FT source code](https://github.com/Yewchi/vulft) -- Public github<br/>
<br/>
##==Not yet implemented==<br/>
The player can only choose their lane and role in the first 30 seconds of a match.<br/>
Macro fight behaviour, initiator choice, grander strats like cutting losses, trading towers. They will assess the current aggressive plays being made and see if they think it's worth it for themselves, if an enemy is occupied attacking someone else. Enemy fight intent is tracked and loses magnitude based on facing direction, this allows allies to recognize trading without being attacked.<br/>
Player-to-bot ping communication.<br/>
Enemy vision assessments.<br/>
Dewarding.<br/>
Sentry and dust for enemy stealth.<br/>
Outposts.<br/>
Illusions are controlled by default behaviour. (But arc warden double is full-takeover).<br/>
Enemy fountain threat.<br/>
Avoid zones.<br/>
Response types for ability casts. (Rupture: Avoid unnecessary movement)<br/>
Structural enemy unit-health units. (tombstone, supernova)<br/>
Attacking and avoiding hero creep units. (Lycan wolves, Broodmother spiders)<br/>
Roshan.<br/>
Denying towers.<br/>
<br/>
##==Known issues==<br/>
Picking may over-select for core roles.<br/>
Middle lane may have a difficult time outplaying the opposing mid -- much better in safe or offlane where they can trade.<br/>
Some tasks are not well informed by threat analytics code, not all tasks use intelligent movement functions to adjust vectors around dangerous areas.<br/>
Junk is not correctly sold (DotaBuff meta parser is not complete, and there may be additional junk buys incorrectly parsed into the build, item builds are calculated for their combines, however, the junk is incorrectly evaluated and the wrong item may be sold when 9-slotted).<br/>
<br/>
Many other things.<br/>
<br/>
Runes for full-takeover bots:<br/>
###-- bottom water runes cannot be picked up.<br/>
###-- river bounty runes cannot be picked up.<br/>
###-- any runes that are stacked up on by another bounty rune cannot be picked up.<br/>
These three rune issues are all technically true, but there is a workaround in place. During the early stage of the game, the bots run as a partial takeover bot, all modes are set to do nothing, ability_item_usage state is set to 100% desire, and the bots use that as a hook to the full-takeover code. When they stand next to a rune, rune mode is engaged for a split second, in the hope that they will pick up the bounty rune. Once the runes are picked up, or after a short while, a handover is completed to cut the default bot code off completely and the bot_generic Think function is defined.<br/>
<br/>
##==Project State==<br/>
Alpha version. Please give feedback.<br/>
Is the project currently stable: Stable, no game crashes or script breaking over 10 matches 30/03/23 (March 30)<br/>
Last DotaBuff meta update: 19/03/23<br/>
<br/>
##==Dev contact==<br/>
zyewchi@gmail.com<br/>
