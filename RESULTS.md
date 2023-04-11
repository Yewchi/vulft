### Code
```Lua
Think = function()
	if RandomInt(1,10) == 10 then
		print(GetBot():GetPlayerID(), "tries grab", GetBot():GetPlayerID() % 6)
		GetBot():Action_PickUpRune(GetBot():GetPlayerID() % 6)
	end
end
```

### Player Tbl
| Team | Number On Team | PlayerID |
| :---: | :---: | :---: |
| Radiant | 1 | 0 |
| Radiant | 2 | 1 |
| Radiant | 3 | 2 |
| Radiant | 4 | 3 |
| Radiant | 5 | 4 |
| Dire | 1 | 5 |
| Dire | 2 | 6 |
| Dire | 3 | 7 |
| Dire | 4 | 8 |
| Dire | 5 | 9 |

## Results of Test
 In 7.32e, May 8, 2023.
In a fresh instance of Dota 2 that had not yet loaded a bot match.
### minus 1:30
	Bots stand still in fountain.
### 0:00
	Goes and grabs top bounty: PID#2, PID#8.

	Goes and grabs bot bounty: PID#3, PID#9.

	River bounties are ignored.
### 2:00
	Goes and grabs top water rune: PID#0, PID#1, PID#6.

	Bottom river bounty is ignored.

	The top river bounty rune is not picked up.

### 3:00
	Same action as 0:00

### 4:00 
	Same action as 2:00

### 6:00
	Same action as 0:00

	An arcane rune spawns bottom.

	Goes and grabs bot power rune: PID#0, PID#1, PID#6

	PID#7 exits fountain to grab the arcane rune once PID#6 reveals it with hero vision.

	The bottom river bounty rune is not picked up.

### 8:00
	A haste rune spawns top.

	Goes and grabs top power rune: PID#0, PID#1, PID#7 (seven)

	PID#6 leaves bot power rune to grab the haste rune once PID#6 reveals it with hero vision. (six)

	(Radiant heroes PID#0 and PID#1 die to lane creeps)

### 9:00
	Same action as 0:00

### 10:00
	An invis rune spawns bot.

	Goes and grabs bot power rune: PID#6.

	PID#7 leaves top power rune to grab the invis rune once PID#6 reveals it with hero vision.

	PID#0 and PID#1 are alive in the fountain and stay in the fountian.


### 12:00
	Same action as 0:00
	
	Same action as 8:00 from Dire.

	(PID#6 and PID#7 die to lane creeps at top rune)

### 14:00
	All players respawned in fountain ignore rune.

### 15:00
	Same action as 0:00

### 16:00
	All players respawned in fountain ignore bot regen rune.

### 18:00
	Same action as 0:00

	All players respawned in fountain ignore top invis rune with:

> [VScript] Rune status:	-1	0</br>
> [VScript] Rune status:	0	0</br>
> [VScript] Rune status:	1	0</br>
> [VScript] Rune status:	2	2</br>
> [VScript] Rune status:	3	2</br>
> [VScript] Rune status:	4	0</br>
> [VScript] Rune status:	5	0</br>
> [VScript] Rune status:	6	0</br>
> [VScript] Rune status:	7	0</br>
> </br>
> [VScript] POWERUP1	0	POWERUP2	1	BOUNTY1	2	BOUNTY2	3	BOUNTY3	4	BOUNTY4	5</br>
> [VScript] 5	tries grab	5</br>
> [VScript] POWERUP1	0	POWERUP2	1	BOUNTY1	2	BOUNTY2	3	BOUNTY3	4	BOUNTY4	5</br>
> [VScript] 6	tries grab	0</br>
> [VScript] POWERUP1	0	POWERUP2	1	BOUNTY1	2	BOUNTY2	3	BOUNTY3	4	BOUNTY4	5</br>
> [VScript] 7	tries grab	1</br>
> [VScript] POWERUP1	0	POWERUP2	1	BOUNTY1	2	BOUNTY2	3	BOUNTY3	4	BOUNTY4	5</br>
> [VScript] 8	tries grab	2</br>
> [VScript] POWERUP1	0	POWERUP2	1	BOUNTY1	2	BOUNTY2	3	BOUNTY3	4	BOUNTY4	5</br>
> [VScript] 9	tries grab	3</br>
> [VScript] POWERUP1	0	POWERUP2	1	BOUNTY1	2	BOUNTY2	3	BOUNTY3	4	BOUNTY4	5</br>
> [VScript] 0	tries grab	0</br>
> [VScript] POWERUP1	0	POWERUP2	1	BOUNTY1	2	BOUNTY2	3	BOUNTY3	4	BOUNTY4	5</br>
> [VScript] 1	tries grab	1</br>
> [VScript] POWERUP1	0	POWERUP2	1	BOUNTY1	2	BOUNTY2	3	BOUNTY3	4	BOUNTY4	5</br>
> [VScript] 2	tries grab	2</br>
> [VScript] POWERUP1	0	POWERUP2	1	BOUNTY1	2	BOUNTY2	3	BOUNTY3	4	BOUNTY4	5</br>
> [VScript] 3	tries grab	3</br>
> [VScript] POWERUP1	0	POWERUP2	1	BOUNTY1	2	BOUNTY2	3	BOUNTY3	4	BOUNTY4	5</br>
> [VScript] 4	tries grab	4</br>


### 18:00+
	Behaviour repeats
