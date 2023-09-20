VULFT - Full Takeover Bot Script. Requires manual install into vscripts/bots folder (all recently released bots have this issue). Highly dynamic fight behaviour. DotaBuff roles and item builds updated on: 19/09/23. VUL-FT has no affiliation with DotaBuff.<br/>
<br/>
[Translations of This Page in Other Languages](https://steamcommunity.com/groups/VULFT/announcements/detail/6966546241858334331)<br/>
<br/>

## == Manually installing ==
VUL-FT currently will not work via subscription. It will revert to the default bots, it seems other recent bots have the same issue. I'm still investigating what is going wrong there. For now, it's necessary to manually install the bots.<br/>
<br/>
Optional: Before setting VUL-FT as the local dev script, It may also be a good idea to backup your old 'vscript/bots' folder if you have another bot that you have stored there:<br/>
The local dev bot folder is located at<br/>
> [drive]:/%Program Files%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots<br/>

0) rename bots folder to bots.old.<br/>
1) make a new folder named bots<br/>
2) copy the VUL-FT files from either github or the workshop folder into the new bots folder.<br/>
<br/>

### -- Via workshop local files: (the Valve-verified workshop files)
After freshly subscribing, find the recent folder in<br/>
> [drive]:/%Program Files%/Steam/steamapps/workshop/content/570/2872725543<br/>

and copy the contents of that folder to the bots folder at<br/>
> [drive]:/%Program Files%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots/<br/>
<br/>

### -- Via Github: (updated by the creator)
If you know how to use git you can manually download the bots from the [official VUL-FT Github](https://github.com/Yewchi/vulft) and put them in
> [drive]:/%Program Files%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots/<br/>
<br/>

### -- Running:
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

## == Features ==

![Animated gif of VUL-FT engaged in a teamfight](https://steamuserimages-a.akamaihd.net/ugc/2028349340710795317/22D68EA70AEF6E343BBE3EBD5F1A3EF1C52F5A04/?imw=5000&imh=5000&ima=fit&impolicy=Letterbox&imcolor=%23000000&letterbox=false)

Dynamic fight decision making.<br/>
More player-like.<br/>

![Animated gif of Muerta bot running from orb walking enemies](https://steamuserimages-a.akamaihd.net/ugc/2009206964554280836/186F1E4C8B555F0D06352C96399941EBBD9A29E5/?imw=5000&imh=5000&ima=fit&impolicy=Letterbox&imcolor=%23000000&letterbox=false)

Orb Walking.<br/>
Advanced item management.<br/>
Automatically generated and filtered for error ward locations, if the map ever changes.<br/>
DotaBuff parser for averaged out of 5 game skill build, roles and an item build from Divine - Immortal players that week.<br/>
Basic jungling in downtime.<br/>
They may jungle self-deny in the early game if they get caught by the enemy.<br/>
Dynamic retreat, to friendly towers (unless the tower gets overrun), or to friendly allies in the direction of the allied fountain.<br/>
Bounty rune task allocation based on proximity, safety, fog, greed rating<br/>
Tower defense allocation based on required threat.<br/>
Choose your position whenever by saying in chat "!pos [1-5]"
Lower CPU usage than other popular bots.<br/>
Bugs!<br/>
<br/>
In addition. I promise this project's code is 100% functional offline and will stay that way. No networking API functions, ever.<br/>
<br/>

## == Error Report ==
[Lua Error Dump (steam discussion link)](https://steamcommunity.com/workshop/filedetails/discussion/2872725543/3648503910213521285/) -- Use this if you just want to quickly dump some console output.

[VUL-FT source code](https://github.com/Yewchi/vulft) -- Public github

## == Not yet implemented ==
Macro fight behaviour, initiator choice, grander strats like cutting losses, trading towers. They will assess the current aggressive plays being made and see if they think it's worth it for themselves, if an enemy is occupied attacking someone else. Enemy fight intent is tracked and loses magnitude based on facing direction, this allows allies to recognize trading without being attacked.<br/>
Player-to-bot ping communication.<br/>
Enemy vision assessments.<br/>
Dewarding.<br/>
Sentry and dust for enemy stealth.<br/>
Illusions are controlled by default behaviour. (But arc warden double is full-takeover).<br/>
Enemy fountain threat.<br/>
Avoid zones.<br/>
Response types for ability casts. (Rupture: Avoid unnecessary movement)<br/>
Structural enemy unit-health units. (tombstone, supernova)<br/>
Attacking and avoiding hero creep units. (Lycan wolves, Broodmother spiders)<br/>
Roshan.<br/>
Denying towers.<br/>
<br/>

## == Known issues ==
Picking may over-select for core roles.<br/>
Some tasks are not well informed by threat analytics code, not all tasks use intelligent movement functions to adjust vectors around dangerous areas.<br/>
Junk is not correctly sold (DotaBuff meta parser is not complete, and there may be additional junk buys incorrectly parsed into the build, item builds are calculated for their combines, however, the junk is incorrectly evaluated and the wrong item may be sold when 9-slotted).<br/>
Bots do not leave lanes which are dangerous if farming them. They only retreat. The untested data is there for changing lanes but mid-game rotating is not coded, it only happens naturally as they move / getting runes / defending towers / sometimes by jungling. The score of the creep wave draws them in too strongly. <br/>
Overly aggressive, especially in the early game.<br/>
Bots might not be able to commit to a highground push, due to certain variables in the state of the creep wave, they might wander off out of push range instead.<br/>
<br/>
Many other things.<br/>
<br/>
Runes for full-takeover bots:<br/>
### -- bottom water runes cannot be picked up.
### -- river bounty runes cannot be picked up.
### -- any runes that are stacked up on by another bounty rune cannot be picked up.
These three rune issues are all technically true, but there is a workaround in place. During the early stage of the game, the bots run as a partial takeover bot, all modes are set to do nothing, ability_item_usage state is set to 100% desire, and the bots use that as a hook to the full-takeover code. When they stand next to a rune, rune mode is engaged for a split second, in the hope that they will pick up the bounty rune. Once the runes are picked up, or after a short while, a handover is completed to cut the default bot code off completely and the bot_generic Think function is defined.<br/>
<br/>

## == Project State ==
Alpha version. Please give feedback.<br/>
Is the project currently stable: Experimental, updated for 7.34c 19/09/23 (September 19)<br/>
Last DotaBuff meta update: 19/09/23<br/>
<br/>

## == Support ==
Please shoot me an email for any questions or to support the project: <br/>
zyewchi@gmail.com<br/>

If you would like to support the project, my paypal is on the above email with the goofy robot icon. Support means I can justify more time to make them better. But also just a nice comment on the workshop page helps a lot.

## == Dev contact ==
Michael - zyewchi@gmail.com<br/>
