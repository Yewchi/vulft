## VULFT


VULFT - Kabuuang Takeover Bot Script na may dynamic na pag-uugali ng labanan. DotaBuff papel at imbentaryo build sequences ay na update sa: 19/03/23. Nangangailangan ng manu manong pag install sa vscripts / bots folder (may kasalukuyang problema sa Dota workshop sa mga bagong bot). Ang VUL-FT ay hindi kaakibat ng DotaBuff.



##  Pagsasalin 

Ang pagpapanatili ng pagsasalin na ito ay tumatagal ng mahabang panahon para sa akin, mga 30 minuto. Kailangan kong bumalik sa programming, kaya maaaring hindi na napapanahon ang file na ito. Kung ang proseso ng pag install ng bot ay kailanman naayos at hindi na kinakailangan, pagkatapos ay babalik ako upang i update ang dokumentong ito. Tingnan ang pahina ng workshop sa Ingles para sa kasalukuyang petsa ng pagtatayo ng DotaBuff at petsa ng paglabas ng software.



##  Manu manong pag install 

Ang VUL-FT ay kasalukuyang hindi gagana sa pamamagitan lamang ng pag-subscribe. Ito ay magpapatakbo lamang ng mga default na bot sa halip, ang iba pang mga kamakailang inilabas na mga bot ay may parehong isyu. Sa ngayon, kailangan manu manong i install ang mga bot.



Opsyonal: Bago itakda ang VUL-FT bilang lokal na dev script, Maaari ring magandang ideya na i-backup ang iyong lumang folder na 'vscript/bots' kung mayroon kang ibang bot na naimbak mo roon:

Ang lokal na folder ng dev bot ay matatagpuan sa

[drive]:/%Program Files%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots

0) palitan ang pangalan ng folder ng bots sa bots.old.

1) gumawa ng bagong folder na may pangalang bots

2) kopyahin ang mga file ng VUL-FT mula sa github o sa folder ng workshop sa bagong folder ng mga bot.



-- O gamit ang Github: (na-update ng lumikha)

Kung alam mo kung paano gamitin ang git maaari mong manu manong i download ang mga bot mula sa [official VUL-FT Github](https://github.com/yewchi/vulft) at ilagay ang mga ito sa

[drive]:/%Program Files%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots/



-- Pagsisimula ng tugma:

Matapos makumpleto ang isa sa mga hakbang sa itaas, maaari mong patakbuhin ang mga bot sa pamamagitan ng pag navigate sa in game upang

Custom Lobbies -> Create -> Edit:

Sa ilalim ng BOT SETTINGS baguhin ang mga bot ng koponan sa Lokal na Dev Script (kung nais mo pa ring labanan ang mga bot ng Valve, tandaan na mayroong isang pagpipilian para sa "Default Bots" dito rin)

Baguhin ang SERVER LOCATION sa LOCAL HOST (ang iyong computer).

Ang Easy mode o Unfair ay walang epekto pa, ngunit ang Unfair ay maaaring dagdagan ang passive gold ng bot.

Pindutin ang OK.

Sumali sa unang slot ng alinman sa koponan.

Pindutin ang START GAME.



Bilang kahalili, maaari mong gamitin ang "Play VS Bots" na pagpipilian ngunit hindi lahat ng mga bayani ay ipinatupad.



## Mga Tampok

- Dynamic labanan paggawa ng desisyon.

- Higit pang mga tulad ng tunay na mga manlalaro.

- Sila ay nagsisimula upang ilipat kaagad pagkatapos ng release ng isang atake.

- Advanced na pamamahala ng imbentaryo.

- Awtomatikong nabuo tagamasid highground ward lokasyon, para sa kung ang mapa kailanman ay nagbabago.

- DotaBuff parser para sa average out ng 5 laro kasanayan build, mga tungkulin at isang item build mula sa Divine - Imortal na mga manlalaro sa linggong iyon.

- Basic halimaw pangangaso sa kanilang libreng oras.

- Maaari nilang tanggihan ang kaaway mula sa pagkuha ng isang pumatay sa maagang laro sa pamamagitan ng pagbibigay ng isang gubat halimaw ang huling pag-atake.

- Dynamic urong, sa friendly tower (maliban kung ang tower ay makakakuha ng masyadong masikip), o sa friendly na mga kaalyado sa direksyon ng allied fountain.

- Bounty rune task allocation batay sa kalapitan, kaligtasan, fog, kasakiman rating - Tower pagtatanggol allocation batay sa labanan kahirapan.

- Mas mababang paggamit ng CPU kaysa sa iba pang mga popular na bot.

- Software bugs! :)



Ngunit din, ipinapangako ko ang code ng proyektong ito ay 100% functional offline at mananatili sa ganoong paraan. Walang networking API ang gagamitin ng codebase na ito, kailanman.



## Ulat ng Pagkakamali

[ Lua Error Dump (steam discussion link)](https://steamcommunity.com/workshop/filedetails/discussion/2872725543/3648503910213521285/) -- Gamitin ito kung nais mong kopyahin nang mabilis ang ilang mensahe ng error mula sa console log.

[ VUL-FT source code](https://github.com/Yewchi/vulft) -- Public github



## Mga Kilalang Isyu

Ang bahaging ito ay napakahirap isalin, paumanhin!



Ang lahat ng mga bagong gintong bounty grabbable entity at tubig ilog entity ipinakilala minsan sa 7.x ay hindi kasalukuyang magagawang upang ma pick up sa pamamagitan ng kabuuang override bot script. Kabilang dito ang mas bagong tampok ng mga entity ng bounty stacking ontop ng isa't isa. Gayundin, tanging ang pinakahuling lumitaw bounty entity ay maaaring kolektahin. Ang isang workaround ay nasa lugar bago ang trombone ng digmaan sa 0:00 upang payagan ang mga bot na kunin ang mga ito, gayunpaman, ang workaround ay nagiging sanhi ng mga bot na maluwag ang kabuuang kontrol ng kanilang imbentaryo, at kaya ito ay inalis pagkatapos ng sungay sa tungkol sa 0:30



## Estado ng Proyekto

Bersyon ng alpha. Magbigay po kayo ng feedback.

Ang proyekto ba ay kasalukuyang matatag: Matatag, walang mga pag crash ng laro o script breaking sa paglipas ng 10 tugma bilang ng 30/03/23 (Marso 30)

Huling DotaBuff meta update: Mangyaring suriin ang mga petsa ng pahina ng workshop sa Ingles.



## Dev kontak

zyewchi@gmail.com

