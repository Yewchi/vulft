## VULFT


VULFT - Total Override Bot Script. Comportement de combat très dynamique. Les rôles DotaBuff et les séquences de construction d'inventaire sont mis à jour le : 19/03/23. Nécessite une installation manuelle dans le dossier vscripts/bots (identique à Phalanx Bot et à d'autres bots récents, en raison d'un bogue de l'atelier Dota). VUL-FT n'est pas affilié à DotaBuff.



##  Traduction 

La traduction prend beaucoup de temps pour moi, environ 30 minutes. J'ai besoin de revenir à la programmation, donc ce fichier peut être obsolète. Si le processus d'installation manuelle est corrigé et n'est plus nécessaire, je mettrai à jour ce document. Voir la page de l'atelier en anglais pour la date de construction actuelle de DotaBuff et la date de sortie du logiciel.



##  Installation manuelle 

VUL-FT ne fonctionnera actuellement pas en s'abonnant. Il reviendra aux bots par défaut, d'autres bots récemment publiés ont le même problème. Pour l'instant, il est nécessaire d'installer manuellement les bots.



Facultatif: Avant de définir VUL-FT comme script de développement local, il peut également être judicieux de sauvegarder votre ancien dossier 'vscript/bots' si vous avez un autre bot que vous y avez stocké:

Le dossier local dev bot se trouve à l'emplacement suivant :

[lecteur]:/%Program Files%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots

0) Renommez le dossier bots en bots.old.

1) Créez un nouveau dossier nommé Bots

2) copiez les fichiers VUL-FT de GitHub ou du dossier Workshop dans le dossier New Bots.



-- Via les fichiers locaux de l'atelier : (les fichiers d'atelier vérifiés par Valve)

Après vous être fraîchement abonné, recherchez le dossier récent dans

[lecteur]:/%Program Files%/Steam/steamapps/workshop/content/570/2872725543

et copiez le contenu de ce dossier dans le dossier bots à l'adresse

[lecteur]:/%Program Files%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots/



-- Via Github: (mis à jour par le créateur)

Si vous savez comment utiliser git, vous pouvez télécharger manuellement les bots depuis le [official VUL-FT Github](https://github.com/yewchi/vulft) et les mettre dans

[lecteur]:/%Program Files%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots/



-- Début d'un match :

Une fois l'une des étapes ci-dessus terminée, vous pouvez exécuter les bots en naviguant dans le jeu pour Lobbies personnalisés -> Créer -> Modifier :

Sous BOT SETTINGS changez team bots en Local Dev Script (si vous voulez toujours combattre les bots Valve, notez qu'il existe une option pour « Default Bots » ici aussi)

Remplacez SERVER LOCATION par LOCAL HOST (votre ordinateur).

Le mode facile ou Injuste n'a pas encore d'effet, mais Injuste peut augmenter l'or passif du bot.

Appuyez sur OK.

Rejoignez la première place de l'une ou l'autre équipe.

Appuyez sur DÉMARRER LE JEU.



Alternativement, vous pouvez utiliser l'option « Jouer VS Bots » mais tous les héros ne sont pas implémentés.



##  Fonctionnalités 

- Prise de décision dynamique au combat.

- Plus comme de vrais joueurs.

- Ils commencent à se déplacer immédiatement après avoir lancé une attaque.

- Gestion avancée des stocks.

- Emplacements des quartiers d'observation générés automatiquement, si la carte change.

- DotaBuff parser pour une moyenne sur 5 jeux de compétences, de rôles et d'un élément construit par les joueurs Divin - Immortel cette semaine-là.

- Chasse aux monstres de base pendant leur temps libre.

- Ils peuvent empêcher l'ennemi de tuer au début du jeu en donnant à un monstre de la jungle l'attaque finale.

- Retraite dynamique, vers des tours amies (à moins que la tour ne soit trop encombrée), ou vers des alliés amis en direction de la fontaine alliée.

- Allocation des tâches de runes de prime basée sur la proximité, la sécurité, le brouillard, la cupidité - Allocation de tower defense basée sur la difficulté du combat.

- Utilisation du processeur inférieure à celle des autres robots populaires.

- Bugs logiciels ! :)



Mais aussi, je promets que le code de ce projet est 100% fonctionnel hors ligne et le restera. Aucune API réseau ne sera jamais utilisée par cette base de code.



##  Rapport d'erreur 

[ Lua Error Dump (lien de discussion Steam)](https://steamcommunity.com/workshop/filedetails/discussion/2872725543/3648503910213521285/) -- Utilisez cette option si vous souhaitez copier rapidement certains messages d'erreur du journal de la console.

[ Code source VUL-FT](https://github.com/Yewchi/vulft) -- Github public



##  Problèmes connus 

Cette section est très difficile à traduire, désolé!



Toutes les nouvelles entités récupérables de primes d'or et les entités de rivière d'eau introduites dans 7.x ne peuvent actuellement pas être récupérées par des scripts de bot de remplacement total. Cela inclut la nouvelle fonctionnalité des entités de primes qui s'empilent les unes sur les autres. En outre, seule l'entité de prime la plus récemment apparue peut être collectée. Une solution de contournement est en place avant le trombone de guerre à 0:00 pour permettre aux bots de les ramasser, cependant, la solution de contournement fait perdre aux bots le contrôle total de leur inventaire, et donc il est retiré après le klaxon vers 0:30



##  État du projet 

Version alpha. S'il vous plaît donner des commentaires.

Le projet est-il actuellement stable : Stable, aucun plantage de jeu ou script de rupture de plus de 10 matchs au 30/03/23 (30 mars)

Dernière mise à jour de la méta DotaBuff: Veuillez vérifier les dates de la page de l'atelier en anglais.



##  Contact Dev 

zyewchi@gmail.com

