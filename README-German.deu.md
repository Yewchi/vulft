## VULFT


VULFT - Total Override Bot Script. Hochdynamisches Kampfverhalten. DotaBuff-Rollen und Inventar-Build-Sequenzen werden aktualisiert am: 19/03/23. Erfordert eine manuelle Installation in den Ordner vscripts / bots (wie Phalanx Bot und andere aktuelle Bots aufgrund eines Dota-Workshop-Fehlers). VUL-FT ist nicht mit DotaBuff verbunden.



##  Einzelnachweise 

Das Übersetzen dauert bei mir sehr lange, etwa 30 Minuten. Ich muss zurück zur Programmierung, daher ist diese Datei möglicherweise veraltet. Wenn der manuelle Installationsprozess behoben ist und nicht mehr benötigt wird, werde ich dieses Dokument aktualisieren. Auf der englischen Workshop-Seite finden Sie das aktuelle DotaBuff-Erstellungsdatum und das Veröffentlichungsdatum der Software.



##  Manuelle Installation 

VUL-FT funktioniert derzeit nicht, wenn Sie nur abonnieren. Es wird auf die Standard-Bots zurückgesetzt, andere kürzlich veröffentlichte Bots haben das gleiche Problem. Im Moment ist es notwendig, die Bots manuell zu installieren.



Optional: Bevor Sie VUL-FT als lokales Dev-Skript festlegen, kann es auch eine gute Idee sein, Ihren alten Ordner "vscript / bots" zu sichern, wenn Sie einen anderen Bot haben, den Sie dort gespeichert haben:

Der lokale Dev-Bot-Ordner befindet sich unter

[Laufwerk]:/%Program Files%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots

0) Benennen Sie den Bots-Ordner in bots.old um.

1) Erstellen Sie einen neuen Ordner mit dem Namen bots

2) Kopieren Sie die VUL-FT-Dateien entweder von GitHub oder dem Workshop-Ordner in den neuen Bots-Ordner.



-- Mit den lokalen Werkstattdateien: (die von Valve verifizierten Werkstattdateien)

Nachdem Sie VULFT im Spiel oder im Workshop frisch heruntergeladen haben, finden Sie den letzten Ordner in

[Laufwerk]:/%Programme%/Steam/steamapps/workshop/content/570/2872725543

und kopieren Sie den Inhalt dieses Ordners in den Bots-Ordner unter

[Laufwerk]:/%Program Files%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots/



-- Oder mit Github: (vom Ersteller aktualisiert)

Wenn Sie wissen, wie man Git verwendet, können Sie die Bots manuell von [official VUL-FT Github](https://github.com/yewchi/vulft) herunterladen und in

[Laufwerk]:/%Program Files%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots/



-- Starten eines Spiels:

Nachdem einer der oben genannten Schritte abgeschlossen ist, können Sie die Bots ausführen, indem Sie im Spiel navigieren zu Benutzerdefinierte Lobbys -> Erstellen -> Bearbeiten:

Ändern Sie unter BOT SETTINGS Team Bots auf Local Dev Script (wenn Sie die Valve-Bots weiterhin bekämpfen möchten, beachten Sie, dass es auch hier eine Option für "Default Bots" gibt)

Ändern Sie SERVER LOCATION in LOCAL HOST (Ihr Computer).

Der einfache Modus oder Unfair hat noch keine Wirkung, aber Unfair kann das passive Gold des Bots erhöhen.

Klicken Sie auf OK.

Treten Sie dem ersten Slot eines der beiden Teams bei.

Drücken Sie SPIEL STARTEN.



Alternativ können Sie die Option "VS Bots spielen" verwenden, aber nicht alle Helden sind implementiert.



##  Funkitonnen 

- Dynamische Kampfentscheidung.

- Eher wie echte Spieler.

- Sie beginnen sich sofort nach dem Auslösen eines Angriffs zu bewegen.

- Erweiterte Bestandsverwaltung.

- Automatisch generierte Beobachter-Standorte für den Fall, dass sich die Karte jemals ändert.

- DotaBuff-Parser für durchschnittlich 5 Spiel-Skill-Builds, Rollen und einen Item-Build von Divine - Unsterblichen Spielern in dieser Woche.

- Grundlegende Monsterjagd in ihrer Freizeit.

- Sie können dem Feind im frühen Spiel einen Kill verwehren, indem sie einem Dschungelmonster den letzten Angriff geben.

- Dynamischer Rückzug, zu befreundeten Türmen (es sei denn, der Turm wird zu voll) oder zu befreundeten Verbündeten in Richtung des alliierten Brunnens.

- Kopfgeld-Runen-Aufgabenverteilung basierend auf Nähe, Sicherheit, Nebel, Gier - Tower-Defense-Zuteilung basierend auf dem Schwierigkeitsgrad des Kampfes.

- Geringere CPU-Auslastung als bei anderen beliebten Bots.

- Software-Bugs! :)



Aber ich verspreche auch, dass der Code dieses Projekts offline zu 100% funktionsfähig ist und so bleiben wird. Keine Netzwerk-API wird von dieser Codebasis verwendet, niemals.



##  Fehlerberichte 

[ Lua Error Dump (Steam-Diskussionslink)](https://steamcommunity.com/workshop/filedetails/discussion/2872725543/3648503910213521285/) -- Verwenden Sie diese Option, wenn Sie einige Fehlermeldungen schnell aus dem Konsolenprotokoll kopieren möchten.

[ VUL-FT-Quellcode ](https://github.com/yewchi/vulft) -- Öffentlicher Github



##  Bekannte Probleme 

Dieser Abschnitt ist sehr schwer zu übersetzen, sorry!



Alle neuen Gold-Bounty-Grabbable-Entitäten und Wasserfluss-Entitäten, die irgendwann in 7.x eingeführt wurden, können derzeit nicht von Bot-Skripten mit vollständiger Überschreibung abgeholt werden. Dazu gehört auch die neuere Funktion von Bounty-Entitäten, die übereinander gestapelt werden. Außerdem kann nur die zuletzt erschienene Bounty-Einheit gesammelt werden. Ein Workaround ist vor der Posaune des Krieges um 0:00 Uhr vorhanden, damit die Bots sie abholen können, aber der Workaround führt dazu, dass die Bots die vollständige Kontrolle über ihr Inventar verlieren, und so wird es nach dem Horn um etwa 0:30 Uhr entfernt



##  Projektstatus 

Alpha-Version. Bitte geben Sie uns Feedback.

Ist das Projekt derzeit stabil: Stabil, keine Spielabstürze oder Skriptbrüche über 10 Spiele am 30.03.23 (30. März)

Letztes DotaBuff-Meta-Update: Bitte überprüfen Sie die Daten der englischen Workshop-Seite.



##  Einzelnachweise 

zyewchi@gmail.com

