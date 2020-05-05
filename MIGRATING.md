# English Version

The following describes the migration from KIX 2016 to KIX 2017. It's absolutely necessary to fulfill all the requirements and to follow the steps.  

## Requirements

* the KIX 2016 system uses the same DBMS like KIX 2017 (PostgreSQL, MariaDB or MySQL)
* the KIX 2016 is updated to the newest version (16.1.0)
* the KIX database must be local

# Steps

* stop the daemon in the KIX 2016 system
 * ```sudo -u www-data <KIX2016-Home>/bin/otrs.Daemon.pl stop```
* stop cronjobs in the KIX 2016 system
 * ```<KIX2016 Home>/bin/Cron.sh stop <apache user>```
* stop apache
* go to the KIX 2017 application directory 
 * ```cd /opt/kix``` 
* execute migration script
 * ```scripts/migrate_kix16.sh```
  * follow the instuctions
  * wait... 
* copy special config from your KIX 2016 Config.pm to KIX 2017 Config.pm
 * copy your old SystemID to the SystemID config attribute in the KIX 2017 Config.pm 
 * do not change the rest of the existing KIX 2017 config! 
* deactivate mod_perl
 * this is only necessary if you want to work in both systems
* start apache
* re-install the remaining installed packages using the console package manager
 * ```sudo -u <apache user> /opt/kix/bin/kix.Console.pl Admin::Package::Reinstall --force <package name>```
* copy article attachments in the filesystem from KIX 2016 installation to KIX 2017
 * ```cp -rvp <KIX2016-Home>/var/article /opt/kix/var```
* if exists, copy CI images in the filesystem from KIX 2016 installation to KIX 2017
 * ```cp -rvp <KIX2016-Home>/var/ITSMConfigItem /opt/kix/var```
* if exists, copy CI attribute attachments in the filesystem from KIX 2016 installation to KIX 2017
 * ```cp -rvp <KIX2016-Home>/var/attachments /opt/kix/var```
* rebuild Config
* clear caches
* reload apache
* check cronjobs in KIX system
 * copy special cronjobs and adjust and validate configuration
* start cronjobs in KIX 2017 system
 * ```/opt/kix/bin/Cron.sh start <apache user>```
* start daemon in KIX 2017 system
 * ```sudo -u www-data /opt/kix/bin/kix.Daemon.pl start```

# Deutsche Version

Im Folgenden wird das Vorgehen für die Migration von KIX 2016 auf KIX 2017 beschrieben. Es ist zwingend notwendig, die Voraussetzungen zu erfüllen und die Schritte einzuhalten. 

## Voraussetzungen
* das KIX 2016 System verwendet das gleiche DBMS wie KIX 2017 (PostgreSQL, MariaDB oder MySQL) 
* das KIX 2016 ist auf der aktuellsten Version (16.1.0)
* die KIX-Datenbank muss lokal installiert sein

## Vorgehen

* Daemon in KIX 2016 System stoppen
 * ```sudo -u www-data <KIX2016-Home>/bin/otrs.Daemon.pl stop```
* Cronjobs in KIX 2016 System stoppen
 * ```<KIX2016-Home>/bin/Cron.sh stop <Apache-Nutzer>```
* Apache stoppen
* ins KIX 2017 Verzeichnis wechseln
 * ```cd /opt/kix``` 
* Migrationsscript ausführen
  * ```scripts/migrate_kix16.sh```
   * Instruktionen folgen
   * warten... 
* spezielle Konfigurationen aus der alten Config.pm in die neue Config.pm von KIX übertragen
 * die alte SystemID in das SystemID-Config-Attribut der KIX Config.pm kopieren 
 * nicht die restliche bestehende KIX-Konfiguration überschreiben!  
* mod_perl deaktivieren
 * nur notwendig, falls man parallel in KIX 2016 und KIX 2017 arbeiten will
* Apache starten 
* abschließend die übrigen installierten Pakete im Paket-Manager auf der Console re-installieren
 * ```sudo -u <apache user> /opt/kix/bin/kix.Console.pl Admin::Package::Reinstall --force <package name>```
* die Artikel-Attachments im Dateisystem von der alten KIX-Installation nach KIX 2017 kopieren
 * ```cp -rvp <KIX2016-Home>/var/article /opt/kix/var```
* falls vorhanden, die CI-Bilder im Dateisystem von der alten KIX-Installation nach KIX 2017 kopieren
 * ```cp -rvp <KIX2016-Home>/var/ITSMConfigItem /opt/kix/var```
* falls vorhanden, die CI-Attribute-Attachments im Dateisystem von der alten KIX-Installation nach KIX kopieren
 * ```cp -rvp <KIX2016-Home>/var/attachments /opt/kix/var```
* Config rebuild
* Caches löschen
* Apache reload
* Cronjobs in KIX 2017 System prüfen
 * spezielle Cronjobs übertragen und Konfiguration prüfen und ggf. anpassen
* Cronjobs in KIX 2017 System starten
 * ```/opt/kix/bin/Cron.sh start <Apache-Nutzer>```
* Daemon in KIX 2017 System starten
 * ```sudo -u www-data /opt/kix/bin/kix.Daemon.pl start```

