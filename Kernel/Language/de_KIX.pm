# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Language::de_KIX;

use strict;
use warnings;
use utf8;

sub Data {
    my $Self = shift;
    my $Lang = $Self->{Translation};
    return 0 if ref $Lang ne 'HASH';

    # $$START$$

    # FAQWorkflow...
    $Lang->{'Suggest as FAQ-Entry'} = 'Als FAQ-Eintrag vorschlagen';
    $Lang->{'Defines if the trigger flag at the source ticket/article is reset.'}
        = 'Definiert ob das auslösende Flag am Quellticket/-artikel zurückgesetzt wird.';
    $Lang->{'Defines if the new FAQ-article is linked with the source ticket.'}
        = 'Definiert ob der neue FAQ-Artikel mit dem Quellticket verknüpft wird.';
    $Lang->{'Basic settings for FAQ edit workflow.'}
        = 'Grundlegende Einstellungen für den FAQ-Redaktionsprozess';
    $Lang->{'Enables creation of a FAQ entry from currently created article.'}
        = 'Aktiviert die Erstellung eines FAQ-Eintrags aus dem akt. erzeugtem Artikel.'
        ;
    $Lang->{'KIX: Define the free key field 3 for articles. Its a new article property.'}
        = 'KIX: Definition des FreiSchlüsselFeldes 3 für Artikel. Hierüber kann einen zusätzliches Artikel-Attribut definiert werden.';

    # custom article types...
    $Lang->{'note-workaround-external'} = 'Workaroundbeschreibung (sichtbar für Kunde)';
    $Lang->{'note-workaround-internal'} = 'Workaroundbeschreibung (unsichtbar für Kunde)';
    $Lang->{'note-reason-external'}     = 'Ursachenbeschreibung (sichtbar für Kunde)';
    $Lang->{'note-reason-internal'}     = 'Ursachenbeschreibung (unsichtbar für Kunde)';
    $Lang->{'note-close-external'}      = 'Abschlussnotiz (sichtbar für Kunde)';
    $Lang->{'note-close-internal'}      = 'Abschlussnotiz (unsichtbar für Kunde)';
    $Lang->{'email-notification-ext'}   = 'Email-Benachrichtigung (sichtbar für Kunde)';
    $Lang->{'email-notification-int'}   = 'Email-Benachrichtigung (unsichtbar für Kunde)';
    $Lang->{'fax'}                      = 'Fax (sichtbar für Kunde)';

    # other translations...
    $Lang->{'Hint'}                            = 'Hinweis';
    $Lang->{'Address Book'}                    = 'Adressbuch';
    $Lang->{'Manage address book.'}            = 'Adressbuch verwalten.';
    $Lang->{'Address Book Management'}         = 'Adressbuchverwaltung';
    $Lang->{'Please enter a search term to look for address book entries.'} = 'Bitte geben Sie einen Suchbegriff ein, um nach Einträgen im Adressbuch zu suchen.';
    $Lang->{'Creates a new address book entry if necessary.'} = 'Erstellt einen neuen Eintrag im Adressbuch, falls notwendig.';
    $Lang->{'Delete selected entries'}         = 'Ausgewählte Einträge löschen';
    $Lang->{'Empty address book'}              = 'Adressbuch leeren';
    $Lang->{'Do you really want to empty the whole address book ? All entries will be deleted!'} = 'Wollen Sie das Adressbuch wirklich komplett leeren ? Alle Einträge werden gelöscht!';
    $Lang->{'Customer Portal Group'}           = 'Kundenportalgruppe';
    $Lang->{'Customer Portal Groups'}          = 'Kundenportalgruppen';
    $Lang->{'Manage customer portal groups.'}  = 'Kundenportalgruppen verwalten.';
    $Lang->{'Customer Portal Group Management'} = 'Kundenportalgruppen-Verwaltung';
    $Lang->{'Add Customer Portal Group'}       = 'Kundenportalgruppe hinzufügen';
    $Lang->{'Edit Customer Portal Group'}      = 'Kundenportalgruppe bearbeiten';
    $Lang->{'(The icon should have a size of 64x64 pixels. Otherwise it will be scaled automatically.)'} = '(Das Icon sollte eine Größe von 64x64 Pixel haben. Andernfalls wird es automatisch scaliert.)';
    $Lang->{'Filter templates and groups'}     = 'Vorlagen und Gruppen einschränken';
    $Lang->{'filter template groups'}          = 'Vorlagengruppen filtern';
    $Lang->{'filter ticket templates'}         = 'Ticketvorlagen filtern';
    $Lang->{'Requisitions'}                    = 'Bedarfsanforderungen';
    $Lang->{'Incident Reports'}                = 'Störungsmeldungen';
    $Lang->{'Change Requests'}                 = 'Änderungsanforderungen';
    $Lang->{'Go to'}                           = 'Gehe zu';
    $Lang->{'KIX Online Help'}                 = 'Onlinehilfe für KIX';
    $Lang->{'pending auto reopen'}             = 'warten zur Wiedervorlage';
    $Lang->{'Ticketnumber'}                    = 'Ticket-Nummer';
    $Lang->{'Ticket number'}                   = 'Ticket-Nummer';
    $Lang->{'Invalid ticket number!'}          = 'Ungültige Ticket-Nummer!';
    $Lang->{'Ticket bounced'}                  = 'Ticket umgeleitet';
    $Lang->{'ZIP'}                             = 'PLZ';
    $Lang->{'ZIP Code'}                        = 'PLZ';
    $Lang->{'ZIP-Code'}                        = 'PLZ';
    $Lang->{'Street'}                          = 'Strasse';
    $Lang->{'Mobile'}                          = 'Mobil';
    $Lang->{'Phone number'}                    = 'Telefon-Nr.';
    $Lang->{'Phonenumber'}                     = 'Telefonnummer';
    $Lang->{'Function'}                        = 'Funktion';
    $Lang->{'County'}                          = 'Land';
    $Lang->{'Company'}                         = 'Firma';
    $Lang->{' (minutes)'}                      = ' (Minuten)';
    $Lang->{' (hours)'}                        = ' (Stunden)';
    $Lang->{'Accounted time for this article'} = 'Erfasste Zeit für diesen Artikel';
    $Lang->{'Click to change CustomerID'}      = 'Hier Klicken um Kunden# zu ändern';
    $Lang->{'Multiple Selection'}              = 'Mehrfachauswahl';
    $Lang->{'current'}                         = 'aktuell';
    $Lang->{'desired date'}                    = 'Wunschtermin';
    $Lang->{'Desired date'}                    = 'Wunschtermin';
    $Lang->{'Please click an icon below to create a ticket from the desired template.'} =
        'Bitte klicken Sie auf ein Icon, um ein Ticket aus der gewünschten Vorlage zu erstellen.';
    $Lang->{'Don\'t write \'Fwd:\' into subject'}    = 'Kein \'Fwd:\' in den Betreff schreiben';
    $Lang->{'Don\'t write \'Re:\' into subject'}     = 'Kein \'Re:\' in den Betreff schreiben';
    $Lang->{'Write a mail, using an empty template'} = 'Leere E-Mail verfassen';
    $Lang->{'Empty mail'}                            = 'Leere Email';
    $Lang->{'Link ticket'}                           = 'Ticket verknüpfen';
    $Lang->{'Check to activate this date'}           = 'Haken setzten um Datum zu aktivieren';
    $Lang->{'All Tickets'}                           = 'Alle Tickets';
    $Lang->{'Open linked Tickets'}                   = 'Offene verknüpfte Tickets';
    $Lang->{'All linked Tickets'}                    = 'Alle verknüpften Tickets';
    $Lang->{'The icon file to be used as favicon (relative to Frontend::ImagePath).'} =
        'Die Icondatei, welche als Favicon genutzt werden soll (relativ zu Frontend::ImagePath).';
    $Lang->{"This field's content can not be longer than %s characters."} =
        'Der Inhalt dieses Felds kann max. %s Zeichen betragen.';
    $Lang->{"This field is required and its content can not be longer than %s characters."} =
        'Dieses Feld wird benötigt und der Inhalt kann max. %s Zeichen betragen.';
    $Lang->{'Do you really want to delete the selected entries?'}
        = 'Möchten Sie die ausgewählten Einträge wirklich löschen ?';
    $Lang->{'Do you really want to delete the selected links?'}
        = 'Möchten Sie die ausgewählten Verlinkungen wirklich löschen ?';
    $Lang->{'Search Template'}         = 'Suchvorlage';
    $Lang->{'My Search Profiles'}      = 'Meine Suchvorlagen';
    $Lang->{'Clone contact'}           = 'Ansprechpartner kopieren';
    $Lang->{'Search Profile Category'} = 'Kategorie der Suchvorlage';
    $Lang->{'Search Profile'}          = 'Suchvorlage';
    $Lang->{'Please select a category to add the shared search profile. Or enter a new category.'}
        = 'Kategorie wählen, zu der die geteilte Suchvorlage hinzugefügt werden soll. Oder eine neue Kategorie anlegen.';
    $Lang->{'Name for new search template category'} = 'Name der neuen Suchvorlagen-Kategorie';
    $Lang->{'Subscribe'}                             = 'Abonnieren';
    $Lang->{'Clone agent'}                           = 'Agent kopieren';
    $Lang->{'with link type'}                        = 'mit Verknüpfungstyp';
    $Lang->{'Select all the existing article attachments which should be attached too.'} =
        'Wählen Sie die Artikel-Anlagen aus, die ebenfalls angehangen werden sollen.';
    $Lang->{'A previously saved draft (Subject and Text) exists. Load the draft or delete ?'} =
        'Ein gespeicherter Entwurf (Betreff und Text) ist vorhanden. Soll dieser geladen oder gelöscht werden ?';
    $Lang->{'Save As Draft (Subject and Text)'} = 'Als Entwurf (Betreff und Text) speichern';
    $Lang->{'Defines the attributes to save form content as draft.'}
        = 'Legt die Attribute fest, die beim Als-Entwurf-Speichern gesichert werden sollen.';
    $Lang->{'Activates the save as draft button.'} = 'Aktiviert den Button: Als Entwurf speichern.';
    $Lang->{'Module Registration for the SaveAsDraft AJAXHandler.'}
        = 'Modulregistrierung für den AJAXHandler zu: Als Entwurf speichern.';
    $Lang->{'Module Registration for the PopupSize AJAXHandler.'}
        = 'Modulregistrierung für den AJAXHandler zu: Popupgröße ändern.';
    $Lang->{'Show DynamicField in frontend modules'}
        = 'Das Dynamische Feld wird in diesen Frontendmodulen angezeigt';
    $Lang->{'Mandatory in frontend modules'}   = 'Pflichtfeld in diesen Frontendmodulen';
    $Lang->{'DynamicField SysConfig Settings'} = 'SysConfig-Einstellungen für das Dynamische Feld';
    $Lang->{'Saving module assignments in SysConfig'}
        = 'Modulzuweisungen werden in SysConfig gespeichert';
    $Lang->{'Please select all frontend modules which should display the dynamic field.'}
        = 'Bitte wählen Sie alle Frontendmodule,<br /> in denen das Dynamische Feld angezeigt werden soll.';
    $Lang->{'Please select all frontend modules which should have the dynamic field as a mandatory field.' }
        = 'Bitte wählen Sie alle Frontendmodule,<br /> in denen das Dynamische Feld Pflichtfeld sein soll.';
    $Lang->{'Defines the interval to save form content as draft in milliseconds.'}
        = 'Legt das Intervall fest, in dem der Inhalt des Formulars gesichert werden soll. Der Wert ist in Millisekunden angegeben.';
    $Lang->{'Defines the message to be displayed when a draft exists and can be loaded.'}
        = 'Legt die Meldung fest, die angezeigt wird, wenn ein Entwurf existiert und geladen werden kann.';
    $Lang->{'e.g. Text or Te*t'}        = 'z.b. Text oder Te*t';
    $Lang->{'ObjectReference'}          = 'Objektreferenz';
    $Lang->{'Object Reference'}         = 'Objektreferenz';
    $Lang->{'Field Type'}               = 'Feldtyp';
    $Lang->{'Attachments Download'}     = 'Anlagen herunterladen';
    $Lang->{'Tickets New'}              = 'Tickets, neu';
    $Lang->{'Tickets Total'}            = 'Tickets insgesamt';
    $Lang->{'Tickets Reminder Reached'} = 'Tickets, Erinnerungszeit erreicht';
    $Lang->{'Ticket Customer'}          = 'Ticketkunde';
    $Lang->{'Third Party'}              = 'Dritte';
    $Lang->{'Customer Contact'}         = 'Kundenkontakt';
    $Lang->{'Contact Information'}      = 'Kontaktinformationen';
    $Lang->{'Link Type'}                = 'Linktyp';
    $Lang->{'Not set'}                  = 'Nicht gesetzt';
    $Lang->{'Select a field type.'}        = 'Wählen Sie einen Feldtyp aus.';
    $Lang->{'Select an object reference.'} = 'Wählen Sie eine Objektreferenz aus.';
    $Lang->{
        'Defines possible search criteria in the agents link interface for target object "Ticket". Order is important. Value is used as internal name.'
        }
        = 'Legt mögliche Suchkriterien im Agenteninterface für das Zielobjekt "Ticket" fest. Der Wert wird als interner Name genutzt.';
    $Lang->{
        'Defines displayed name for configured search criteria. Key has to be one of the internal names (see above); Value is used as name in the interface.'
        }
        = 'Legt den Anzeigename für die konfigurierten Suchkriterien fest. Der Schlüssel muss einer der vorher definierten internen Namen - siehe oben - sein. Der Wert ist der angezeigte Name in der Nutzeroberfläche.';
    $Lang->{
        'Defines data source for configured search criteria. Key has to be one of the internal names (see above); Value is used as name in the interface.'
        }
        = 'Legt die Datenquellen für die konfigurierten Suchkriterien fest. Der Schlüssel muss einer der vorher definierten internen Namen - siehe oben - sein.';
    $Lang->{'Determines the way the linked objects are displayed in each zoom mask.'}
        = 'Bestimmt die Art, wie verlinkte Objekte in jeder Zoom-Maske angezeigt werden.';
    $Lang->{'Create new linked person on create new Article or Update Owner.'}
        = 'Erstellt eine neue verlinkte Person, wenn ein Artikel erstellt oder ein Bearbeiter neu gesetzt wird.';
    $Lang->{'Defines which persons should not be added on AutoCreateLinkedPerson'}
        = 'Legt fest, welche Personen nicht automatisch bei AutoCreateLinkedPerson hinzugefügt werden sollen.';
    $Lang->{'This setting defines the person link type "agent".'}
        = 'Diese Einstellung definiert den Personen-Link-Typ "Agent".';
    $Lang->{'This setting defines the person link type "customer".'}
        = 'Diese Einstellung definiert den Personen-Link-Typ "Kunde".';
    $Lang->{'This setting defines the person link type "3rd party".'}
        = 'Diese Einstellung definiert den Personen-Link-Typ "Dritte".';
    $Lang->{
        'This setting defines that a "Ticket" object can be linked with persons using the "agent" link type.'
        }
        = 'Diese Einstellung legt fest, dass ein Ticketobjekt als "Agent" mit einer Person verlinkt werden kann.';
    $Lang->{
        'This setting defines that a "Ticket" object can be linked with persons using the "customer" link type.'
        }
        = 'Diese Einstellung legt fest, dass ein Ticketobjekt als "Kunde" mit einer Person verlinkt werden kann.';
    $Lang->{
        'This setting defines that a "Ticket" object can be linked with persons using the "3rd party" link type.'
        }
        = 'Diese Einstellung legt fest, dass ein Ticketobjekt als "Dritte" mit einer Person verlinkt werden kann.'
        ;
    $Lang->{'List of CSS files to always be loaded for the customer interface.'}
        = 'Liste von CSS-Dateien, die immer im Kunden-Interface geladen werden.';
    $Lang->{'Configures which ticket should receive which style, there are two possibilities for this. The first is a dependency on attributes such as Service, SLA, Type, State or Priority and its value name. The key consists of 000###attribute:::value name or as a combination with several attributes 000###attribute:::value name|||attribute2:::value name (||| is a logical AND). Several values (separated simicolon, corresponds to the logical OR) can be checked for each attribute. Furthermore, the value "EMPTY" can be used to check for empty values or with "[regexp]" via regular expressions. The second option would be to simply store the desired ticket status as a key (fallback).'}
        = 'Konfiguriert welches Ticket welchen Style erhalten soll, es gibt hierfür zwei möglichkeiten. Die erste ist eine Abhängigkeit nach Attributen wie Service, SLA, Type, State oder Priority und dessen Wertname. Der Schlüssel besteht aus 000###Attribut:::Wertname oder als Kombination mit mehreren Attributen 000###Attribut:::Wertname|||Attribut2:::Wertname (||| ist ein logisches UND). Es kann zu jedem Attribut mehrere Werte (Simikolon separiert, enrspricht dem logischen ODER) geprüft werden. Des weiterem kann mit dem Wert "EMPTY" nach leerwerten oder mit "[regexp]" über requläre Ausdrücke geprüft werden. Die zweite Möglichkeit wäre einfach den gewünschten Ticketstatus als Schlüssel zu hinterlegen (Fallback).';
    $Lang->{'List of CSS files to always be loaded for the agent interface.'}
        = 'Liste von CSS-Dateien, die immer im Agenten-Interface geladen werden.';
    $Lang->{'PostmasterFilter which sets destination queue in X-headers depending on email suffix.'}
        = 'PostmasterFilter, welcher eine Zielqueue im X-Header in Abhängigkeit vom Email-Suffix setzt.';
    $Lang->{'Defines the maximum number of recipients allowed for each incoming email.'}
        = 'Definiert die maximale Anzahl zulässiger Empfänger für jede eingehende E-Mail.';
    $Lang->{
        'Registers an identifier for the email filters. Value is used in the following config options. The keys will use for sorting.'
        }
        = 'Registriert einen Bezeichner für Emailfilter. Der Wert wird für die folgenden Optionen benötigt. Die Schlüssel legen die Sortierreihenfolge fest.';
    $Lang->{
        'Key has to be one of the identifier (see above). Values have to be an email address or a regexp as the sender which will be matched in from field of email.'
        }
        = 'Der Schlüssel muss einer der Bezeichner von oben sein. Werte müssen Emailadressen oder reguläre Ausdrücke sein, welche auf den Absender im "Von"-Feld passen.';
    $Lang->{
        'Key has to be one of the identifier (see above). Values have to be a regexp decribes the external reference number format which will be matched in subject field of the email.'
        }
        = 'Der Schlüssel muss einer der Bezeichner von oben sein. Werte müssen reguläre Ausdrücke sein, welche auf die externe Referenznummer im Betreff-Feld der Email passen.';
    $Lang->{
        'Key has to be one of the identifier (see above). Values have to be dynamic field names in which the external reference numbers will be saved. this fields will be used for extended follow up.'
        }
        = 'Der Schlüssel muss einer der Bezeichner von oben sein. Werte müssen Namen von dynamischen Feldern sein, in welchen die jeweiligen Referenznummern gespeichert werden sollen. Dieses Feld wird für das ExtendedFollowUp genutzt.';
    $Lang->{'Sort order for the age of the follow up tickets.'}
        = 'Sortierreihenfolge für das Alter der Follow-Up-Tickets.';
    $Lang->{
        'State types of follow up tickets which will be considered. If open/pending tickets was selected and no one was found all tickets will be considered.'
        }
        = 'Statustypen des FollowUpTickets, welche berücksichtigt werden sollen. Wenn "offene/wartende Tickets" gewählt und keine Tickets gefunden wurden, werden alle Tickets berücksichtigt.';
    $Lang->{'First open/pending tickets'}
        = 'Zuerst offene/wartende Tickets.';
    $Lang->{'Show merged tickets in linked objects table.'}
        = 'Anzeige zusammengefasster Tickets in der Tabelle mit den verknüpften Objekten.';
    $Lang->{'Show Merged Tickets in Linked Objects'}
        = 'Zusammengefasste Tickets anzeigen.';
    $Lang->{'Sets the default link object target identifier.'}
        = 'Setzt den Standard LinkObject Identifikator beim Erstellen von Email- oder Phonetickets.';
    $Lang->{'Defines Output filter to change link object target identifier.'}
        = 'Definiert einen Outputfilter, um den TargetIdentifier für die verlinkten Objekte im Email- und Phoneticket anzupassen.';
    $Lang->{
        'Defines Output filter to provide multiselect fields to assign dynamic fields easily to frontend modules.'
        }
        = 'Definiert einen Outputfilter, um Mehrfachauswahlfelder zum schnellen Zuweisen von dynamischen Feldern zu Frontendmodulen einzublenden.';
    $Lang->{'Alternative Display'} = 'Alternative Anzeige';
    $Lang->{
        'Here you can specify an alternative display string using placeholders for variables. If empty, the default will be taken.'
        }
        = 'Hier können Sie eine Alternative für die Darstellung angeben, unter Nutzung von Platzhaltern für Variablen. Falls nichts angegeben ist, wird der Standard genutzt.';
    $Lang->{'saved'} = 'gespeichert';
    $Lang->{'All agents who are linked with this ticket and have been selected (Linked Persons)'}
        = 'Alle Agenten die mit dem Ticket verlinkt sind und ausgewählt wurden (Verlinkte Personen)';
    $Lang->{
        'All customer contacts who are linked with this ticket and have been selected (Linked Persons)'
        }
        = 'Alle Ansprechpartner, die mit dem Ticket verlinkt sind und ausgewählt wurden (Verlinkte Personen)';
    $Lang->{
        'All 3rd person contacts who are linked with this ticket and have been selected (Linked Persons)'
        }
        = 'Alle "Dritte" die mit dem Ticket verlinkt sind und ausgewählt wurden (Verlinkte Personen)';
    $Lang->{'empty answer'} = 'Leere Antwort';

    # ticket template extensions
    $Lang->{'Create new ticket from template'} = 'Neues Ticket aus Vorlage erstellen';
    $Lang->{'Create new ticket from predefined template'} =
        'Neues Ticket aus vordefinierter Vorlage erstellen';
    $Lang->{'New Template Ticket'}           = 'Neues Vorlage-Ticket';
    $Lang->{'Template Description'}          = 'Vorlagenbeschreibung';
    $Lang->{'Template'}                      = 'Vorlage';
    $Lang->{'Ticket Templates'}              = 'Ticketvorlagen';
    $Lang->{'Ticket-Template'}               = 'Ticketvorlage';
    $Lang->{'Ticket-Template selection'}     = 'Ticket-Vorlagen-Auswahl';
    $Lang->{'Create new quick-email ticket'} = 'Neues Schnell-Email-Ticket erstellen';
    $Lang->{'Create new quick-phone ticket'} = 'Neues Schnell-Telefon-Ticket erstellen';
    $Lang->{'Incident Solved At Once'}       = 'Störung Sofort Gelöst';
    $Lang->{'New Problem Candidate'}         = 'Neuer Problemkandidat';
    $Lang->{'Create new ticket from predefined template.'} =
        'Neues Ticket aus einer Vorlage erstellen.';
    $Lang->{'Module Registration for TicketTemplate Base Module.'}
        = 'Modulregistrierung für das Ticketvorlagen Basismodul.';
    $Lang->{'TicketTemplate Base Module'} = 'Ticketvorlagen Basismodul';
    $Lang->{'Defines restrictions (blacklist) for the viewability of templates for contacts. Key contains the template key followed by double colon and a contact attribute, while value contains a regexp. Matching this regexp means no access to the template.'}
        = 'Legt Einschränkungen (Blacklist) für die Sichtbarkeit von Vorlagen für Kontakte fest. Der Schlüssel besteht aus dem Vorlagen-Schlüssel, gefolgt von zwei Doppelpunkten und einem Kontakt-Attribut. Der Wert enthält eine RegExp. Trifft die Regexp zu, so besteht kein Zugriff auf die Vorlage.';
    $Lang->{'Defines restrictions (whitelist) for the viewability of templates for contacts. Key contains the template key followed by double colon and a contact attribute, while value contains a regexp. Matching this regexp means no access to the template.'}
        = 'Legt Einschränkungen (Whitelist) für die Sichtbarkeit von Vorlagen für Kontakte fest. Der Schlüssel besteht aus dem Vorlagen-Schlüssel, gefolgt von zwei Doppelpunkten und einem Kontakt-Attribut. Der Wert enthält eine RegExp. Trifft die Regexp zu, so besteht kein Zugriff auf die Vorlage.';
    $Lang->{'Defines a one-line description for each template.'}
        = 'Legt einzeilige Beschreibungen für Vorlagen fest.';

    # ticket template configurator
    $Lang->{'Save template'}                  = 'Vorlage speichern';
    $Lang->{'Save new quick ticket template'} = 'Neue Ticket-Vorlage speichern';
    $Lang->{'Save changes'}                   = 'Änderungen speichern';
    $Lang->{'Change template'}                = 'Vorlage ändern';
    $Lang->{'A ticket template with this name already exists!'}
        = 'Eine Ticketvorlage mit diesem Namen existiert bereits!';
    $Lang->{'Save changes for this quick ticket template'} =
        'Änderungen für diese Ticket-Vorlage speichern';
    $Lang->{'Attachments cannot be part of a quick ticket template'}
        = 'Ticket-Vorlagen können keine Anhänge beinhalten';
    $Lang->{'Create/Change quickticket templates'} = 'Ticket-Vorlagen erstellen/ändern';
    $Lang->{'Ticket-Template configurator'}        = 'Ticket-Vorlagen-Konfigurator';
    $Lang->{'Start creating a new ticket template'}
        = 'Eine neue Ticket-Vorlagen anlegen';
    $Lang->{'Name for new ticket template'} = 'Name der neuen Ticket-Vorlage';
    $Lang->{'Delete selected ticket template and its configuration'}
        = 'Ausgewählte Ticket-Vorlagen und zugehörige Konfiguration löschen';
    $Lang->{'Are you sure you want to delete this template and its configuration?'}
        = 'Sind Sie sicher, dass Sie diese Vorlage und die zugehörige Konfiguration löschen möchten?';
    $Lang->{'Top of page'} = 'Zum Anfang der Seite';

    # ticket search and ticket search template extensions
    $Lang->{'Ticket Pending Time (before/after)'}    = 'Ticket-Wartezeit (vor/nach)';
    $Lang->{'Ticket Pending Time (between)'}         = 'Ticket-Wartezeit (zwischen)';
    $Lang->{'Ticket Escalation Time (before/after)'} = 'Ticket-Eskalationszeit (vor/nach)';
    $Lang->{'Ticket Escalation Time (between)'}      = 'Ticket-Eskalationszeit (zwischen)';
    $Lang->{'Name for new search template'}          = 'Name der neuen Suchvorlage';
    $Lang->{'Share this new template with all agents'}
        = 'Neue Suchvorlage allen Agenten zur Verfügung stellen';
    $Lang->{'Assign to agents'}                     = 'Allen Agenten zuweisen';
    $Lang->{'Start creating a new search template'} = 'Eine neue Suchvorlage anlegen';
    $Lang->{'Show template as queue'}               = 'Suchvorlage als virtuelle Queue anzeigen';
    $Lang->{'Show the search result as a virtual queue in the queue view'} =
        'Suchergebnis als virtuelle Queue in der Queue-Ansicht anzeigen';
    $Lang->{'Share this new template with other agents'}
        = 'Diese Suchvorlage mit anderen Agenten teilen.';
    $Lang->{'Escalation Destination Date'} = 'Eskalationszeitpunkt';
    $Lang->{'Escalation Destination In'}   = 'Eskalationszeit';

    # dashboard translations...
    $Lang->{'FAQ News'}                  = 'FAQ - Neuigkeiten';
    $Lang->{'14 Day Stats'}              = '14 Tage-Statistik';
    $Lang->{'1 Month Stats'}             = '1 Monat-Statistik';
    $Lang->{'Closed last week'}          = 'Geschlossen letzte Woche';
    $Lang->{'Created last week'}         = 'Erstellt letzte Woche';
    $Lang->{'Closed last month'}         = 'Geschlossen letzten Monat';
    $Lang->{'Created last month'}        = 'Erstellt letzten Monat';
    $Lang->{'Time of ticket creation'}   = 'Zeitpunkt der Ticket-Erstellung';
    $Lang->{'Time of ticket escalation'} = 'Zeitpunkt der Ticket-Eskalation';
    $Lang->{'no information for this ticket type available'}
        = 'keine Zusatzinformation für diesen Ticket-Typ verfügbar';
    $Lang->{'News about KIX releases!'} = 'Neuigkeiten zu KIX!';
    $Lang->{'Ticket Count Overview'}         = 'Ticketanzahlen';
    $Lang->{'Statetype'}                     = 'Statustyp';
    $Lang->{'Show Column Total'}             = 'Spaltensumme';
    $Lang->{'Show Row Total'}                = 'Zeilesumme';
    $Lang->{'StateTypes'}                    = 'Statustypen';
    $Lang->{'Row'}                           = 'Zeile';
    $Lang->{'Column'}                        = 'Spalte';

    # customer dashboard...
    $Lang->{'View all information for a selected customer'}
        = 'Alle Information zu einen ausgewählten Kunden einsehen';
    $Lang->{'Search for Customer'} = 'Kunden-Auswahl';
    $Lang->{'Search input'}        = 'Such-Eingabe';
    $Lang->{'Create new ticket'}   = 'Neues Ticket erstellen';
    $Lang->{'Create Phone Ticket'} = 'Telefon-Ticket erstellen';
    $Lang->{'Create Email Ticket'} = 'Email-Ticket erstellen';
    $Lang->{'Create a new phone or new email ticket for the selected customer.'} =
        'Neues Telefon- oder Email-Ticket für den ausgewählten Kundennutzer erstellen.';
    $Lang->{'Shows all assigned services for the selected customer.'}
        = 'Zeigt alle zugeordneten Services für den ausgewählten Kundennutzer.';
    $Lang->{'Assigned Services'}    = 'Zugeordnete Services';
    $Lang->{'Shown Services'}       = 'Gezeigte Services';
    $Lang->{'Max. table height'}    = 'Max. Tabellenhöhe';
    $Lang->{'No serivces assigned'} = 'Es sind keine Services zugeordnet';
    $Lang->{'Search for the customer, whose data should be shown in other dashboard plugins.'}
        = 'Suche nach Kunden, deren Daten in anderen Dashboard-Plugins angezeigt werden soll.';
    $Lang->{'Please select a customer first!'} = 'Bitte wählen Sie zuerst einen Kunden aus!';
    $Lang->{'Customer company'}                = 'Kunden-Firma';
    $Lang->{'Customer Companies'}              = 'Kunden-Firmen';
    $Lang->{'Create and manage companies.'}    = 'Unternehmen erzeugen und verwalten.';
    $Lang->{'Link customers to services.'}     = 'Kunden zu Services zuordnen.';
    $Lang->{'Customer Company Information'}    = 'Kundenfirmeninformation';
    $Lang->{'Further Information'}             = 'Weitere Informationen';
    $Lang->{'Please include at least one customer company.'}
        = 'Bitte geben Sie mindestens eine Kundenfirma an.';

    # CustomerTicketCustomerIDSelection
    $Lang->{'New Customer Ticket'}        = 'Neues Kundenticket';
    $Lang->{'Create new customer ticket'} = 'Neues Kundenticket erstellen';
    $Lang->{'Selection'}                  = 'Auswahl';
    $Lang->{'Assigned customer IDs'}      = 'Zugeordnete Kundennummern';
    $Lang->{'Selected customer ID'}       = 'Ausgewählte Kundennummer';
    $Lang->{'Select customer ID: %s'}     = 'Auswahl der Kundennummer: %s';
    $Lang->{'Select customer ID for this ticket: %s'} =
        'Folgende Kundennummer für dieses Ticket verwenden: %s';
    $Lang->{'Proceed'} = 'Fortfahren';
    $Lang->{'Proceed with ticket creation for the selected customer ID'}
        = 'Fortfahren mit der Ticket-Erstellung für die ausgewählten KundenID';
    $Lang->{'Please select the customer ID to which your request is related'}
        = 'Bitte wählen Sie die Kundennummer aus, auf die sich Ihre Anfrage bezieht';

    # queue/service tree view extensions
    $Lang->{'Change Service'}                 = 'Service ändern';
    $Lang->{'Queue-Tree'}                     = 'Queue-Baum';
    $Lang->{'Service-Tree'}                   = 'Service-Baum';
    $Lang->{'Hide or show queue selection'}   = 'Queue-Auswahl zeigen oder verstecken';
    $Lang->{'Hide or show service selection'} = 'Service-Auswahl zeigen oder verstecken';
    $Lang->{'Expand All'}                     = 'Alle aufklappen';
    $Lang->{'Collapse All'}                   = 'Alle zuklappen';
    $Lang->{'Queue view - layout'}            = '"Ansicht nach Queues" - Layout';
    $Lang->{'Service view - layout'}          = '"Ansicht nach Services" - Layout';
    $Lang->{'Select queue view layout.'}      = 'Layout der "Ansicht nach Queues" auswählen.';
    $Lang->{'Select service view layout.'}    = 'Layout der "Ansicht nach Services" auswählen.';
    $Lang->{'Layout style'}                   = 'Layout-Stil';
    $Lang->{'Queue view - show all tickets'}
        = '"Ansicht nach Queues" - Alle Tickets anzeigen';
    $Lang->{'Service view - show all tickets'}
        = '"Ansicht nach Services" - Alle Tickets anzeigen';
    $Lang->{'View All Tickets'} = 'Alle Tickets anzeigen';
    $Lang->{'Choose weather to show all (locked and unlocked) tickets in queueview.'} =
        'Auswahl, ob alle (gesperrte und entsperrte) Tickets in der "Ansicht nach Queues" angezeigt werden sollen';
    $Lang->{'Choose whether to show all (locked and unlocked) tickets in service view.'} =
        'Auswahl, ob alle (gesperrte und entsperrte) Tickets in der "Ansicht nach Queues" angezeigt werden sollen';
    $Lang->{'Display mode'}                      = 'Anzeige-Art';
    $Lang->{'All (locked and unlocked) tickets'} = 'Alle Tickets (entsperrte und gesperrte)';
    $Lang->{'Unlocked tickets only'}             = 'Nur entsperrte Tickets';
    $Lang->{'Column Settings'}                   = 'Spalteneinstellungen';
    $Lang->{'Possible Columns'}                  = 'Verfügbare Spalten';
    $Lang->{'Selected Columns'}                  = 'Gewählte Spalten';
    $Lang->{'FromTitle'}                         = 'Von / Titel (Letzter Kundenbetreff)';
    $Lang->{'My Tickets (all)'}                  = 'Meine Tickets (alle)';
    $Lang->{'My Tickets (open)'}                 = 'Meine Tickets (offen)';
    $Lang->{'Tickets unlocked'}                  = 'Entsperrte Tickets';

    # out of office substitute
    $Lang->{'Substitute'}      = 'Vertreter';
    $Lang->{'Substitute note'} = 'Vertreterhinweis';

    # PreferencesExtensions.xml
    $Lang->{'My Removable Article Flags'} = 'Meine entfernbaren Artikelmarkierungen';
    $Lang->{'Select article flags which should be removed after ticket close.'}
        = 'Wählen Sie Artikelmarkierungen aus, die beim Schließen des Tickets entfernt werden sollen';
    $Lang->{
        'Defines the use preference to select article flags which could be removed after ticket close.'
        }
        = 'Legt die Nutzereinstellung fest, mit welcher die Artikelmarkierungen gewählt werden können, die beim Schließen des Tickets entfernt werden';
    $Lang->{'Frontend module registration for the SearchProfileAJAXHandler.'}
        = 'Frontend-Modulregistrierung für SearchProfileAJAXHandler.';
    $Lang->{
        'Select search profiles from other agents. They are sorted by category and could be copied or subscribed.'
        }
        = 'Auswahl von Suchprofilen anderer Agenten. Diese sind nach Kategorien sortiert und können kopiert oder abonniert werden.';
    $Lang->{'Defines the use preference, to select search profiles from other agents.'}
        = 'Legt die Nutzereinstellung fest, mit welcher Suchprofile anderer Agenten ausgewählt werden können.';
    $Lang->{'Defines the user preference to select the queue move selection style.'}
        = 'Legt die Nutzereinstellung fest, mit welcher das Aussehen der Queueauswahl geändert werden kann.';
    $Lang->{'Parameters for the Out Of Office Substitute object in the preference view.'}
        = 'Parameter für die Abwesenheitsvertretung in den Nutzereinstellungen.';
    $Lang->{'Out Of Office Substitute'} = 'Abwesenheitsvertretung';
    $Lang->{'Select your out of office substitute.'}
        = 'Waehlen Sie fuer Ihre Abwesenheit eine Vertretung aus.';
    $Lang->{'Removable Article Flag'} = 'Entfernbare Artikelmarkierungen';
    $Lang->{
        'Defines the user preference, to auto-subscribe search profiles from other agents depending on selected categories.'
        }
        = 'Legt die Nutzereinstellung fest, mit welcher Suchprofile automatisch abonniert werden können in Abhängigkeit von der gewählten Kategorie.';
    $Lang->{'My Auto-subscribe Search Profile Categories'}
        = 'Meine automatisch abonnierten Suchprofilkategorien';
    $Lang->{'Auto-subscribe search profiles from other agents depending on selected categories.'}
        = 'Automatisches Abonnieren von Suchprofilen anderer Agenten auf der Grundlage von gewählten Kategorien.';
    $Lang->{'"From" field format'} = '"Von"-Feld Format';
    $Lang->{'System setting'}      = 'System-Einstellung';

    # changed translations
    $Lang->{'Article(s)'}    = 'Artikel';
    $Lang->{'Your language'} = 'Ihre bevorzugte Sprache';
    $Lang->{'Search Result'} = 'Suchergebnisse';
    $Lang->{'Linked as'}     = 'Verknüpft als';

    # ServiceQueueAssignment
    $Lang->{
        'Registration of service attribute AssignedQueueID which is used for automatic queue updates upon service updates.'
        } =
        'Registrierung des Service-Attributes AssignedQueueID, welches für die automatische Queue-Änderung bei Service-Updates genutzt wird.';
    $Lang->{'Assign a preferred queue to this service'} =
        'Diesem Service eine bevorzugte Queue zuweisen.';

    # Ticket.xml
    $Lang->{'Shows all owners and responsibles in selecetions.'} =
        'Legt die Anzeige aller Bearbeiter und Verantwortlichen als Standard fest.';
    $Lang->{'Default body for a forwarded email.'} =
        'Standardinhalt für eine weitergeleitete Email.';
    $Lang->{'Sets the search paramater for the ticket count in contact info block.'} =
        'Festlegung, welches Attribut für die Anzeige der Ticketanzahl in den Kundendaten genutzt werden soll.';
    $Lang->{
        'Overloads (redefines) existing functions in Kernel::System::Ticket. Used to easily add customizations.'
        }
        = 'Überschreibt (redefiniert) bestehende Funktionen in Kernel::System::Ticket. Dies vereinfacht das Hinzufügen von Anpassungen.';
    $Lang->{
        'Defines whether results of PossibleNot for tickets of multiple ACLs are subsumed, thus allowing a more modular approach to ACLS (KIX-default behavior is disabled).'
        }
        = 'Definiert ob die "PossibleNot"-Ergebnisse für Ticket-Eigenschaften mehrerer ACLs subsummiert werden. Dadurch wird ein modularer Ansatz für ACLs ermoeglicht (KIX-Standardverhalten ist deakviert).';
    $Lang->{
        'Determines the next possible ticket states, after the creation of a new phone ticket in the agent interface.'
        }
        = 'Legt den naechsten moeglich Ticketstatus nach dem Erzeugen einens Telfontickets im Agentenfrontend fest.';
    $Lang->{'Sets the default link type of splitted tickets in the agent interface.'}
        = 'Setzt einen Standard-Linktyp für geteilte Tickets im Agentenfrontend.';
    $Lang->{
        'Shows a link in the menu that allows linking a ticket with another object in the ticket zoom view of the agent interface.'
        }
        = 'Zeigt eine Verknuepfung in der TicketZoomView an, die es ermoeglicht ein Ticket mit einem anderen Objekt zu verknuepfen.';
    $Lang->{
        'Shows a link in the menu that allows merging tickets in the ticket zoom view of the agent interface.'
        }
        = 'Zeigt eine Verknuepfung in der TicketZoomView an, die es ermoeglicht ein Ticket mit einem anderen zusammenzufuegen.';
    $Lang->{
        'Shows a link in the menu to see the priority of a ticket in the ticket zoom view of the agent interface.'
        }
        = 'Zeigt eine Verknuepfung in der TicketZoomView an, die es ermoeglicht die Prioritaet eines Tickets zu sehen.';
    $Lang->{
        'Enable a smart style for time inputs (SysConfig-option TimeInputFormat will be ignored)'
        }
        = 'Aktivieren einer smarten Darstellung für die Zeiteingabe (die SysConfig-Option TimeInputFormat werden ignoriert)';
    $Lang->{
        'Enable a smart style for date inputs (SysConfig-option TimeInputFormat will be ignored)'
        }
        = 'Aktivieren einer smarten Darstellung für die Datumseingabe (die SysConfig-Option DateInputFormat werden ignoriert)';
    $Lang->{
        'Set interval for minute in time selections. Hash key is template file regex, value is time interval from 1 to 60. '
        }
        = 'Festlegung des Intervalls für Minuten in den Zeitauswahlen. Der Hash-Key enthält die RegEx für die Template-File, der Hash-Wert ist das Minuten-Intervall mit Werten von 1 bis 60.';
    $Lang->{
        'Infostring that will be used to show customer data if no specific infostring is defined in customer data backends.'
        }
        = 'Der Infostring, der fuer die Anzeige der Kundendaten genutzt wird, wenn keine spezifische Darstellung in den Kundendaten-Backends definiert ist.';
    $Lang->{
        'Autocomplete search attributes for ticket id, comma-eparated.'
        }
        = 'Autocomplete Suchattribute für die TicketID, kommagetrennt.';
    $Lang->{
        'Configures which dynamic fields were disabled depending on used frontend module, attributes like service, type, state or priority and its value. The key is composed like FrontendModule:::Attribute::Value. The key should contain the names of the disabled fields using regular expressions. If dynamic fields should be hidden on empty values, use EMPTY like FrontendModule:::Attribute::EMPTY.'
        }
        = 'Legt fest, welche Dynamischen Felder ausgeblendet werden sollen abhängig vom genutzten Frontendmodul, Attributen wie Service, Typ, Status oder Priorität und ihrem jeweiligen Wert. Der Schlüssel besteht dabei aus Frontendmodul:::Attribut:::Wert und Wert aus den zu verbergenden Dynamischen Felder. Diese können als RegExp angegeben werden. Falls Dynamische Felder bei leeren Werten ausgeblendet werden sollen, muss EMPTY in dieser Form genutzt werden: FrontendModule:::Attribute::EMPTY';
    $Lang->{
        'Defines how many chars should be shown for dynamic fields in ticket info sidebar. Disable this key to show all chars.'
        }
        = 'Legt fest, wie viele Zeichen für den Wert eines Dynamischen Feldes in der TicketInfo Sidebar angezeigt werden sollen. Um keine Einschränkungen vorzunehmen, kann der SysConfig-Schlüssel deaktiviert werden.';

    # QuickTicket
    $Lang->{
        'Frontend module registration for the Quickticket via AgentTicketPhone object in the agent interface.'
        }
        = 'Frontendmodul-Registration des Quickticket-via-AgentTicketPhone-Objekts im Agent-Interface.';
    $Lang->{
        'Defines the quickticket customer. Key must be the value of param DefaultSet in object registration.'
        }
        = 'Definiert den Quickticket-Kunden. Als Schluessel muss der Wert des Parameters DefaultSet in der Objektregistirerung verwendet werden.';
    $Lang->{
        'Defines the quickticket ticket type. Key must be the value of param DefaultSet in object registration.'
        }
        = 'Definiert den Quickticket-Tickettyp. Als Schluessel muss der Wert des Parameters DefaultSet in der Objektregistirerung verwendet werden.';
    $Lang->{
        'Defines the quickticket queue. Key must be the value of param DefaultSet in object registration.'
        }
        = 'Definiert den Quickticket-Queue. Als Schluessel muss der Wert des Parameters DefaultSet in der Objektregistirerung verwendet werden.';
    $Lang->{
        'Defines the quickticket service. Key must be the value of param DefaultSet in object registration.'
        }
        = 'Definiert den Quickticket-Service. Als Schluessel muss der Wert des Parameters DefaultSet in der Objektregistirerung verwendet werden.';
    $Lang->{
        'Defines the quickticket SLA. Key must be the value of param DefaultSet in object registration.'
        }
        = 'Definiert den Quickticket-SLA. Als Schluessel muss der Wert des Parameters DefaultSet in der Objektregistirerung verwendet werden.';
    $Lang->{
        'Defines the quickticket user (user must sign up for configured queue). Key must be the value of param DefaultSet in object registration.'
        }
        = 'Definiert den Quickticket-Bearbeiter (Nutzer muss diese Queue als Meine-Queue markiert haben). Als Schluessel muss der Wert des Parameters DefaultSet in der Objektregistirerung verwendet werden.';
    $Lang->{
        'Defines the quickticket responsible (user must sign up for configured queue). Key must be the value of param DefaultSet in object registration.'
        }
        = 'Definiert den Quickticket-Verantwortlichen (Nutzer muss diese Queue als Meine-Queue markiert haben). Als Schluessel muss der Wert des Parameters DefaultSet in der Objektregistirerung verwendet werden.';
    $Lang->{
        'Defines the quickticket article subject. Key must be the value of param DefaultSet in object registration.'
        }
        = 'Definiert den Quickticket-Artikelbetreff (und somit Tickettitel). Als Schluessel muss der Wert des Parameters DefaultSet in der Objektregistirerung verwendet werden.';
    $Lang->{
        'Defines the quickticket article body (only one line). Key must be the value of param DefaultSet in object registration.'
        }
        = 'Definiert den Quickticket-Artikelinhalt (nur einzeilig). Als Schluessel muss der Wert des Parameters DefaultSet in der Objektregistirerung verwendet werden.';
    $Lang->{
        'Defines the quickticket ticket state. Key must be the value of param DefaultSet in object registration.'
        }
        = 'Definiert den Quickticket-Ticketstatus. Als Schluessel muss der Wert des Parameters DefaultSet in der Objektregistirerung verwendet werden.';
    $Lang->{
        'Defines the quickticket pending time (in minutes). Key must be the value of param DefaultSet in object registration.'
        }
        = 'Definiert die Quickticket-Wartezeit (in Minuten). Als Schluessel muss der Wert des Parameters DefaultSet in der Objektregistirerung verwendet werden.';
    $Lang->{
        'Defines the quickticket priority. Key must be the value of param DefaultSet in object registration.'
        }
        = 'Definiert den Quickticket-Prioritaet. Als Schluessel muss der Wert des Parameters DefaultSet in der Objektregistirerung verwendet werden.';
    $Lang->{
        'Defines the quickticket freekey. Key must be the value of param DefaultSet in object registration followed by double-colon and desired freetext index.'
        }
        = 'Definiert den Quickticket-Freitextschluessel. Als Schluessel muss der Wert des Parameters DefaultSet in der Objektregistirerung  gefolgt von Doppel-Doppelpunkt und gewuenschtem Freitextindex verwendet werden.';
    $Lang->{
        'Defines the quickticket freetext. Key must be the value of param DefaultSet in object registration followed by double-colon and desired freetext index.'
        }
        = 'Definiert den Quickticket-Freitextwert. Als Schluessel muss der Wert des Parameters DefaultSet in der Objektregistirerung  gefolgt von Doppel-Doppelpunkt und gewuenschtem Freitextindex verwendet werden.';
    $Lang->{
        'Defines the quickticket time accounting value. Key must be the value of param DefaultSet in object registration.'
        }
        = 'Definiert den Quickticket-Zeitaufwand. Als Schluessel muss der Wert des Parameters DefaultSet in der Objektregistirerung verwendet werden.';
    $Lang->{
        'Defines link direction for quickticket templates - possible: Source or Target. Link will not be created, if there is no split action.'
        }
        = 'Definiert die Verlinksrichtung bei Quickticket-Vorlagen - möglich: Source oder Target. Ein Link wird nur angelegt, falls eine Split-Aktion vorausgeht.';
    $Lang->{
        'Defines link type for quickticket templates. Link will not be created, if there is no split action.'
        }
        = 'Definiert die Verlinksart bei Quickticket-Vorlagen. Ein Link wird nur angelegt, falls eine Split-Aktion vorausgeht.';
    $Lang->{
        'Create new phone ticket from "default user support"-template'
        }
        = 'Erstellt neues Telefonticket von der Vorlage "default user support"';
    $Lang->{'Defines whether the ticket type is translated in the selection box and ticket overviews (except in the admin area).'}
        = 'Definiert, ob der Tickettyp in der Auswahlbox und Ticketübersichten übersetzt wird (ausgenommen im Adminbereich).';
    $Lang->{'Do you really want to delete this template?'}
        = 'Wollen Sie diese Vorlage wirklich löschen?';
    $Lang->{'Delete this template'}
        = 'Diese Vorlage löschen';

    # PersonTicket
    $Lang->{'This setting defines the link type \'Person\'.'} = 'Definiert den Linktyp \'Person\'.';
    $Lang->{
        'This setting defines that a \'Ticket\' object can be linked with persons using the \'Person\' link type.'
        }
        = 'Definiert, dass ein \'Ticket\'-Objekt mit dem Linktyp \'Person\' mit Personen verlinkt werden kann.';
    $Lang->{'suspended'} = 'ausgesetzt';
    $Lang->{'Escalation suspended due to ticket state'}
        = 'Die Lösungszeit wurde abhängig vom Ticketstatus ausgesetzt.';

    # SLADisabled
    $Lang->{'Defines MethodName.'} = 'Defines Methodenname.';
    $Lang->{
        'Defines state names for which the solution time is disabled. Is a ticket set to on of these states, the solution time is set to hold.'
        }
        = 'Definiert Statusnamen, für die Lösungszeiten ausgesetzt werden. Befindet sich ein Ticket in einem dieser Status, wird die Lösungszeitberechnung angehalten.';
    $Lang->{'Defines ticket type names for which the SLA calulation time is disabled.'}
        = 'Definiert Tickettypen für die keine SLA-Zeiten berechnet werden.';
    $Lang->{
        'Additional and extended ticket methods which may overwrite original ticket methods (but not methods in Kernel::System::Ticket).'
        }
        = 'Zusaetzliche und erweiterte Ticket-Methoden die Original-methoden ueberschreiben koennen (ausser Methoden in Kernel::System::Ticket).';

    # Defaults
    $Lang->{'The identifier for a ticket, e.g. Ticket#, Call#, MyTicket#. The default is Ticket#.'}
        = 'Ticket-Identifikator, z. B. Ticket#,Call#, MyTicket#. Als Standard wird Ticket# verwendet.';
    $Lang->{'Parameters for the FollowUpNotify object in the preference view.'}
        = 'Parameter für das FollowUpNotify-Objekt in der Ansicht für die Einstellungen.';
    $Lang->{
        'Select your TicketStorageModule to safe the attachments of articles. "DB" stores all data in the database. Don\'t use this module if big attachments will be stored. "FS" stores the data in the filesystem. This is faster but webserver user should be the KIX user. You can switch between the modules even on a running system without any loss of data.'
        }
        = 'Wählen Sie das TicketStorage-Modul aus und legen sie fest, wie die Anhänge zu Artikeln gespeichert werden sollen. "DB" speichert alle Daten in der Datenbank. Wird nur mit kleinen Anhängen gearbeitet, ist das kein Problem. "FS" legt die Daten im Filesystem ab, der Zugriff ist schneller. Allerdings sollte bei Verwendung von "FS" der WEB-Server unter dem selben Benutzer laufen, der auch für KIX verwendet wird. Sie können das Modul auch für laufende Systeme ändern, es wird trotzdem weiter auf alle Daten zugegriffen und auch die Daten, die mit Hilfe des anderen Moduls gespeichert wurden, bleiben verfügbar.';
    $Lang->{
        'Would you like to execute followup checks on In-Reply-To or References headers for mails, that don\'t have a ticket number in the subject?'
        }
        = 'Sollen auf die Header-Einträge für In-Reply-To und References-Header Follow-up- Checks ausgeführt werden, wenn im Betreff einer Mail keine Ticketnummer angegeben ist?';
    $Lang->{
        'Would you like to execute followup checks in mail body, that don\'t have a ticket number in the subject?'
        }
        = 'Sollen in den Email-Body Follow-up- Checks ausgeführt werden, wenn im Betreff einer Mail keine Ticketnummer angegeben ist?';
    $Lang->{
        'Would you like to execute followup checks in mail plain/raw, that don\'t have a ticket number in the subject?'
        }
        = 'Sollen in den Email-Plain/Raw Follow-up- Checks ausgeführt werden, wenn im Betreff einer Mail keine Ticketnummer angegeben ist?';
    $Lang->{'The postmaster default queue.'} = 'Postmaster default Queue.';
    $Lang->{'Enable ticket responsible feature.'}
        = 'Aktivieren des Ticket-Verantwortlichkeits-Features.';
    $Lang->{'Clone Filter'} = 'Filter kopieren';
    $Lang->{'A filter with this name already exists!'}
        = 'Ein Filter mit diesem Namen existiert bereits!';

    # Escalation
    $Lang->{'Disables response time SLA, if the newly created ticket is a phone ticket.'}
        = 'Deaktiviert Antwortzeit-SLA wenn Ticket ein Telefonticket ist.';
    $Lang->{'Restricts the ResponsetimeSetByPhoneTicket to these ticket types.'}
        = 'Beschränkt die ResponsetimeSetByPhoneTicket auf diese Tickettypen.';
    $Lang->{'List of JS files to always be loaded for the agent interface.'}
        = 'Liste von JS-Dateien, die immer im Agenten-Interface geladen werden.';
    $Lang->{
        'Defines a dynamic field of type date/time which is used as start time for solution SLA-computation rather than ticket creation time, thus allowing to start SLA-countdown with begin of customer desired times. "Index" is only fallback for old configuration upgraded from KIX 4.0 or previous to be workable. In this case dynamic field named TicketFreeTime"Index" is used.'
        }
        = 'Definiert ein Dynamisches Feld vom Typ Datum/Zeit welches anstelle des Ticketerstellzeitpunktes als SLA-Startzeitpunkt für die Lösungszielzeit genutzt wird. Somit kann die SLA-Zeit erst ab dem Kundenwunschtermin starten. "Index" ist nur ein Fallback, um ältere Konfigurationen, welche von KIX 4.0 oder älter angehoben wurden, funktionstüchtig zu halten. In diesem Falle wird ein Dynamisches Feld mit dem Namen TicketFreeTime"Index" genutzt.';
    $Lang->{'Disables response time SLA, if an auto reply was sent for this ticket.'} = '';
    $Lang->{'Restricts the ResponsetimeSetByAutoReply to these ticket types.'}        = '';
    $Lang->{'Defines queue names for which the SLA calulation time is disabled.'}     = '';

    # FrontendTicketRestrictions
    $Lang->{'Ticket-ACL to restrict some ticket data selections based on current ticket data.'}
        = 'Ticket-ACL, um bestimmte Auswahlmöglichkeiten basierend auf den aktuellen Ticketdaten zu verbieten.';
    $Lang->{
        'Registers an identifier for the ticket restrictions. Value is used in the following config options.'
        }
        = 'Registriert einen Bezeichner für die TicketDataRestrictions. Der Wert wird für die folgenden Konfigurationsoptionen benötigt.';
    $Lang->{
        'Defines which ticket actions have to be restricted (agent and customer frontend is possible). Key has to be one of the identifier (see above). Value defines restricted ticket actions and has to be filled at any time. Multiple actions can be seperated by ;.'
        }
        = 'Legt fest, welche Ticketaktionen eingeschränkt werden sollen (Agenten- und Kundenfrontend möglich). Der Schlüssel muss einer der Bezeichner (siehe oben) sein.';
    $Lang->{
        'Defines ticket match properties (e.g. type:::default). Key has to be one of the identifier (see above). Value defines matching ticket data type and its values, separated by :::. Multiple values can be seperated by ;. Split multiple match criteria by |||. Leave it empty for always matching.'
        }
        = 'Legt die Eigenschaften fest, auf die geprüft werden soll (z.B. type:::default). Der Schlüssel muss einer der Bezeichner (siehe oben) sein. Die Werte legen die Daten fest, auf die geprüft werden soll, getrennt durch :::. Mehrfache Werte können durch ; getrennt werden. Mehrfache Prüfkritierien durch |||. Wird das Feld leer gelassen, passt der Wert immer.';

    $Lang->{
        'Registers additional information for the ticket excluded data restrictions. Use it like the old configuration above.'
        }
        = 'Registriert ergänzende Informationen für die ExcludedDataRestrictions. Genutzt werden kann dies wie die bisherige Konfiguration, siehe oben.';

    $Lang->{
        'Allows overriding of Data character limits, hard coded in TTs. The key has the following format: &lt;TemplateFilePattern&gt;::(&lt;VariableNamePattern&gt;), the value is the numeric character limit that should be used. You can use RegEx.'
        }
        = 'Ermöglicht das Überschreiben von Data-Zeichenlimits, die in TTs fest eingetragen sind. Der Schlüssel hat das folgende Format: <TemplateFilePattern>::<VariableNamePattern>, der Wert ist das zu verwendende nummerische Zeichenlimit. RegEx kann genutzt werden.';
    $Lang->{'Replaces the default Data character limits.'}
        = 'Überschreibt die Standard-Data-Zeichenlimits.';
    $Lang->{'Allows overriding of dynamic field character limits.'}
        = 'Überschreibt die Standard-Zeichenlimits für Dynamische Felder.';

    # CustomerDashboard
    $Lang->{'Pending Tickets'}      = 'Wartende Tickets';
    $Lang->{'All pending tickets.'} = 'Alle wartenden Tickets.';

    # TicketStateWorkflow
    $Lang->{'no state update possible - no common next states'} =
        'kein Statuswechsel möglich - keine gemeinsamen Folgestatus';
    $Lang->{'Ticket-ACLs to define the following possible state.'}
        = 'Ticket-ACLs zur Definition der moeglichen Folgestatus.';
    $Lang->{
        'Settings for TicketStateWorkflow to define the following possible state. States have to be comma separated. placeholders are _ANY_ , _PREVIOUS_ and _NONE_.'
        }
        = 'Einstellungen für den Ticketstatusworkflow, zur Definition der moeglichen Folgestatus. Status werden kommasepariert aufgelistet. Als Platzhalter dienen _ANY_ , _PREVIOUS_ und _NONE_.';
    $Lang->{'Settings for Default TicketState to define the following possible state.'}
        = 'Einstellungen für den DefaultTicketstatus, zur Definition der moeglichen Folgestatus.';
    $Lang->{'Settings for DefaultTicket-Queue.'} = 'Einstellungen für die Standard-Queue.';
    $Lang->{'Sets default ticket type in AgentTicketPhone and AgentTicketEmail.'}
        = 'Setzt den Standard-Tickettyp in AgentTicketPhone und AgentTicketEmail.';
    $Lang->{'Sets default queue in AgentTicketPhone and AgentTicketEmail.'}
        = 'Setzt die Standard-Queue in AgentTicketPhone und AgentTicketEmail.';
    $Lang->{
        'Ticket event module to force a new ticket state after lock action. As key you have to define the ticket type + ":::" + current state and the next state as content after lock action.'
        }
        = 'Ticket Event Modul für automatisches Setzen eines neuen Ticketstatus nach dem das Ticket gesperrt wurde. Der Schlüssel ist der Tickettyp + ":::" + aktueller Status, der Inhalt der Status nach dem Sperren.';
    $Lang->{'Updates ticket state if configured or required after type update.'}
        = 'Aktualisiert Ticketstatus sofern konfiguriert oder notwendig nach Aenderung des Tickettyps.';
    $Lang->{
        'Set a true-value for key (ticket type) if a type update forces a state update to the default state. The update is done whenever the original ticket state does not appear in the new ticket types workflow definition.'
        }
        = 'Setzen Sie einen True-Wert für den Schluessel (Tickettyp), falls eine Tickettypaenderung einen Statuswechsel in den Standardstatus erzwingen soll. Die Aktualisierung wird immer durchgefuehrt wenn der aktuelle Ticketstatus nicht in der Workflowdefinition des neuen Tickettyps vorhanden ist.';
    $Lang->{
        'The state if a ticket got a follow-up (use _PREVIOUS_ as placeholder for the very last state in ticket history before current).'
        }
        = 'Status für ein Ticket, für das ein Follow-up eintrifft (nutzen Sie _PREVIOUS_ als Platzhalter für den letzten Status in der Tickethistorie vor dem aktuellen).';
    $Lang->{
        'Checks if the sender of a follow-up message is contained in customer database an has an identical customer-ID as the ticket. If so, the email is considered as email-external, otherwise it is considered as email-internal. Default KIX-behavior if disabled.'
        }
        = 'Prüft ob der Absender einer Nachricht als Kundennutzer hinterlegt ist und dieselbe Kunden-ID hat wie am Ticket hinterlegt ist. Ist dem so wird die Email als "email-external" betrachtet, andernfalls als "email-internal". Standard KIX-Verhalten wenn deaktiviert.';
    $Lang->{
        'Checks if the sender of a follow-up message is contained in agent database, and if so sets sender type "agent".'
        }
        = 'Prüft ob der Absender einer Nachricht als Agent hinterlegt ist und setzt den SenderTyp "agent" wenn dem so ist.';
    $Lang->{'Moves ticket after state update.'} = 'Verschiebt Ticket nach Statusaktualisierung.';
    $Lang->{
        'Automatically sets the state named by value if the state named in key is reached. Key may be prefixed by a certain ticket type name for which this state transition is valid only.'
        }
        = 'Setzt automatisch den Status in Wert, sobald der Status in Schluessel erreicht wird. Im Schluessel kann ein Praefix des Tickettyps diesen Statuswechsel auf genau diesen Tickettyp einschraenken.';
    $Lang->{
        'If the automatically set state is a pending state, the pending offset time can be defined here (business minutes). Key must be the same as in NextStateSet.'
        }
        = 'Wenn der automatisch zu setzende Status ein warten-Status ist, kann hier die Wartezeit in Geschaeftsminuten definiert werden. Der Schluessel muss identisch zu dem entsprechenden Uebergang in NextStateSet sein.';
    $Lang->{
        'Define which State should be set automatically (Value) after pending time of State (Key) has been reached.'
        }
        = 'Definition welche Status automatisch gesetzt werden soll (Inhalt) nach dem erreichen des "Warten Zeit" (Schlüssel).';
    $Lang->{
        'Automatically moves ticket to configured queue if state is set - use of wildcards possible (e.g. &lt;KIX_TicketDynamicField1&gt;).'
        }
        = 'Verschiebt Ticket automat. in konfigurierte Queue sobald der Status gesetzt wird - Verwendung von Platzhaltern möglich (z.B. &lt;KIX_TicketDynamicField1&gt;).';
    $Lang->{
        'Choose to add a failure article to ticket, if target queue for automatic queue move does not exists.'
        }
        = 'Festlegung für eine Fehler-Notiz am Ticket, falls die Zielqueue für das automatsiche Verschieben nicht existiert.';
    $Lang->{'New ticket queue, if target queue for automatic queue move does not exists.'}
        = 'Gesetzte Ticket-Queue, falls die Zielqueue für das automatsiche Verschieben nicht existiert.';
    $Lang->{'New ticket state, if target state for automatic state change does not exists.'}
        = 'Gesetzter Ticket-Status, falls der Zielstatus für die automatische Änderung nicht existiert.';
    $Lang->{'Defines which state will unlock the ticket.'}
        = 'Definiert die Status die zum Freigeben des Tickets führen.';
    $Lang->{
        'Performs ticket update actions after state update - currently limited to state update.'
        }
        = 'Führt Ticketaktionen nach Statusaktualisierung durch - derzeit beschränkt auf Statuswechsel.';
    $Lang->{
        'Settings for Default TicketState to define the default following possible state un lock.'
        }
        = 'Einstellungen fuer den Ticketstatus, zur Definition des Default-Folgestatus nach dem Sperren.';
    $Lang->{
        'Settings for Default TicketState to define the default following possible state on unlock.'
        }
        = 'Einstellungen fuer den Ticketstatus, zur Definition des Default-Folgestatus nach dem Freigeben.';
    $Lang->{
        'Settings for TicketState to define the following possible state. States have to be comma separated.'
        }
        = 'Einstellungen fuer den nichtüberschreibbaren Ticketstatus, zur Definition der moeglichen Folgestatus. Status werden kommasepariert aufgelistet.';
    $Lang->{
        'Settings for TicketState to define the following possible state. States have to be comma separated.'
        }
        = 'Einstellungen fuer den nichtüberschreibbaren Ticketstatus, zur Definition der moeglichen Folgestatus. Status werden kommasepariert aufgelistet.';
    $Lang->{'Updates ticket state after unlock ticket based on selected ticket type.'}
        = 'Aktualisiert Ticketstatus nach Sperren / Entsperren basierend auf dem gesetzten Tickettyp.';
    $Lang->{'Defines Queue, TicketType and new State for TicketQueueMoveWorkflowState.'}
        = 'Definiert Queue, TicketType und den zu setzenden Folgestatus für TicketQueueMoveWorkflowState';
    $Lang->{'Updates ticket state if configured or required after queue move.'}
        = 'Aktualisiert den Ticket Status nach einem Queuewechsel.';
    $Lang->{'Defines Queue, TicketType and new TicketType for TicketQueueMoveWorkflowTickettype.'}
        = 'Definiert Queue, TicketType und den zu setzenden Folgetyp für TicketQueueMoveWorkflowTickettyp.';
    $Lang->{'Updates ticket type if configured or required after queue move.'}
        = 'Aktualisiert den Ticket Typ nach einem Queuewechsel.';
    $Lang->{
        'State update for closed tickets if a new article of type webrequest is created in customer interface.'
        }
        = 'Statusupdate für geschlossene Tickets wenn ein neuer Artikel vom Typ Webrequest in der Kundenoberfläche erstellt wird.';

    # AgentArticleEdit
    $Lang->{'Edit Article'}                 = 'Artikel ändern';
    $Lang->{'Copy Article'}                 = 'Artikel kopieren';
    $Lang->{'Move Article'}                 = 'Artikel verschieben';
    $Lang->{'Delete Article'}               = 'Artikel löschen';
    $Lang->{'of destination ticket'}        = 'des Zieltickets';
    $Lang->{'You cannot asign more time units as in the source article!'} =
        'Sie können nicht mehr Zeiteinheiten zuweisen, als im Original-Artikel!';
    $Lang->{'Really delete this article?'} = 'Diesen Artikel wirklich löschen?';
    $Lang->{'Copied time units of the source article'} =
        'Zu übernehmende Zeiteinheiten des Original-Artikels';
    $Lang->{'Handling of accounted time from source article?'} =
        'Umgang mit Zeitbuchung am Original-Artikel?';
    $Lang->{'Change to residue'}   = 'Auf Rest verringern';
    $Lang->{'Leave unchanged'}     = 'Unverändert lassen';
    $Lang->{'Owner / Responsible'} = 'Bearbeiter / Verantwortlicher';
    $Lang->{'Change the ticket owner and responsible!'} =
        'Ändern des Ticket-Bearbeiters und -Verantwortlichen!';
    $Lang->{'Perhaps, you forgot to enter a ticket number!'} =
        'Bitte geben Sie eine Ticket-Nummer ein';
    $Lang->{'Sorry, no ticket found for ticket number: '} =
        'Es konnte kein Ticket gefunden werden für Ticket-Nummer: ';
    $Lang->{'Sorry, you need to be owner of the new ticket to do this action!'} =
        'Sie müssen der Bearbeiter des neuen Tickets sein, um diese Aktion auszuführen!';
    $Lang->{'Sorry, you need to be owner of the selected ticket to do this action!'} =
        'Sie müssen der Bearbeiter des ausgewählten Tickets sein, um diese Aktion auszuführen!';
    $Lang->{'Please contact your admin.'}     = 'Bitte kontaktieren Sie Ihren Administrator.';
    $Lang->{'Please change the owner first.'} = 'Bitte ändern Sie zunächst den Bearbeiter.';
    $Lang->{'Sorry, you are not a member of allowed groups!'} =
        'Bitte entschuldigen Sie, aber Sie nicht Mitglied der berechtigten Gruppen!';

    # EO AgentArticleEdit

    # Link person
    $Lang->{'Persons login'}                   = 'Personen-Login';
    $Lang->{'Persons attributes'}              = 'Personen-Attribute';
    $Lang->{'3rd party'}                       = 'Dritte';
    $Lang->{'3rdParty'}                        = 'Dritte';
    $Lang->{'Linked Persons'}                  = 'Verlinkte Personen';
    $Lang->{'Person Type'}                     = 'Personentyp';
    $Lang->{'Show or hide the linked persons'} = 'Verlinkte Personen zeigen oder verstecken';
    $Lang->{'Select this person to receive a copy of the new article via email'} =
        'Dieser Person eine Kopie des Artikels per Mail zu kommen lassen';
    $Lang->{'Add this person to list of recipients'}
        = 'Diese Person als Empfänger hinzufügen';
    $Lang->{'Click to view detailed informations for this persons'} =
        'Klicken um detaillierte Informationen zu dieser Person einzusehen';
    $Lang->{'Select frontend agent modules where linked persons are activated.'} =
        'Festlegung in welchen Agent-Frontend-Modulen die Verlinkten Personen aktiviert sind.';
    $Lang->{'Defines how the linked persons can be included in emails.'} =
        'Definiert die Arten wie Verlinkte Personen in Emails eingebunden werden können.';
    $Lang->{'Defines which person attributes are displayed in detail presentation.'} =
        'Definiert welche Personen-Attribute in der Detailansicht gezeigt werden.';
    $Lang->{'Defines which person attributes are displayed in complex link presentation.'}
        = 'Definiert welche Personen-Attribute in der komplexen Link-Ansicht gezeigt werden.';
    $Lang->{
        'Defines the column headers of the person attributes displayed in complex presentation.'
        }
        = 'Definiert die Spaltenüberschriften der Personen-Attribute, die in der komplexen Link-Ansicht gezeigt werden.';
    $Lang->{
        'Defines if linked persons of types "Customer" and "3rd Party" can be selected for notification of internal articles.'
        } =
        'Definiert, ob verlinkte Personen vom Typ "Kunde" oder "Dritte" für die Benachrichtigung bei internen Artikeln ausgewählt werden dürfen.';
    $Lang->{'PLEASE NOTE'} = 'BITTE BEACHTEN';
    $Lang->{
        'Persons of types "Customer" and "3rd Party" will not be notified when an internal article is created!'
        } =
        'Personen vom Typ "Kunde" und "Dritte" werden nicht benachrichtigt wenn ein interner Artikel erstellt wird.';
    $Lang->{'Person Information'} = 'Informationen zur Person';

    # TicketZoom
    $Lang->{'Module to show empty mail link in menu.'} =
        'Link zu der Erstellung einer leeren Email im Menue der Ticketansicht.';
    $Lang->{'Screen after ticket closure'} = 'Ansicht nach Ticket-Abschluss';
    $Lang->{'Defines which page is shown after a ticket has been closed.'} =
        'Definiert welche Ansicht aufgerufen, wird nach dem ein Ticket geschlossen wurde';
    $Lang->{'Redirect target'}      = 'Weiterleitungsziel';
    $Lang->{'Last screen overview'} = 'Letzte Ticket-Übersicht';
    $Lang->{'Ticket zoom'}          = 'Ticket-Inhalt';
    $Lang->{'Ticket Zoom - article handling'} =
        'Artikel-Verhalten in Ticket-Detailansicht';
    $Lang->{'Initially shown article in agent\'s ticket zoom mask.'} =
        'Inital angezeigter Artikel in der Ticket-Detailansicht der Agentenoberfläche';
    $Lang->{'Shown article'}         = 'Angezeigter Artikel';
    $Lang->{'First article'}         = 'Erster Artikel';
    $Lang->{'Last article'}          = 'Letzter Artikel';
    $Lang->{'Last customer article'} = 'Letzter Kunden-Artikel';
    $Lang->{'Defines which ticket data parameters are displayed in direct data presentation.'} =
        'Definiert welche Daten in der Direktdatenanzeige dargestellt werden.';
    $Lang->{'Defines email-actions allowed for article types.'} =
        'Definiert E-Mail-Aktionen für Artikeltypen.';
    $Lang->{'No articles were found with the defined filter.'}
        = 'Es wurde keine Artikel mit den festgelegten Filter gefunden.';

    # LinkObject
    $Lang->{'Allows a search with empty search parameters in link object mask.'}
        = 'Erlaubt Suche mit leeren Suchparametern in LinkObject-Maske.';
    $Lang->{'Frontend module registration for the AgentLinkObjectUtils.'}
        = 'Frontendmodul-Registration des Moduls AgentLinkObjectUtils.';
    $Lang->{'Dynamic fields shown in the linked tickets screen of the agent interface. Possible settings: 0 = Disabled, 1 = Available, 2 = Enabled by default.'}
        = 'Dynamische Felder, die auf dem Bildschirm für verknüpfte Tickets der Agentenschnittstelle angezeigt werden. Mögliche Einstellungen: 0 = Deaktiviert, 1 = Verfügbar, 2 = Standardmäßig aktiviert.';

    # ResponsibleAutoSetPerTicketType
    $Lang->{'Workflowmodule which sets the ticket responsible based on ticket type if not given.'} =
        'Workflowmodule welches auf den Ticketverantwortlichen auf Basis des Tickettyps setzt, sofern dieser noch nicht vorgegeben wurde.';
    $Lang->{
        'If ticket responsible feature is enabled, set automatically the owner as responsible on owner set.'
        } =
        'Wenn das Ticket-Verantwortlichkeits-Featues aktiviert ist, wird beim nicht gesetzten Verantwortlichen der Bearbeiter auch automatisch als Verantwortlich gesetzt.';

    $Lang->{'Preselect old ticket data in chosen ticket note functions'} =
        'Vorauswahl der vorherigen Ticket-Daten in den ausgewählten Ticket-Notiz-Funktionen';
    $Lang->{'Defines where it is possible to move a ticket into an other queue.'} =
        'Legt fest wo es möglich ist, ein Ticket in eine andere Queue zu verschieben.';

    # FrontendMenuChanges
    $Lang->{'Reporting'}            = 'Berichtswesen';
    $Lang->{'Default user support'} = 'Standard Anwenderunterstützung';
    $Lang->{''}                     = '';

    # SysConfigChangeLog
    $Lang->{
        'Logs the configuration changes of SysConfig options.'
        }
        = 'Loggt die Konfigurationsänderungen von SysConfig-Optionen.';
    $Lang->{
        'Log module for the SysConfig. "File" writes all messages in a given logfile, "SysLog" uses the syslog daemon of the system, e.g. syslogd.'
        }
        = 'Logmodul für die SysConfig. "File" schreibt in eine anzugebende Datei, "SysLog" logt mit Hilfe des systemspezifischen Logdaemons, z. B. syslogd.';
    $Lang->{
        'Set this config parameter to "Yes", if you want to add a suffix with the actual year and month to the SysConfig logfile. A logfile for every month will be created.'
        }
        = 'Wird dieser Konfigurationsparameter aktiviert, wird an das SysConfig Logfile eine Endung mit dem aktuellen Monat und Jahr angehängt und monatlich ein neues Logfile geschrieben.';

    # KIXSidebar
    $Lang->{'Sidebar module registration for the agent interface.'} =
        'Registrierung für das Sidebarmodul im Agenten-Interface.';
    $Lang->{'Sidebar module registration for the customer interface.'} =
        'Registrierung für das Sidebarmodul im Kunden-Interface.';
    $Lang->{'Parameters for the KIXSidebar backend TextModules.'} =
        'Parameter für das KIXSidebar-Backend TextModules.';
    $Lang->{'Parameters for the KIXSidebar backend LinkedPersons.'} =
        'Parameter für das KIXSidebar-Backend LinkedPersons.';
    $Lang->{'Parameters for the KIXSidebar backend CustomerInfo.'} =
        'Parameter für das KIXSidebar-Backend CustomerInfo.';
    $Lang->{'Parameters for the KIXSidebar backend CustomizeForm.'} =
        'Parameter für das KIXSidebar-Backend CustomizeForm.';
    $Lang->{'Parameters for the KIXSidebar backend Scratchpad (Remarks).'} =
        'Parameter für das KIXSidebar-Backend Scratchpad (Bemerkungen)';
    $Lang->{'Parameters for the KIXSidebar backend TicketInfo.'} =
        'Parameter für das KIXSidebar-Backend TicketInfo.';
    $Lang->{'Show more information about this customer'} =
        "Zeige mehr Informationen über diesen Kunden";
    $Lang->{
        'Registers an identifier for the KIXSidebarTools. Value is used in the following config options.'
        } =
        "Registriert einen Indentifikator für die KIXSidebarTools. Der Wert wird für die folgende Konfiguration benötigt.";
    $Lang->{
        'Defines which ticket actions have to be used (agent and customer frontend is possible). Key has to be one of the identifier (see above). Value defines used ticket actions and has to be filled at any time. Multiple actions can be separated by ;.'
        } =
        "Definiert, welche Ticket-Actions betroffen sind (Agenten- und Kundenfrontend möglich). Der Schlüssel muss einer der zuvor definierten Identifikatoren sein (siehe oben). Die Werte definieren die genutzten Ticket-Actions und müssen ausgefüllt werden. Mehrfache Actions können durch ; getrennt werden.";
    $Lang->{
        'Defines connection data (e.g. Example:::Database). Key has to be one of the identifier (see above).'
        } =
        "Definiert die Verbindungsdaten (z.B. Example:::Database). Der Schlüssel muss einer der zuvor definierten Identifikatoren sein. (siehe oben)";
    $Lang->{'Defines for which actions the linked persons should be informed by email.'}
        = 'Legt fest, für welche Actions die verlinkten Personen per Mail informiert werden sollen.';
    $Lang->{'Behavior of KIXSidebar "ContactInfo" contact selection'}
        = 'Verhalten der Kontaktauswahl in der KIXSidebar "Kontaktinformation"';
    $Lang->{'Article Contacts'} = 'Artikelkontakte';
    $Lang->{
        'Defines parameters for user preference to set behavior of KIXSidebar contact selection.'
        }
        = 'Legt Parameter für die Nutzereinstellung fest, welche das Verhalten der Kontaktauswahl in der KIXSidebar "Kontaktinformation" festlegt.';
    $Lang->{'Select all dynamic fields that should be displayed.'}
        = 'Wählen Sie alle dynamischen Felder, die angezeigt werden sollen.';
    $Lang->{
        'Defines the default item state for new items. It should be one of the item states out of the list below.'
        }
        = 'Definiert den Standardstatus, der genutzt wird, wenn neue Items angelegt werden. Es sollte ein Item-Status aus der unten folgenden Liste sein.';
    $Lang->{
        'Defines all possible item states for the checklist sidebar. Key has to be unique and used for StateIcon list and StateStyle list below.'
        }
        = 'Definiert alle möglichen Item-Status für die Checkliste. Der Schlüssel muss eindeutig sein und wird für die unten folgenden Listen für Style und Icon mit genutzt.';
    $Lang->{'Module Registration for the KIXSidebarChecklist AJAXHandler.'}
        = 'Modulregistrierung für den KIXSidebarChecklist AJAXHandler.';
    $Lang->{'Defines the item state icons for the item states defined above.'}
        = 'Definiert die Icons für die oben definierten Item-Status.';
    $Lang->{'Defines the item state styles for the item states defined above. Use CSS-styles.'}
        = 'Definiert die Styles für die oben definierten Item-Status. CSS-Styles können genutzt werden.';
    $Lang->{'Defines all the ticket states in which the checklist cannot be changed.'}
        = 'Definiert alle Ticketstatus in denen die Checkliste nicht verändert werden kann.';
    $Lang->{'Defines all the ticket state types in which the checklist cannot be changed.'}
        = 'Definiert alle Ticketstatustypen in denen die Checkliste nicht verändert werden kann.';
    $Lang->{'Significant changes of item descriptions will cause state loss.'}
        = 'Signifikante Änderungen am Text der einzelnen Items führen zum Verlust des gesetzten Status.';
    $Lang->{'Checklist'}               = 'Checkliste';
    $Lang->{'No checklist available.'} = 'Keine Checkliste vorhanden.';

    # EO KIXSidebar

    # Service2QueueAssignment...
    $Lang->{'Assigned Queue'}                  = 'Zugewiesene Queue';
    $Lang->{'Assign a queue to this service.'} = 'Diesem Service eine Queue zuordnen.';
    $Lang->{'Assign a prefered queue to this service'} =
        'Diesem Service eine bevorzugte Queue zuordnen';

    # CustomerPreferences
    $Lang->{'Default ticket type'}       = 'Standard-Tickettyp für Ticketerstellung';
    $Lang->{'Your default ticket type'}  = 'Ihr Standard-Tickettyp';
    $Lang->{'Default ticket queue'}      = 'Standard-Queue für Ticketerstellung';
    $Lang->{'Your default ticket queue'} = 'Ihre Standard-Queue';
    $Lang->{'Default service'}           = 'Standard-Service für Ticketerstellung';
    $Lang->{'Your default service'}      = 'Ihr Standard-Service';

    # UserQueueSelectionStyle...
    $Lang->{'Queue selection style'}       = 'Queueauswahl - Methode';
    $Lang->{'Owner selection style'}       = 'Bearbeiterauswahl - Methode';
    $Lang->{'Responsible selection style'} = 'Verantwortlichenauswahl - Methode';
    $Lang->{'Selection Style'}             = 'Auswahlmethode';
    $Lang->{'Configuration of the mapping for the search type. example: Module:::Element => Typ'} =
        'Konfiguration des Mappings für die Suche eingeben. Beispiel: Module::: Element => Typ';

    $Lang->{'LastSubject'}             = 'Letzter Betreff';
    $Lang->{'LastCustomerSubject'}     = 'Letzter Kundenbetreff';
    $Lang->{'TicketNumber'}            = 'Ticket-Nummer';
    $Lang->{'EscalationTime'}          = 'Eskalationszeit';
    $Lang->{'Width'}                   = 'Breite';
    $Lang->{'Pending Time'}            = 'Erinnerungszeit';
    $Lang->{'Pending DateTime'}        = 'Wartezeitpunkt';
    $Lang->{'Pending UntilTime'}       = 'Warten bis';
    $Lang->{'OwnerLogin'}              = 'Bearbeiter (Login)';
    $Lang->{'Owner Login'}             = 'Bearbeiter (Login)';
    $Lang->{'Owner Information'}       = 'Information Bearbeiter';
    $Lang->{'ResponsibleLogin'}        = 'Verantw. (Login)';
    $Lang->{'Responsible Login'}       = 'Verantw. (Login)';
    $Lang->{'Responsible Information'} = 'Information Verantwortlicher';
    $Lang->{'CustomerCompanyName'}     = 'Firma';
    $Lang->{'CustomerUserEmail'}       = 'Kunden-Email';
    $Lang->{'MarkedAs'}                = 'Markiert als';
    $Lang->{'at first select relevant marks above'}
        = 'relevante Markierungen zuvor oberhalb auswählen';

    # Article Flags...
    $Lang->{'Flagged Tickets'}    = 'Markierte Tickets';
    $Lang->{'My Flagged Tickets'} = 'Meine markierten Tickets';
    $Lang->{
        'Defines the default ticket attribute for ticket sorting in the ticket article flag view of the agent interface.'
        } = '';    # explicitely without translation
    $Lang->{
        'Defines the default ticket order in the ticket article flag view of the agent interface. Up: oldest on top. Down: latest on top.'
        } = '';    # explicitely without translation

    $Lang->{'Edit article'}      = 'Artikel bearbeiten';
    $Lang->{'Article edit'}      = 'Artikel bearbeiten';
    $Lang->{'Edit article data'} = 'Artikeldaten bearbeiten';
    $Lang->{'Required permissions to use this option.'}
        = 'Benötigte Rechte zur Bearbeitung des Artikels.';
    $Lang->{'Defines if a ticket lock is required to edit articles'}
        = 'Definiert, ob für die Artikelbearbeitung das Ticket gesperrt werden soll.';
    $Lang->{
        'Article free text options shown in the article edit screen in the agent interface. Possible settings: 0 = Disabled, 1 = Enabled, 2 = Enabled and required.'
        }
        = 'Definiert Anzeige der Artikelfreitextoptionen in der Artikelbearbeitenansicht. Mögliche Werte: 0 = inaktiv, 1 = aktiviert, 2 = aktiviert und Pflicht.';
    $Lang->{'Only ticket responsible can edit articles of the ticket.'}
        = 'Nur der Ticketverantwortlicher darf Artikel des Tickets bearbeiten.';
    $Lang->{'Determines whether the selection fields in the action bar should be displayed as "Modernize".'}
        = 'Legt fest, ob die Auswahlfelder in der Aktionsleiste als "Modernize" dargestellt werden sollen.';
    $Lang->{'Defines if flag is shared with other agents.'} = 'Legt fest, ob ein Flag mit anderen Agenten geteilt wird.';
    $Lang->{'Defines if flag has no edit function.'} = 'Legt fest, ob das Flag keine Bearbeiten-Funktion hat.';
    $Lang->{'DynamicFields that can be filtered in the article table of the agent interface. Possible settings: 0 = Disabled, 1 = Available.'}
        = 'Dynamische Felder, welche in der Artikeltabelle der Agentenoberfläche gefiltert werden können. Mögliche Einstellungen: 0 = deaktiviert, 1 = aktiviert';
    $Lang->{'Defines icons from awesome fonts lib for article flag icons.'} = 'Legt Incos aus der Font Awesome Bibliothek für Artikel-Flag-Icons fest.';
    $Lang->{'Defines additional css styles for article flag icons. This value could be empty.'} = 'Legt zusätzliches CSS für Artikel-Flag-Icons fest. Dieser Wert kann leer sein.';
    $Lang->{'Defines whether article flags should be removed on ticket close. This value could be empty. Use "UserPref" if user could choose this preference by itself and 0 or 1 if not.'} = 'Legt fest, ob Artikel-Falgs beim Schließen eines Tickets entfernt werden sollen. Nutzen Sie "UserPref", wenn der Agent das selbst entscheiden kann oder 0 oder 1, wenn nicht.';
    $Lang->{'Defines whether article flags can be set by every agent or just by owner and responsible.'} = 'Legt fest, ob ein Artikel-Flag von jedem Agenten gesetzt werden kann oder nur von Bearbeiter und Verantwortlichem.';
    $Lang->{'show details for flag'} = 'Zeige Details für Flag';
    $Lang->{'edit details for flag'} = 'Bearbeite Details von Flag';
    $Lang->{'remove flag'}           = 'Entferne Flag';
    $Lang->{'Article Flag Options'}  = 'Artikel-Flag Optionen';
    $Lang->{'show details'}          = 'Details anzeigen';
    $Lang->{'for Article'}           = 'für Artikel';
    $Lang->{'Defines parameters for the AgentTicketZoomTab "Attachments".'} = 'Legt Parameter für das AgentTicketZoomTab "Anlagen" fest.';
    $Lang->{'Dynamic fields shown in the dynamic field tab of the agent interface. Possible settings: 0 = Disabled, 1 = Enabled, 2 = Enabled and required.'} = 'Dynamische Felder, welche Tab "Dynamische Felder" der Agentenoberfläche angezeigt werden können. Mögliche Einstellungen: 0 = deaktiviert, 1 = aktiviert, 2 = aktiviert und Pflicht.';
    $Lang->{'Defines the next state of a ticket after editing a dynamic field, in the ticket dynamic field tab screen of the agent interface.'} = 'Legt den Folgestatus eines Tickets fest nach dem Editieren eines Dynamischen Feldes im Tab "Dynamische Felder" der Agentenoberfläche.';
    $Lang->{'Dynamic fields shown in the process tab of the agent interface. Possible settings: 0 = Disabled, 1 = Enabled, 2 = Enabled and required.'} = 'Dynamische Felder, welche Tab "Prozess-Informationen" der Agentenoberfläche angezeigt werden können. Mögliche Einstellungen: 0 = deaktiviert, 1 = aktiviert, 2 = aktiviert und Pflicht.';
    $Lang->{'Required permissions to use the RemoteDB view screen in the agent interface.'} = 'Benötigte Berechtigungen, um die Remote-DB-Ansicht in der Agentenoberfläche nutzen zu können.';

    # AgentArticleEdit
    $Lang->{'History type for this action.'} = 'Historientyp für diese Aktion.';
    $Lang->{'Frontend module registration for the AgentArticleEdit.'}
        = 'Frontendmodul-Registrierung von AgentArticleEdit.';
    $Lang->{'Required permissions to edit articles.'}
        = 'Benötigte Rechte zur Bearbeitung von Artikeln.';
    $Lang->{'Defines if a ticket lock is required to edit articles.'}
        = 'Definiert, ob für die Artikelbearbeitung das Ticket gesperrt werden soll.';

    $Lang->{'All tickets with this customerID'} = 'Alle Tickets mit dieser Kunden-ID';
    $Lang->{'De-/Select this ticket for merging'}
        = 'Dieses Ticket für das Zusammenfassen auswählen';
    $Lang->{'De-/Select all tickets'}           = 'Alle Tickets aus-/abwählen';
    $Lang->{'View this ticket in a new window'} = 'Dieses Ticket in einem neuen Fenster betrachten';
    $Lang->{'Replied'}                          = 'Beantwortet';
    $Lang->{'Merge to'}                         = 'Zusammenfassen zu';
    $Lang->{'oldest ticket'}                    = 'ältestem Ticket';
    $Lang->{'newest ticket'}                    = 'neuestem Ticket';
    $Lang->{'current ticket'}                   = 'aktuellem Ticket';
    $Lang->{'Merge customer tickets'}           = 'Kundentickets zusammenfassen';
    $Lang->{'Merge all tickets from this customer'} = 'Tickets des aktuellen Kunden zusammenfassen';

    # AgentTicketMergeToCustomer
    $Lang->{
        'Frontend module registration for the AgentTicketMergeToCustomer object in the agent interface.'
        }
        = 'Frontendmodul-Registration des AgentTicketMergeToCustomer-Objekts im Agenten-Oberfläche.';
    $Lang->{
        'Shows a link in the menu that allows to merge all tickets from the ticket customer in the ticket zoom view of the agent interface.'
        }
        = 'Zeigt einen Link im Menü der Ticket-Detailansicht der Agenten-Oberfläche an, der das Zusammenfassen aller Tickets des Ticketkunden ermöglicht.';
    $Lang->{
        'Shows a link in the menu that allows to merge all tickets from the ticket customer in the ticket overview of the agent interface.'
        }
        = 'Zeigt einen Link im Menü der Ticket-übersicht der Agenten-Oberfläche an, der das Zusammenfassen aller Tickets des Ticketkunden ermöglicht.';
    $Lang->{'Selected history types to classify a ticket to be answered.'}
        = 'Auswahl der Historie-Typen, die ein Ticket als beantwortet kennzeichnen.';
    $Lang->{'Selected state types to restrict shown customer tickets.'}
        = 'Auswahl der Status-Typen zur Einschränkung der angezeigten Kundentickets.'
        ;

    # CustomerSearch
    $Lang->{
        'Defines Output filter to provide possibility to open customer ticket search result for result form "print" in new tab.'
        }
        = 'Definiert einen Outputfilter, welcher die Möglichkeit bereitstellt, das Ergebnis der Ticketsuche im Kundenfrontend bei Suchergebnisformat "Drucken" in einem neuen Tab zu öffnen.';
    $Lang->{'Customer ticket search result for "Print" opens in new tab.'}
        = 'Suchergebnis der Ticketsuche im Kundenfrontend für "Drucken" öffnet in einem neuen Tab.';
    $Lang->{'Defines additional search fields to searching for customers in the customer backends. (Key: Identifier, Value: database column)'}
        = 'Definiert weitere Suchfelder für die Suche nach Kunden in den Kunden-Backends. (Schlüssel: Kennung, Wert: Datenbankspalte)';
    # EO CustomerSearch

    # admin frontend
    $Lang->{'Selected Field From Source Field'} = 'Gewählter Wert im Quellfeld';
    $Lang->{'Available Target Fields'}          = 'Verfügbare Zielfelder';
    $Lang->{'Available Target Values'}          = 'Verfügbare Werte im Zielfeld';
    $Lang->{'Depending Dynamic Field Edit'}     = 'Abhängige Dynamische Felder bearbeiten';
    $Lang->{'Available Dynamic Fields'}         = 'Verfügbare Dynamische Felder';
    $Lang->{'Add Depending Field'}              = 'Abhängiges Feld hinzufügen';
    $Lang->{'Add Dynamic Field'}                = 'Dynamisches Feld hinzufügen';
    $Lang->{'Remove Dynamic Field'}             = 'Dynamisches Feld entfernen';
    $Lang->{'Tree Name'}                        = 'Name des Baumes';
    $Lang->{'Selected Dynamic Field'}           = 'Gewähltes Dynamisches Feld';
    $Lang->{'Possible Values'}                  = 'Mögliche Werte';
    $Lang->{'Depending Dynamic Field Add'}      = 'Abhängiges Dynamisches Feld hinzufügen';
    $Lang->{'Depending Dynamic Fields'}         = 'Abhängige Dynamische Felder';
    $Lang->{'Click here to add a depending field'} =
        'Klicken, um ein abhängiges Feld hinzuzufügen';
    $Lang->{'Depending Dynamic Fields - Tree View'} = 'Abhängige Dynamische Felder - Baumansicht';
    $Lang->{'Depending Dynamic Fields Management'}  = 'Verwaltung - Abhängige Dynamische Felder';
    $Lang->{'Create new depending dynamic field or change existing.'} =
        'Abhängige Dynamische Felder erzeugen und verwalten';
    $Lang->{
        'Frontend module registration for the depending dynamic field configuration in the admin interface.'
        } =
        'Frontend Modul Registrierung für die Konfiguration der abhängigen Dynamische Felder in der Administrator-Oberfläche.';
    $Lang->{'Ticket-ACLs to define dynamic fields dependencies.'}
        = 'Ticket-ACLs, um Abhängigkeiten bei dynamischen Feldern festzulegen.';
    $Lang->{
        'Do you really want to delete this depending field and all of its other depending fields?'
        }
        = 'Möchten Sie wirklich das abhängige Feld und alle von diesem abhängigen Felder löschen?';

    $Lang->{'Select a General Catalog Class.'} = 'Wählen Sie eine General Catalog Klasse.';

    # other translations...
    $Lang->{'Please check the config item which is affected by your request'} =
        'Bitte markieren Sie das Config Item, auf welches sich Ihre Anfrage bezieht';
    $Lang->{'Create and manage the definitions for Configuration Items.'} =
        'Erstellen und verwalten Sie die Definitionen für Configuration Items.';
    $Lang->{'Images'}                          = 'Bilder';
    $Lang->{'Load image'}                      = 'Bild laden';
    $Lang->{'Set image text'}                  = 'Bildtext festlegen';
    $Lang->{'Delete image'}                    = 'Bild löschen';
    $Lang->{'Assigned CIs'}                    = 'Zugewiesene CIs';
    $Lang->{'Config Item Data'}                = 'CI Daten';
    $Lang->{'Show CILinks Selection'}          = 'Anzahl der verlinkten ConfigItems pro Seite';
    $Lang->{'Contact info CILinks selection'}  = 'Ansprechpartner-Info: verlinkte ConfigItems';
    $Lang->{'File is no image or image type not supported. Please contact your admin.'}
        = 'Datei ist kein Bild oder Bildtyp wird nicht unterstützt.';
    $Lang->{'Shows a link in the menu to create an email ticket.'}
        = 'Erstellt einen Link im Menu, um ein Emailticket zu erstellen.';
    $Lang->{'Shows a link in the menu to create a phone ticket.'}
        = 'Erstellt einen Link im Menu, um ein Telefonticket zu erstellen.';
    $Lang->{'Defines parameters for the AgentITSMConfigItemZoomTab ConfigItem.'}
        = 'Legt Parameter für das AgentITSMConfigItemZoomTab ConfigItem fest.';
    $Lang->{'Defines parameters for the AgentITSMConfigItemZoomTab Linked Objects.'}
        = 'Legt Parameter für das AgentITSMConfigItemZoomTab Verlinkte Objekte fest.';
    $Lang->{'Defines parameters for the AgentITSMConfigItemZoomTab Images.'}
        = 'Legt Parameter für das AgentITSMConfigItemZoomTab Bilder fest.';
    $Lang->{'Defines parameters for the AgentTicketZoomTab Dummy Tab.'}
        = 'Legt Parameter für das AgentITSMConfigItemZoomTab Dummy fest.';
    $Lang->{
        'Overloads (redefines) existing functions in Kernel::System::ITSMConfigItem. Used to easily add customizations.'
        }
        = 'Überlädt (redefiniert) existierende Funktionen in Kernel::System::ITSMConfigItem. Wird genutzt, um einfach Anpassungen hinzufügen zu können.';
    $Lang->{'ConfigItem link direction for propagating of warning/error incident states.'}
        = 'ConfigItem Linkrichtung zur Übertragung von Warnungs-/Fehlervorfallstatus.';
    $Lang->{'Shows the most important information about this change'}
        = 'Zeigt die wichtigsten Informationen zu diesem Change.';
    $Lang->{'Parameters for the KIXSidebar backend ChangeInfo.'}
        = 'Parameter für das KIXSidebar-Backend ChangeInfo.';
    $Lang->{'Parameters for the KIXSidebar backend ConfigItemInfo.'}
        = 'Parameter für das KIXSidebar-Backend ConfigItemInfo.';
    $Lang->{'Defines the path to save the images.'}
        = 'Legt den Speicherpfad für die ConfigItem-Bilder fest.';
    $Lang->{'Defines an overview module to show the custom view of a configuration item list.'}
        = 'Definiert ein Übersichtsmodul, um die Custom-Ansicht (C) einer ConfigItem-Liste anzuzeigen.';
    $Lang->{'Parameters for the KIXSidebar backend WorkOrderInfo.'}
        = 'Parameter für das KIXSidebar-Backend WorkOrderInfo.';
    $Lang->{'Parameters for the KIXSidebar backend linked config items.'}
        = 'Parameter für das KIXSidebar-Backend Linked Config Items (Zugewiesene CIs).';
    $Lang->{'Frontend module registration for the KIXSidebarLinkedCIsAJAXHandler object.'}
        = 'Frontend Modulregistrierung für das KIXSidebarLinkedCIsAJAXHandler Objekt.';
    $Lang->{
        'Parameters for the pages (in which the CIs are shown) of the custom config item overview. This is a list of available column values can be chosen.'
        }
        = 'Parameter für die Seiten (auf welchen CIs als Liste angezeigt werden) mit Custom Config Item Overview (C). Es wird eine Liste von verfügbaren Spalten angezeigt, die gewählt werden können.';
    $Lang->{'Defined DeploymentStates to hide ConfigItems.'}
        = 'Festgelegte Verwendungsstatus, um ConfigItems zu verstecken.';
    $Lang->{'Defined IncidentStates to hide ConfigItems.'}
        = 'Festgelegte Vorfallstatus, um ConfigItems zu verstecken.';
    $Lang->{'Frontend module registration for the customer interface.'}
        = 'Frontend Modulregistrierung für das Kundenfrontend.';
    $Lang->{'Current Incident Signal'}   = 'Aktueller Vorfallstatus (als Icon)';
    $Lang->{'Current Deployment Signal'} = 'Aktueller Verwendungstatus (als Icon)';
    $Lang->{'Last Changed'}              = 'Zuletzt geändert';
    $Lang->{'WarrantyExpirationDate'}    = 'Garantieablaufdatum';
    $Lang->{'ConfigItemSearch behavior for search over all config item classes'}
        = 'Verhalten der CI-Suche beim Suchen über alle Klassen';
    $Lang->{'Linked config items'} = 'Verknüpfte ConfigItems';
    $Lang->{'All Attributes'}      = 'Alle Attribute';
    $Lang->{'Common Attributes'}   = 'Gemeinsame Attribute';
    $Lang->{'Number of Linked ConfigItems per Page'}
        = 'Anzahl der verknüpften ConfigItems pro Seite';
    $Lang->{'Defines parameters for the AgentITSMWorkOrderZoomTab "Linked Objects".'}
        = 'Legt Parameter fest für das AgentITSMWorkOrderZoomTab "Linked Objects".';
    $Lang->{'Defines the shown columns of CIs in the link table complex view, depending on the CI class. Each entry must be prefixed with the class name and double colons (i.e. Computer::). There are a few CI-Attributes that common to all CIs (example for the class Computer: Computer::Name, Computer::CurDeplState, Computer::CreateTime). To show individual CI-Attributes as defined in the CI-Definition, the following scheme must be used (example for the class Computer): Computer::HardDisk::1, Computer::HardDisk::1::Capacity::1, Computer::HardDisk::2, Computer::HardDisk::2::Capacity::1. If there is no entry for a CI class, then the default columns are shown.'}
        = 'Legt die angezeigten Spalten der CIs in der Komplexansicht der Tabelle "Verlinkte Objekte" fest. Jeder Eintrag muss mit einem Klassennamen gefolgt von Doppelpunkten beginnen (z.B. Computer::). Es gibt einige CI-Attribute, die alle CIs gemeinsam haben (Beispiel für die Klasse Computer: Computer::Name, Computer::CurDeplState, Computer::CreateTime). Um individuelle CI-Attribute anzuzeigen, wie sie in der CI-Definition festgelegt sind, muss das folgende Schema genutzt werden (Beispiel für die Klasse Computer): Computer::HardDisk::1, Computer::HardDisk::1::Capacity::1, Computer::HardDisk::2, Computer::HardDisk::2::Capacity::1. Wenn kein Eintrag für eine CI-Klasse hinterlegt ist, werden die Standardspalten angezeigt.';
    $Lang->{'Defines the image types.'} = 'Legt die Bildtype fest, die geladen werden können.';
    $Lang->{'Parameters for the pages (in which the configuration items are shown).'}
        = 'Parameter für die Seiten, auf denen ConfigItems angezeigt werden.';
    $Lang->{
        'Defines parameters for user preference to set ConfigItemSearch behavior for search over all config item classes.'
        }
        = 'Legt Parameter fest für die Nutzereinstellungen zum Suchverhalten, wenn über alle ConfigItem Attribute gesucht werden soll.';
    $Lang->{
        'Parameters for the dashboard backend of the customer assigned config items widget of the agent interface . "Group" is used to restrict the access to the plugin (e. g. Group: admin;group1;group2;). "Default" determines if the plugin is enabled by default or if the user needs to enable it manually. "CacheTTLLocal" is the cache time in minutes for the plugin.'
        }
        = 'Parameter für das Dashboardbackend des Widgets für die dem Nutzer zugeordneten CIs. "Group" wird genutzt, um den Zugriff einzuschränken  (z.B. Group: admin;group1;group2;). "Default" bestimmt, ob das Plugin standardmäßig aktiviert ist oder ob der Nutzer es manuell aktivieren muss. "CacheTTLLocal" ist die Cachezeit in Minuten für dieses Plugin.';
    $Lang->{'Defines parameters for the AgentITSMChangeZoomTab "Linked Objects".'}
        = 'Legt Parameter für das AgentITSMChangeZoomTab "Linked Objects" fest.';
    $Lang->{'Select Class'} = 'Klasse auswählen';
    $Lang->{'Settings for custom config item list view'}
        = 'Einstellungen für persönliche ConfigItem Listendarstellung';
    $Lang->{'Asset Location'} = 'Asset-Standort';
    $Lang->{'Parent Location'} = 'Übergeordneter Standort';
    $Lang->{'Check for empty fields'} = 'Auf leere Felder prüfen';


    # graph visualization related translations...
    $Lang->{'CI-Classes to consider'} = 'Zu betrachtende CI-Klassen';
    $Lang->{'Defines parameters for the AgentITSMConfigItemZoomTab "LinkGraph".'}
        = 'Bestimmt die Parameter für AgentITSMConfigItemZoomTab "Verknüpfungsgraph".';
    $Lang->{'Required permissions to use the ITSM configuration item zoom screen in the agent interface.'}
        = 'Benötigte Berechtigungen, um den ITSM Configuration Item Zoom Tab im Agenten-Interface nutzen zu können.';
    $Lang->{'Defines which class-attribute should be considered for the icons. Sub-attributes are possible. Value must be key not name of attribute!'}
        = 'Bestimmt welches Klassen-Attribut für die Icons beachtet werden soll. Unterattribute sind möglich. Der Wert muss der Key, nicht der Name des Attributes sein!';
    $Lang->{'Defines the icons for node visualization - key could be a CI-Class (if applicable - e.g. "Computer") or a CI-Class followed by a triple colon and a value of the specified class-attribute (if attribute is "Type" - e.g. "Computer:::Server"). The Icon for a CI-Class is the fallback if no icon for the class-attribute is specified and "Default" is the fallback if no icon for a CI-Class is specified.'}
        = 'Definiert die Icons für die Knotendarstellung - der Schlüssel kann eine CI-Klasse (falls zutreffend - z.B. "Computer") oder eine CI-Klasse gefolgt von einem dreifachen Doppelpunkt und einem Wert des angegebenen Klassenattributes (falls "Type" das Attribut ist - z.B. "Computer:::Server") sein. Das Icon der CI-Klasse ist der Fallback, falls kein Icon für das Klassenattribute definiert ist und "Default" ist der Fallback wenn kein Icon für eine CI-Klasse angegeben ist.';
    $Lang->{'Defines the icons for node visualization if CIs with a certain deployment state are not shown in CMDB overview (postproductive or configured) - key could be a CI-Class (if applicable - e.g. "Computer") or a CI-Class followed by a triple colon and a value of the specified class-attribute (if attribute is "Type" - e.g. "Computer:::Server"). The Icon for a CI-Class is the fallback if no icon for the class-attribute is specified and "Default" is the fallback if no icon for a CI-Class is specified.'}
        = 'Definiert die Icons für die Knotendarstellung falls CIs mit einem bestimmten Verwendungsstatus in der CMDB-Übersicht nicht angezeigt werden (postproductive oder konfiguriert) - der Schlüssel kann eine CI-Klasse (falls zutreffend - z.B. "Computer") oder eine CI-Klasse gefolgt von einem dreifachen Doppelpunkt und einem Wert des angegebenen Klassenattributes (falls "Type" das Attribut ist - z.B. "Computer:::Server") sein. Das Icon der CI-Klasse ist der Fallback, falls kein Icon für das Klassenattribute definiert ist und "Default" ist der Fallback wenn kein Icon für eine CI-Klasse angegeben ist.';
    $Lang->{'Defines the icons for the incident-states - key is the state-type (if applicable - e.g. "operational").'}
        = 'Definiert die Icons für die Vorfallstatus - der Schlüssel ist der Status (falls zutreffend - z.B. "operational")';
    $Lang->{'Show linked services'}     = 'Zeige verknüpfte Services';
    $Lang->{'Linked Services'}          = 'Verknüpfte Services';
    $Lang->{'No linked Services'}       = 'Keine verknüpften Services vorhanden.';
    $Lang->{'Considered CI-Classes'}    = 'Betrachtete CI-Klassen';
    $Lang->{'Saved graphs for this CI'} = 'Gespeicherte Graphen für dieses CI';
    $Lang->{'Too many nodes'}           = 'Zu viele Knoten';
    $Lang->{'More than 100 nodes not possible (currently number: %s)!'}
        = 'Mehr als 100 Knoten sind nicht möglich (aktuelle Anzahl: %s)!';
    $Lang->{'Opens the graph in a separate window.'}
        = 'Öffnet den Graphen in einem separaten Fenster.';
    $Lang->{'Defines the display name for an link graph template. The key is used with the same notation in all following preferences.'} = 'Legt den Anzeigename einer Vorlage für den Verknüpfungsgraph fest. Der Schlüssel wird in den folgenden Einstellungen in der gleichen Schreibweise verwendet.';
    $Lang->{'Defines the needed permission for an link graph template. Key has to be the same defined in CIGraphConfigTemplate###Name.'} = 'Legt die Berechtigungen einer Vorlage für den Verknüpfungsgraph fest. Der Schlüssel muss der gleiche sein, wie unter CIGraphConfigTemplate###Name festgelegt.';
    $Lang->{'Defines the maximum link depth for an link graph template. Key has to be the same defined in CIGraphConfigTemplate###Name.'} = 'Legt die Verknüpfungstiefe einer Vorlage für den Verknüpfungsgraph fest. Der Schlüssel muss der gleiche sein, wie unter CIGraphConfigTemplate###Name festgelegt.';
    $Lang->{'Defines the relevant link types for an object graph template.  Key has to be the same defined in CIGraphConfigTemplate###Name.'} = 'Legt die relevanten Linktypen einer Vorlage für den Verknüpfungsgraph fest. Der Schlüssel muss der gleiche sein, wie unter CIGraphConfigTemplate###Name festgelegt.';
    $Lang->{'Defines the relevant object sub types for an link graph template.  Key has to be the same defined in CIGraphConfigTemplate###Name.'} = 'Legt die relevanten Sub-Typen (Klassen) einer Vorlage für den Verknüpfungsgraph fest. Der Schlüssel muss der gleiche sein, wie unter CIGraphConfigTemplate###Name festgelegt.';
    $Lang->{'Defines adjusting strength for an link graph template. Key has to be the same defined in CIGraphConfigTemplate###Name.'} = 'Legt die Ausrichtungsstärke einer Vorlage für den Verknüpfungsgraph fest. Der Schlüssel muss der gleiche sein, wie unter CIGraphConfigTemplate###Name festgelegt.';

    # ITSMConfigItemEvents
    $Lang->{
        'Config item event module that shows passed parameters BEFORE action is perdormed. May be used as template for own CI-events.'
        }
        = 'Event-Modul für ConfigItems, welches die übergebenden Parameter anzeigt BEVOR die Aktion ausgeführt wurde. Kann als Vorlage für eigene CI-Events genutzt werden.';
    $Lang->{
        'Config item event module that shows passed parameters AFTER action is performed. May be used as template for own CI-events.'
        }
        = 'Event-Modul für ConfigItems, welches die übergebenden Parameter anzeigt NACHDEM die Aktion erfolgt ist. Kann als Vorlage für eigene CI-Events genutzt werden.';
    $Lang->{
        'Defines the config parameters of this item, to show CILinks and be shown in the preferences view.'
        }
        = 'Definiert die Konfigurationsparameter für die verlinkten Config Items in der KIXSidebar und zeigt eine Auswahl in der Nutzereinstellungen an.';

    $Lang->{''} = '';

    # ITSMConfigItemCompare
    $Lang->{'Compare'}                       = 'Vergleichen';
    $Lang->{'Compare Versions'}              = 'Versionen vergleichen';
    $Lang->{'Compare different versions of'} = 'Vergleich verschiedener Versionen von';
    $Lang->{'Select two versions to compare'} =
        'Wählen Sie zwei Versionen, die Sie vergleichen möchten';
    $Lang->{'Do not compare two similar versions!'} =
        'Vergleich von zwei gleichen Versionen nicht möglich.';
    $Lang->{'Compare of'}   = 'Vergleich von';
    $Lang->{'version'}      = 'Version';
    $Lang->{'with version'} = 'mit Version';
    $Lang->{'Added'}        = 'Hinzugefügt';
    $Lang->{'Removed'}      = 'Entfernt';
    $Lang->{'Legend'}       = 'Legende';
    $Lang->{
        'Required permissions to use the compare ITSM configuration item screen in the agent interface.'
        }
        = 'Benötigte Berechtigungen, um die Anzeige zum vergleichen von ConfigItem Versionen im Agentenfrontend zu nutzen.';
    $Lang->{'Frontend module registration for the agent interface.'}
        = 'Frontend Modulregistrierung für den Agenten.';
    $Lang->{'Shows a link in the menu to compare a configuration item with an other.'}
        = 'Zeigt einen Link im Menu an, um zwei ConfigItems miteinander zu vergleichen.';
    $Lang->{
        'Configure an highlightning for a row in the compare table depending on compare result.'
        }
        = 'Konfiguriert die farbliche Hervorhebung für das Vergleichsergebnis.';
    $Lang->{
        'Changes the behaviour of Config Item Version Compare. "Structure" will mark swapped items as changed'
        }
        = 'Ändert das Verhalten vom CI-Versionsvergleich. "Struktur" markiert auch Attribute als geändert, bei denen sich nur die Reihenfolge geändert hat.';

    # LinkedCIs
    $Lang->{
        'Defines in which CI-classes (keys) which attributes need to match the search pattern (values, comma separated if more than one attribute should be searched). For use with sub-attributes try this, key: attribute::sub-attribute, value: owner'
        }
        = 'Legt fest, in welchen CI-Klassen (Schlüssel) welche Attribute mit dem Suchmuster (Inhalt, getrennt durch Komma, falls mehr als ein Attribut gesucht werden soll) übereinstimmen müssen. Bei Verwendung von Sub-Attributen, muss folgendes eingestellt werden, Schlüssel: Attribut::Sub-Attribut, Inhalt: Such-Attribut';
    $Lang->{'Defines which attributes are shown in customer table.'} =
        'Legt fest, welche Attribute in der Customer-Tabelle angezeigt werden.';
    $Lang->{
        'Defines the link type which is used for the link creation between ticket and config item.'
        }
        = 'Legt den Link-Typ fest, welcher für die Erzeugung eines Links zwischen Ticket und Config Item genutzt wird.';
    $Lang->{
        'Common Parameters for the KIXSidebarLinkedCIs backend. You can use CI class specific contact attributes (SearchAttribute:::&lt;CIClass&gt;) as well as multiple contact attributes, separated by comma.'
        }
        =
        'Allgemeine Parameter für das KIXSidebarLinkedCIs Backend. Sie können CI-Klassen-spezifische Ansprechpartner-Attribute (SearchAttribute:::&lt;CIClass&gt;), sowie mehrere Kundennutzer-Attribute verwenden, getrennt mit Komma.';
    $Lang->{'Shows all config items assigned to selected customers.'}
        = 'Zeigt alle Config Items, welche den ausgewählten Kunden zugewiesen sind.';
    $Lang->{'Defines a css style element depending on config item deployment state.'}
        = 'Definiert ein CSS Style Element auf Grundlage des Verwendungsstatus (Deployment State).';
    $Lang->{
        'Defines whether config items with postproductive deployment state should be shown or not.'
        }
        = 'Legt fest, ob ConfigItems vom Verwendungsstatus postproductive in der Übersicht angezeigt werden sollen.';
    $Lang->{
        'Defines which deployment states should not be shown in config item overview. Separate different states by comma.'
        }
        = 'Legt fest, welche Verwendungsstatus in der Übersicht nicht mit angezeigt werden sollen. Mehrere Werte werden durch Komma getrennt.';
    $Lang->{
        'Defines which deployment states should not be shown in config item link graph. Separate different states by comma.'
        }
        = 'Legt fest, welche Verwendungsstatus im Verknüpfungsgraph nicht mit angezeigt werden sollen. Mehrere Werte werden durch Komma getrennt.';

    $Lang->{'Choose the attribute of the config items to filter. Click on the plus next to the selection to add an attribute filter.'}
        = 'Wählen Sie hier die Attribute des CIs, nach denen Sie noch weiter einschränken möchten. Klicken Sie dafür auf das Plus neben der Auswahl.';

    $Lang->{'Only attributes of the following types are shown in the list'}
        = 'Nur Attribute folgender Typen werden in der Liste angezeigt';

    $Lang->{'Assigned owner'} = 'Zugewiesener Besitzer';

    # AgentLinkGraph
    $Lang->{'Link Graph'} = 'Verknüpfungsgraph';
    $Lang->{'Shows this object in its relation to other linked objects'}
        = 'Zeigt dieses Objekt in seinen Beziehungen zu anderen verknüpften Objekten';
    $Lang->{
        'This frame should show the current object with its linked objects, depending on your current selection'
        }
        = 'Dieses Frame zeigt das aktuelle Objekt mit seinen verknüpften Objekten, in Abhängigkeit von Ihrer akt. Auswahl an';
    $Lang->{'Defines parameters for the AgentTicketZoomTab "LinkGraph".'} =
        'Bestimmt die Parameter für AgentTicketZoomTab "Verknüpfungsgraph".';
    $Lang->{'Defines the parameters for the "AgentLinkGraphIFrameDefault".'} =
        'Bestimmt die Parameter für "AgentLinkGraphIFrameDefault".';
    $Lang->{
        'Required permissions to use the ticket zoom screen in the agent interface.'
        }
        = 'Benötigte Berechtigungen, um den Ticket Zoom Tab im Agenten-Interface nutzen zu können.';
    $Lang->{
        'Defines the preselected maximum search depth for IDDFS (iterative deepening depth-first search) in the object graph.'
        }
        = 'Definiert die vorselektierte maximale Suchtiefe für IDDFS (Iterative Tiefensuche) im Objekt-Graphen';
    $Lang->{
        'Defines the colors for link visualization - links are just black if no color is given.'
        }
        = 'Bestimmt die Farben für die Verknüpfungen - ohne Farbe ist die Verknüpfung schwarz.';
    $Lang->{
        'Defines which attribute should be considered for the icons. Sub-attributes are possible. Value must be key not name of attribute!'
        }
        = 'Bestimmt welches Attribut für die Icons beachtet werden soll. Unterattribute sind möglich. Der Wert muss der Key, nicht der Name des Attributes sein!';
    $Lang->{
        'Defines the icons for node visualization - key could be "Ticket" alone or followed by a triple colon and a value of the specified attribute (if attribute is "Type" - e.g. "Ticket:::Problem"). The Icon for "Ticket" is the fallback if no icon for the ticket-attribute is specified and "Default" is the fallback if no icon for "Ticket" is specified.'
        }
        = 'Definiert die Icons für die Knotendarstellung - der Schlüssel kann "Ticket" allein oder gefolgt von einem dreifachen Doppelpunkt und einem Wert des angegebenen Attributes (falls "Type" das Attribut ist - z.B. "Ticket:::Problem") sein. Das Icon für "Ticket" ist der Fallback, falls kein Icon für das Attribute definiert ist und "Default" ist der Fallback, wenn kein Icon für "Ticket" angegeben ist.';

    $Lang->{'Link-Types to follow'}     = 'Zu verfolgende Verknüpfungstypen';
    $Lang->{'Max Link Depth'}           = 'Max. Verknüpfungstiefe';
    $Lang->{'Adjusting Strength'}       = 'Ausrichtungsstärke';
    $Lang->{'Strong'}                   = 'Stark';
    $Lang->{'Medium'}                   = 'Mittel';
    $Lang->{'Weak'}                     = 'Schwach';
    $Lang->{'Show Graph'}               = 'Graph anzeigen';
    $Lang->{'Graph View Configuration'} = 'Konfiguration Graphanzeige';
    $Lang->{'Graph Display'}            = 'Graphanzeige';
    $Lang->{'This feature requires a browser that is capable of displaying SVG-elements.'}
        = 'Diese Funktion erfordert einen Browser, der in der Lage ist SVG-Elemente anzuzeigen.';
    $Lang->{'Something went wrong! Please look into the error-log for more information.'} =
        'Etwas lief falsch! Bitte schauen Sie in das Error-Log für mehr Informationen.';
    $Lang->{'No Objects!'}             = 'Keine Objekte!';
    $Lang->{'No objects displayable.'} = 'Keine Objekte darstellbar.';

    # context menu
    $Lang->{'Show'}                        = 'Zeige';
    $Lang->{'Add link with displayed'}     = 'Verknüpfe mit dargestelltem';
    $Lang->{'Add link with not displayed'} = 'Verknüpfe mit nicht dargestelltem';

    $Lang->{'link with'}     = 'verknüpfen mit';
    $Lang->{'Link as'}       = 'Verknüpfen als';
    $Lang->{'Not possible!'} = 'Nicht möglich!';
    $Lang->{'Either search is empty or there is no matching object!'} =
        'Entweder ist das Suchfeld leer oder es gibt kein passendes Objekt!';
    $Lang->{'Impossible to link a node with itself!'} =
        'Ein Knoten kann nicht mit sich selbst verknüpft werden!';
    $Lang->{'Link-Type does already exists!'} = 'Dieser Verknüpfungstyp besteht bereits!';
    $Lang->{'Either search is empty or there is no matching ticket!'} =
        'Entweder ist das Suchfeld leer oder es gibt kein passendes Ticket!';
    $Lang->{'Impossible to link a ticket with itself!'} =
        'Ein Ticket kann nicht mit sich selbst verknüpft werden!';
    $Lang->{'Adjust'}                       = 'Ausrichten';
    $Lang->{'Graph could not be adjusted!'} = 'Der Graph konnte nicht ausgerichtet werden!';
    $Lang->{
        'Maybe the graph is too complex or too "simple". But you can change the adjusting strength and try again if you like. (simple -> increase; complex -> reduce)'
        }
        = 'Vielleicht ist der Graph zu komplex oder zu "einfach". Aber Sie können die Ausrichtungsstärke reduzieren und es gern noch einmal versuchen.</br>(einfach -> erhöhen; komplex -> reduzieren)';
    $Lang->{'Current zoom level'} = 'Aktuelle Zoom-Stufe';
    $Lang->{'Default size'}       = 'Standardgröße';
    $Lang->{'Fit in'}             = 'Einpassen';

    $Lang->{'Edit selected template'}        = 'Ausgewählte Vorlage anpassen';
    $Lang->{'Fits the graph into the visible area'}
        = 'Passt den Graph in den sichtbaren Bereich ein';
    $Lang->{'Zoom in'}                       = 'Vergrößern';
    $Lang->{'Zoom out'}                      = 'Verkleinern';
    $Lang->{'Zoom to 100%'}                  = 'Auf 100% vergrößern';
    $Lang->{'Tool for defining a zoom-area'} = 'Werkzeug zum Aufziehen des Zoombereiches';
    $Lang->{'Adjust the graph'}              = 'Den Graph ausrichten';
    $Lang->{'Load a graph'}                  = 'Einen Graph laden';
    $Lang->{'Save the graph'}                = 'Den Graph speichern';
    $Lang->{'Print the graph'}               = 'Den Graph drucken';

    $Lang->{'Do you want to set a new link type or delete this connection?'} =
        'Möchten Sie einen neuen Verknüpfungstyp zuweisen oder die Verknüpfung löschen?';
    $Lang->{'Link new as'}                = 'Neu verknüpfen als';
    $Lang->{'Set'}                        = 'Zuweisen';
    $Lang->{'Change direction?'}          = 'Richtung ändern?';
    $Lang->{'as source'}                  = 'als Quelle';
    $Lang->{'as target'}                  = 'als Ziel';
    $Lang->{'Print'}                      = 'Drucken';
    $Lang->{'Followed Link-Types'}        = 'Verfolgte Verknüpfungstypen';
    $Lang->{'Link not created!'}          = 'Verknüpfung nicht angelegt!';
    $Lang->{'Link could not be removed!'} = 'Verknüpfung konnte nicht entfernt werden!';
    $Lang->{'Please look into the error-log for more information.'} =
        'Bitte schauen Sie in das Error-Log für mehr Informationen.';
    $Lang->{'Edit current template'}        = 'Aktuelle Vorlage anpassen';
    $Lang->{'Load Graph'}                   = 'Graph Laden';
    $Lang->{'Saved graphs for this object'} = 'Gespeicherte Graphen für dieses Objekt';
    $Lang->{'There are no saved graphs!'}   = 'Es gibt keine gespeicherten Graphen!';
    $Lang->{'Save'}                         = 'Speichern';
    $Lang->{'No name is given!'}            = 'Kein Name angegeben!';
    $Lang->{'There is already a saved graph with this name!'} =
        'Es gibt bereits einen gespeicherten Graphen mit diesem Namen!';
    $Lang->{'Saved'}                      = 'Gespeichert';
    $Lang->{'Graph could not be saved!'}  = 'Graph konnte nicht gespeichert werden!';
    $Lang->{'Load'}                       = 'Laden';
    $Lang->{'Graph could not be loaded!'} = 'Graph konnte nicht geladen werden!';
    $Lang->{'The standard configuration was used instead.'} =
        'Die Standard-Konfiguration wurde stattdessen benutzt.';
    $Lang->{'Information about loaded graph'} = 'Informationen zum geladenen Graphen';
    $Lang->{'No longer existent nodes'}       = 'Nicht mehr vorhandene Knoten';
    $Lang->{'New nodes'}                      = 'Neue Knoten';
    $Lang->{'Save graph for'}                 = 'Graph speichern für';
    $Lang->{'What should be done?'}           = 'Was soll getan werden?';
    $Lang->{'Create new'}                     = 'Neu anlegen';
    $Lang->{'Overwrite'}                      = 'Überschreiben';
    $Lang->{'Which one?'}                     = 'Welchen?';

    # CustomerSearch
    $Lang->{'Show pending time as remaining time or as point of time with date and time.'}
        = 'Zeigt die Wartezeit als verbleibende Zeit oder als Zeitpunkt mit Datum und Zeit an.';
    $Lang->{'Defines user preference to decide how pending time should be displayed.'}
        = 'Legt die Nutzereinstellung fest, welche entscheidet, wie die Wartezeit angezeigt werden soll.';
    $Lang->{'Display of pending time'} = 'Anzeige der Wartezeit';
    $Lang->{'Show pending time as'}    = 'Anzeige der Wartezeit als';
    $Lang->{'Remaining Time'}          = 'Verbleibende Zeit';
    $Lang->{'Point of Time'}           = 'Zeitpunkt';

    # EO CustomerSearch

    $Lang->{'Select to decide whether article colors should be used.'}
        = 'Wählen Sie, ob Artikelfarben genutzt werden sollen.';
    $Lang->{'Use article colors'} = 'Artikelfarben werden genutzt.';
    $Lang->{'Defines user preference to decide whether article colors should be used.'}
        = 'Legt fest, ob Artikelfarben genutzt werden sollen';
    $Lang->{'Column ticket filters for linked objects.'}
        = 'Ticket-Filter-Spalte für Ticketübersichten in den verknüpften Objekten.';
    $Lang->{'Overwrite existing search profiles?'} = 'Existierende Suchprofile überschreiben?';
    $Lang->{
        'Search profiles with same name already exists. Type new search profile name into the textfield to rename copied profile.'
        }
        = 'Suchprofile mit gleichem Namen existieren bereits. Tragen Sie einen neuen Profilnamen in das Textfeld ein, um das kopierte Profil umzubenennen.';

    # redirect messages
    $Lang->{'Ticket template successfully updated!'} = 'Ticket-Vorlage erfolgreich aktualisiert!';
    $Lang->{'Ticket template could not be updated!'}
        = 'Ticket-Vorlage konnte nicht aktualisiert werden!';
    $Lang->{'Copy of ticket template successfully created!'}
        = 'Kopie der Ticket-Vorlage erfolgreich angelegt!';
    $Lang->{'Ticket template could not be copied!'} = 'Ticket-Vorlage konnte nicht kopiert werden!';
    $Lang->{'Ticket template successfully deleted!'} = 'Ticket-Vorlage erfolgreich gelöscht!';
    $Lang->{'Ticket template could not be deleted!'}
        = 'Ticket-Vorlage konnte nicht gelöscht werden!';

    # frontend
    $Lang->{'Pending Date Offset'} = 'Warten bis-Verschiebung';
    $Lang->{
        'Time in minutes that gets added to the actual time if setting a pending-state (e.g. 1440 = 1 day)'
        }
        = 'Zeit in Minuten, die zur aktuellen Zeit addiert wird, wenn ein Warte-Status gesetzt wird (z.B. 1440 = 1 Tag)';
    $Lang->{'This field will be filled by customer data. It cannot be prepopulated.'}
        = 'Dieses Feld wird durch die Kunden-Daten bestimmt. Es kann nicht vorausgefüllt werden.';
    $Lang->{'First of all, please select or add a ticket template.'}
        = 'Bitte wählen Sie zunächst eine Ticket-Vorlage aus oder legen Sie eine neue an.';
    $Lang->{'Please insert the template name for the copy of the selected template.'}
        = 'Bitte geben Sie einen Template-Namen für die Kopie der ausgewählten Vorlage an.';
    $Lang->{'Name for new template'}        = 'Name der neuen Vorlage';
    $Lang->{'Add ticket template'}          = 'Ticketvorlage hinzufügen';
    $Lang->{'Ticket Template Configurator'} = 'Ticketvorlagen Konfigurator';
    $Lang->{'Create new quick ticket template or change existing.'}
        = 'Quick-Ticket-Vorlagen erzeugen und verwalten.';
    $Lang->{'Link type'}      = 'Verknüpfungstyp';
    $Lang->{'Link direction'} = 'Verknüpfungsrichtung';
    $Lang->{
        'Old ticket templates have to be migrated from SysConfig to database before dealing with!'
        }
        = 'Alte Ticketvorlagen müssen von der SysConfig in die Datenbank übertragen werden, bevor mit ihnen gearbeitet werden kann!';
    $Lang->{'Click here to migrate ticket templates'} = 'Klicken, um Ticketvorlagen zu übertragen';
    $Lang->{'Click here to add a ticket template'}    = 'Klicken, um Ticketvorlage hinzuzufügen';
    $Lang->{'Migrate ticket templates'}               = 'Ticketvorlagen übertragen';
    $Lang->{'Ticket template migration successful'} = 'übertragen der Ticketvorlagen erfolgreich.';
    $Lang->{'No existing or matching quick tickets'}
        = 'Es sind keine oder keine passenden Ticket-Vorlagen vorhanden';
    $Lang->{'A: agent frontend; C: customer frontend'}
        = 'A: Agenten-Frontend, C: Kunden-Frontend';
    $Lang->{'delete'}                        = 'Löschen';
    $Lang->{'Download all ticket templates'} = 'Alle Ticketvorlagen herunterladen';
    $Lang->{'Upload ticket templates'}       = 'Ticketvorlagen hochladen';
    $Lang->{'Available for user groups'}     = 'Verfügbar für Nutzergruppen';
    $Lang->{'Empty value'}                   = 'leerer Wert';

    $Lang->{'Person not found'}                  = 'Person nicht gefunden';
    $Lang->{'Article Subject'}                   = 'Artikel Betreff';
    $Lang->{'Article Body'}                      = 'Artikel Inhalt';
    $Lang->{'Accounted Time'}                    = 'Erfasste Zeit';
    $Lang->{'Lock State'}                        = 'Sperrstatus';
    $Lang->{'New Note'}                          = 'Neue Notiz';
    $Lang->{'Articles'}                          = 'Artikel';
    $Lang->{'DynamicFields'}                     = 'Dynamische Felder';
    $Lang->{'Remarks'}                           = 'Anmerkungen';
    $Lang->{'Remarks successfully saved!'}       = 'Anmerkungen erfolgreich gespeichert!';
    $Lang->{'Remarks could not be saved!'}       = 'Anmerkungen konnten nicht gespeichert werden!';
    $Lang->{'Ticket data successfully updated!'} = 'Ticket-Daten erfolgreich aktualisiert!';
    $Lang->{'Ticket data could not be updated!'} =
        'Ticket-Daten konnten nicht aktualisiert werden!';
    $Lang->{'DynamicField successfully updated!'} =
        'Dynamisches Feld erfolgreich aktualisiert!';
    $Lang->{'DynamicField could not be updated!'} =
        'Dynamisches Feld konnte nicht aktualisiert werden!';
    $Lang->{'DynamicField successfully saved!'} =
        'Dynamisches Feld erfolgreich gespeichert!';
    $Lang->{'DynamicField could not be saved!'} =
        'Dynamisches Feld konnte nicht gespeichert werden!';
    $Lang->{'Show ticket ScratchPad in ticket view.'} =
        'Anzeigen des Ticket-Notizblocks in der Ticket-Ansicht.';
    $Lang->{'No attachments available'}     = 'Keine Anlagen vorhanden';
    $Lang->{'Direct URL to article %s: %s'} = 'Link zum Artikel %s: %s';
    $Lang->{'Filter for attachments'}       = 'Filter für Anlagen';
    $Lang->{'Defines which ticket data parameters are displayed in direct data presentation'} =
        'Definiert welche Daten in der Direktdatenanzeige dargestellt werden.';
    $Lang->{'Defines which ticket freetext data parameters are displayed.'} =
        'Definiert welche TicketFreitext Daten dargestellt werden.';
    $Lang->{'Preloaded Content Dummy'} = 'Vorab geladener Dummyinhalt';
    $Lang->{'Shows some preloaded content dummy page'} =
        'Zeigt vorgeladenden Inhalt einer Platzhalterseite';
    $Lang->{'Shows all objects linked with this ticket'} =
        'Zeigt alle mit diesem Ticket verknüpften Objekte';
    $Lang->{'Shows a list of all article attachments of this ticket'} =
        'Zeigt eine Liste aller Artikelanhänge dieses Tickets';
    $Lang->{'Shows all article of this ticket'} = 'Zeigt die Artikel dieses Tickets';
    $Lang->{'Shows the most important information about this ticket'} =
        'Zeigt die wichtigsten Informationen dieses Tickets';
    $Lang->{'Redefine the FreeTextField 3 for article to use it as FAQ-Workflow trigger.'} =
        'Definiert bevorzugte Beschriftungen fuer interne Ticketattributnamen.';
    $Lang->{'Defines parameters for the AgentTicketZoomTab "Ticket Core Data".'}
        = 'Definiert Parameter für das AgentTicketZoomTab "Ticketkerndaten".';
    $Lang->{'Required permissions to use the ticket note screen in the agent interface.'} =
        'Benötigte Rechte, um das Notiztab im Agenteninterface zu nutzen.';
    $Lang->{
        'Defines if a ticket lock is required in the ticket note screen of the agent interface (if the ticket is not locked yet, the ticket gets locked and the current agent will be set automatically as its owner).'
        } =
        'Legt fest, ob ein Ticket gesperrt werden muss im Notiztab. Falls das Ticket noch nicht gesperrt ist, wird es gesperrt und der aktuelle Agent wird automatisch als Bearbeiter gesetzt.';
    $Lang->{'Defines if ticket move is enabled in this screen.'} =
        'Legt fest, ob der Queuewechsel in dieser Ansicht aktiviert ist.';
    $Lang->{
        'Sets the ticket type in the ticket note screen of the agent interface (Ticket::Type needs to be activated).'
        } =
        'Aktiviert die Tickettypauswahl im Notiztab des Agenteninterfaces (Ticket::Type muss aktiviert sein).';
    $Lang->{
        'Sets the service in the ticket note screen of the agent interface (Ticket::Service needs to be activated).'
        } =
        'Aktiviert die Serviceauswahl im Notiztab des Agenteninterfaces (Ticket::Service muss aktiviert sein).';
    $Lang->{'Sets the ticket owner in the ticket note screen of the agent interface.'} =
        'Aktiviert die Ticket-Bearbeiterauswahl im Notiztab des Agenteninterfaces.';
    $Lang->{'Sets if ticket owner must be selected by the agent.'} =
        'Legt fest, ob die Auswahl des Bearbeiters ein Pflichtfeld ist.';
    $Lang->{
        'Sets the responsible agent of the ticket in the ticket note screen of the agent interface.'
        } =
        'Aktiviert die Auswahl für den verantwortlichen Agenten im Notiztab des Agenteninterfaces.';
    $Lang->{
        'If a note is added by an agent, sets the state of a ticket in the ticket note screen of the agent interface.'
        } =
        'Aktiviert die Auswahl für den Status im Notiztab des Agenteninterfaces.';
    $Lang->{
        'Defines the next state of a ticket after adding a note, in the ticket note screen of the agent interface.'
        } =
        'Definiert die möglichen Folgestatus nach Hinzufügen einer Notiz.';
    $Lang->{
        'Defines the default next state of a ticket after adding a note, in the ticket note screen of the agent interface.'
        } =
        'Definiert den Standard-Folgestatus nach Hinzufügen einer Notiz.';
    $Lang->{'Allows adding notes in the ticket note screen of the agent interface.'} =
        'Legt fest, ob das Notizfeld angezeigt werden soll.';
    $Lang->{
        'Sets the default subject for notes added in the ticket note screen of the agent interface.'
        } =
        'Legt den Standardbetreff für das Notiztab fest.';
    $Lang->{
        'Sets the default body text for notes added in the ticket note screen of the agent interface.'
        } =
        'Legt den Standardbody für das Notiztab fest.';
    $Lang->{
        'Shows a list of all the involved agents on this ticket, in the ticket note screen of the agent interface.'
        } =
        'Zeigt eine Liste der involvierten Agenten zu diesem Ticket.';
    $Lang->{
        'Shows a list of all the possible agents (all agents with note permissions on the queue/ticket) to determine who should be informed about this note, in the ticket note screen of the agent interface.'
        } =
        'Zeigt eine Liste aller möglichen Agenten zu diesem Ticket (alle Agenten, welche die Berechtigung note haben bzgl. des Tickets oder der Queue), um festzulegen, wer über die neue Notiz informiert werden sollte.';
    $Lang->{
        'Defines the default type of the note in the ticket note screen of the agent interface.'
        }
        =
        'Legt den Standardtyp für das Notiztab fest.';
    $Lang->{'Specifies the different note types that will be used in the system.'} =
        'Spezifiziert die verschiedenen genutzten Notiztypen';
    $Lang->{'Shows the ticket priority options in the ticket note screen of the agent interface.'} =
        'Aktiviert die Auswahl für die Priorität im Notiztab des Agenteninterfaces.';
    $Lang->{'Defines the default ticket priority in the ticket note screen of the agent interface.'}
        =
        'Legt die Standardpriorität für das Notiztab fest.';
    $Lang->{'Shows the title fields in the ticket note screen of the agent interface.'} =
        'Zeigt das Titelfeld im Notiztab.';
    $Lang->{
        'Defines the history type for the ticket note screen action, which gets used for ticket history in the agent interface.'
        } =
        'Legt den History-Typ, welcher für die Ticket-Historie genutzt wird, für das Notiztab fest.';
    $Lang->{
        'Defines the history comment for the ticket note screen action, which gets used for ticket history in the agent interface.'
        } =
        'Legt den History-Kommentar, welcher für die Ticket-Historie genutzt wird, für das Notiztab fest.';
    $Lang->{
        'Dynamic fields shown in the ticket note screen of the agent interface. Possible settings: 0 = Disabled, 1 = Enabled, 2 = Enabled and required.'
        } =
        'Dynamische Felder, die im Notiztab angezeigt werden sollen. Mögliche Einstellungen: 0 = Deaktiviert, 1 = Aktiviert, 2 = Aktiviert und Pflicht.';
    $Lang->{'Required permissions to use the ticket core data tab in the agent interface.'} =
        'Benötigte Rechte, um das Kerndatentab im Agenteninterface zu nutzen.';
    $Lang->{
        'Defines if a ticket lock is required in the ticket core data tab of the agent interface (if the ticket is not locked yet, the ticket gets locked and the current agent will be set automatically as its owner).'
        } =
        'Legt fest, ob ein Ticket im Kerndatentab gesperrt sein muss. Falls das Ticket noch nicht gesperrt ist, wird es gesperrt und der aktuelle Agent wird automatisch als Bearbeiter gesetzt.';
    $Lang->{
        'Sets the ticket type in the ticket core data tab of the agent interface (Ticket::Type needs to be activated).'
        } =
        'Aktiviert die Tickettypauswahl im Kerndatentab des Agenteninterfaces (Ticket::Type muss aktiviert sein).';
    $Lang->{
        'Sets the service in the ticket core data tab of the agent interface (Ticket::Service needs to be activated).'
        } =
        'Aktiviert die Serviceauswahl im Kerndatentab des Agenteninterfaces (Ticket::Service muss aktiviert sein).';
    $Lang->{'Sets the ticket owner in the ticket core data tab of the agent interface.'} =
        'Aktiviert die Ticket-Bearbeiterauswahl im Kerndatentab des Agenteninterfaces.';
    $Lang->{
        'Sets the responsible agent of the ticket in the ticket core data tab of the agent interface.'
        } =
        'Aktiviert die Auswahl für den verantwortlichen Agenten im Kerndatentab des Agenteninterfaces.';
    $Lang->{
        'If a note is added by an agent, sets the state of a ticket in the ticket core data tab of the agent interface.'
        } =
        'Aktiviert die Auswahl für den Status im Kerndatentab des Agenteninterfaces.';
    $Lang->{
        'Defines the next state of a ticket after adding a note, in the ticket core data tab of the agent interface.'
        } =
        'Legt den Folgestatus für das Kerndatentab fest.';
    $Lang->{
        'Defines the default next state of a ticket after adding a note, in the ticket core data tab of the agent interface.'
        } =
        'Legt den Standardfolgestatus für das Kerndatentab fest.';
    $Lang->{'Allows adding notes in the ticket core data tab of the agent interface.'} =
        'Erlaubt das Hinzufügen von Notizen im Kerndatentab.';
    $Lang->{
        'Sets the default subject for notes added in the ticket core data tab of the agent interface.'
        } =
        'Legt den Standardbetreff für das Kerndatentab fest.';
    $Lang->{
        'Sets the default body text for notes added in the ticket core data tab of the agent interface.'
        } =
        'Legt den Standardbody für das Kerndatentab fest.';
    $Lang->{
        'Shows a list of all the involved agents on this ticket, in the ticket core data tab of the agent interface.'
        } =
        'Zeigt eine Liste der involvierten Agenten zu diesem Ticket.';
    $Lang->{
        'Shows a list of all the possible agents (all agents with note permissions on the queue/ticket) to determine who should be informed about this note, in the ticket core data tab of the agent interface.'
        } =
        'Zeigt eine Liste aller möglichen Agenten zu diesem Ticket (alle Agenten, welche die Berechtigung note haben bzgl. des Tickets oder der Queue), um festzulegen, wer über die neue Notiz informiert werden sollte.';
    $Lang->{
        'Defines the default type of the note in the ticket core data tab of the agent interface.'
        }
        =
        'Legt den Standardtyp für das Kerndatentab fest.';
    $Lang->{'Shows the ticket priority options in the ticket core data tab of the agent interface.'}
        =
        'Aktiviert die Auswahl für die Priority im Kerndatentab des Agenteninterfaces.';
    $Lang->{
        'Defines the default ticket priority in the ticket core data tab of the agent interface.'
        }
        =
        'Legt den Standardbetreff für das Kerndatentab fest.';
    $Lang->{'Shows the title fields in the ticket core data tab of the agent interface.'} =
        'Aktiviert das Titelfeld im Kerndatentab des Agenteninterfaces.';
    $Lang->{
        'Defines the history type for the ticket core data tab action, which gets used for ticket history in the agent interface.'
        } =
        'Legt den Standardbetreff für das Kerndatentab fest.';
    $Lang->{
        'Defines the history comment for the ticket core data tab action, which gets used for ticket history in the agent interface.'
        } =
        'Legt den History-Kommentar, welcher für die Ticket-Historie genutzt wird, für das Kerndatentab fest.';
    $Lang->{
        'Dynamic fields shown in the edit core data tab of the agent interface. Possible settings: 0 = Disabled, 1 = Enabled, 2 = Enabled and required.'
        } =
        'Dynamische Felder, die im Kerndatentab angezeigt werden sollen. Mögliche Einstellungen: 0 = Deaktiviert, 1 = Aktiviert, 2 = Aktiviert und Pflicht.';
    $Lang->{'Ticket Core Data'}             = 'Ticketkerndaten';
    $Lang->{'Edit this tickets core data!'} = 'Die Kerndaten dieses Tickets bearbeiten!';
    $Lang->{'Question'}                     = 'Frage';
    $Lang->{'Delete Attachments'}           = 'Anlagen löschen';
    $Lang->{'Download Attachments'}         = 'Anlagen herunterladen';
    $Lang->{'Do you really want to delete the selected attachments?'}
        = 'Möchten Sie die ausgewählten Anlagen wirklich löschen?';
    $Lang->{'Defines article flags.'} =
        'Definiert Artikel Flags';
    $Lang->{'Article Flag'} =
        'Artikel Flag';
    $Lang->{'Defines icons for article icons.'} =
        'Definiert Icons zu den Artikel Flags.';
    $Lang->{
        'Dynamic fields shown in the article tab of the agent interface. Possible settings: 0 = Disabled, 1 = Enabled, 2 = Enabled and required.'
        } =
        'Dynamische Felder, welche im Artikeltab der Agentenoberfläche angezeigt werden. Mögliche Einstellungen: 0 = deaktiviert, 1 = aktiviert, 2 = aktiviert und benötigt.';
    $Lang->{'Notes'}                         = 'Notizen';
    $Lang->{'Set article flag'}              = 'Setze Artikel Flag';
    $Lang->{'show details / edit'}           = 'Details anzeigen / editieren';
    $Lang->{'remove'}                        = 'Artikel Flag entfernen';
    $Lang->{'- mark as -'}                   = '- markieren als -';
    $Lang->{'MarkAs'}                        = 'markieren als';
    $Lang->{'Link ticket with:'}             = 'Verknüpfe Ticket mit:';
    $Lang->{'Link Configuration Item with:'} = 'Verknüpfe Configuration Item mit:';
    $Lang->{'Link Change with:'}             = 'Verknüpfe Change mit:';
    $Lang->{'Link Workorder with:'}          = 'Verknüpfe Workorder mit:';
    $Lang->{'Enable quick link in linked objects tab (different backends have to be defined first)'}
        =
        'Aktiviert QuickLink im Tab Verlinkte Objekte (die unterschiedlichen Backends müssen vorher aktiviert und konfiguriert werden.)';
    $Lang->{'QuickLink backend registration.'} = 'QuickLink Backend Registrierung.';

    $Lang->{
        'Defines either realname or realname and email address should be shown in the article detail view.'
        }
        = 'Legt fest, ob nur der Name oder Name und Email-Adresse in den Artikeldetails angezeigt werden sollen.';
    $Lang->{
        'Defines either realname or realname and email address should be shown in the article list.'
        }
        = 'Legt fest, ob nur der Name oder Name und Email-Adresse in der Artikelliste angezeigt werden sollen.';
    $Lang->{'Realname and email address'} = 'Name und Emailadresse';
    $Lang->{'Realname'}                   = 'Name';
    $Lang->{'Ticket-ACLs to define shown tabs if ticket is process ticket.'}
        = 'Ticket-ACL um angezeigte Tabs festzulegen, wenn das Ticket ein Prozessticket ist.';
    $Lang->{'There could be more linked objects than displayed due to lack of permissions.'}
        = 'Aufgrund fehlender Berechtigungen können mehr verlinkte Objekte existieren, als angezeigt werden.';

    $Lang->{
        'information: even though this package is not certified by KIX Group, this does NOT mean that you should NOT use it.'
        }
        = 'Paket ist zwar nicht durch KIX Gruppe verifiziert - das bedeutet aber NICHT, dass dieses Paket nicht verwendet werden kann oder darf.';
    $Lang->{
        'Disables the unrequested automatic communication of installed packages and other system details to KIX AG.'
        }
        = 'Deaktiviert die unaufgeforderte automatische Kommunikation, der installierten Pakete und anderer System-Details, zur KIX AG.';
    $Lang->{
        'Enables the unrequested automatic communication of installed packages and other system details to the path.'
        }
        = 'Aktiviert die unaufgeforderte automatische Kommunikation, der installierten Pakete und anderer System-Details, zum angegebenen Pfad.';
    $Lang->{
        'Even though this package is not certified by KIX Group, this does NOT mean that you should NOT use it.'
        }
        = 'Das Paket ist zwar nicht durch KIX Gruppe verifiziert - das bedeutet aber NICHT, dass dieses Paket nicht verwendet werden kann oder darf.';

    $Lang->{'Pre-create loader cache.'} = 'Loadercache vorgenerieren.';

    # general translation...
    $Lang->{'Nothing found.'} = 'Keine gefunden.';
    $Lang->{'item(s) found'}  = 'Einträge gefunden';

    # CI translation...
    $Lang->{'CI search'} = 'CI-Suche';

    # FAQ translations...
    $Lang->{'Relevant FAQ items'} = 'Relevante FAQ-Einträge';
    $Lang->{'Shows FAQ items relevant to current ticket.'}
        = 'Zeigt relevante FAQ-Einträge zum aktuellen Ticket.';

    # Ticket translation...
    $Lang->{'Similar Tickets'} = 'Ähnliche Tickets';

    # Ticket-CI translation...
    $Lang->{'CIs of similar Tickets'} = 'CIs von ähnlichen Tickets';

    # general translation...
    $Lang->{'if possible'}          = 'Wenn möglich';
    $Lang->{'mandatory'}            = 'Zwingend';
    $Lang->{'With Ticketnumber'}    = 'Mit Ticketnummer';
    $Lang->{'Without Ticketnumber'} = 'Ohne Ticketnummer';

    # Agent Overlay
    $Lang->{'Agent Notifications'}                  = 'Agentenbenachrichtigungen';
    $Lang->{'Agent Notification (Popup/Dashboard)'} = 'Agentenbenachrichtigung (Popup/Dashboard)';
    $Lang->{'Decay'}                                = 'Verfallszeit';
    $Lang->{'BusinessTime'}                         = 'Geschäftszeit';
    $Lang->{'Article sender type'}                  = 'Artikel-Absender-Typ';

    $Lang->{'Add entry'}                 = 'Eintrag hinzufügen';
    $Lang->{'Create new email ticket.'}  = 'Neues Email-Ticket erstellen.';
    $Lang->{'Create new phone ticket.'}  = 'Neues Telefon-Ticket erstellen.';
    $Lang->{'Agents <-> Groups'}         = 'Agenten <-> Gruppen';
    $Lang->{'Agents <-> Roles'}          = 'Agenten <-> Rollen';
    $Lang->{'Auto Responses <-> Queues'} = 'Auto Antworten <-> Queues';
    $Lang->{'Change password'}           = 'Passwort ändern';
    $Lang->{'Please supply your new password!'}
        = 'Bitte geben Sie ein neues Passwort ein!';

    $Lang->{'Companies'}                 = 'Kunden-Firma';
    $Lang->{'Customer company updated!'} = 'Kunden-Firma aktualisiert';
    $Lang->{'Company Tickets'}           = 'Firmen Tickets';
    $Lang->{'Customers <-> Groups'}      = 'Kunden <-> Gruppen';
    $Lang->{'Customers <-> Services'}    = 'Kunden <-> Services';
    $Lang->{'Customer Services'}         = 'Kunden-Services';
    $Lang->{'Limit'}                     = 'Limitierung';
    $Lang->{'timestamp'}                 = 'Zeitstempel';
    $Lang->{'Types'}                     = 'Typen';
    $Lang->{'Bulk-Action'}               = 'Sammelaktion';
    $Lang->{'Un-/subscribe ticket watch in the ticket bulk screen of the agent interface.'}               = 'Aktiviert das Setzen oder Aufheben von Beobachten an Tickets in der Sammelaktion des Agentenfrontends.';
    $Lang->{'Responsible Tickets'}       = 'Verantwortliche Tickets';
    $Lang->{'Ticket is locked for another agent!'} =
        'Ticket ist durch einen anderen Agenten gesperrt';
    $Lang->{'Link this ticket to other objects!'} =
        'Ticket mit anderen Objekten verknüpfen!';
    $Lang->{"Wildcards like '*' are allowed."}   = "Platzhalter wie '*' sind erlaubt.";
    $Lang->{'Search for customers.'}             = 'Suche nach Kunden.';
    $Lang->{'Change the ticket classification!'} = 'ändern der Ticket-Klassifizierung!';
    $Lang->{'Change the ticket responsible!'}    = 'ändern des Ticket-Verantwortlichen!';
    $Lang->{'Select new owner'}                  = 'Neuen Bearbeiter auswählen';
    $Lang->{'Filter for SLAs'}                   = 'Filter für SLAs';

    $Lang->{'NEW'}       = 'NEU';
    $Lang->{'Classes'}   = 'Klassen';
    $Lang->{'DeplState'} = 'Verwendungsstatus';
    $Lang->{'InciState'} = 'Vorfallsstatus';

    $Lang->{'Config Item Search Result: Class'} = 'Such-Ergebnis: Config Item: Klasse';
    $Lang->{'ITSM ConfigItem'}                  = 'Config Item';

    $Lang->{'Impact \ Criticality'}   = 'Auswirkung \ Kritikalität';
    $Lang->{'TicketAccumulationITSM'} = 'Ticket-Aufkommen ITSM';

    $Lang->{'Download'}                            = 'Herunterladen';
    $Lang->{'Upload'}                              = 'Hochladen';
    $Lang->{'Current Queues-Groups-Roles Concept'} = 'Aktuelles Queues-Gruppen-Rollen Konzept';
    $Lang->{'Queues-Groups-Roles Management'}      = 'Queues-Gruppen-Rollen Verwaltung';
    $Lang->{'Import, export and show Queue-Group-Role Concept.'}
        = 'Importieren, exportieren und anzeigen des Queues-Gruppen-Rollen Konzepts';
    $Lang->{'Queues Groups Roles'}         = 'Queues Gruppen Rollen';
    $Lang->{'Queues <-> Groups <-> Roles'} = 'Queues <-> Gruppen <-> Rollen';
    $Lang->{
        'Attention: Depending on the number of queues, groups and roles, this process may take several minutes!'
        }
        = 'Achtung: Abhängig von der Anzahl der Queues, Gruppen und Rollen kann dieser Vorgang einige Minuten dauern!';
    $Lang->{'Show Queues-Groups-Roles Concept'} = 'Anzeigen des Queues-Gruppen-Rollen Konzepts';
    $Lang->{'Show'}                             = 'Anzeigen';

    # translations missing in ImportExport...
    $Lang->{'Column Seperator'}                                    = 'Spaltentrenner';
    $Lang->{'Charset'}                                             = 'Zeichensatz';
    $Lang->{'Restrict export per search'}                          = 'Export mittels Suche einschränken';
    $Lang->{'Step 1 of 5 - Edit common information'}               = 'Schritt 1 von 5 - Allgemeine Informationen bearbeiten';
    $Lang->{'Step 2 of 5 - Edit object information'}               = 'Schritt 2 von 5 - Objektinformationen bearbeiten';
    $Lang->{'Step 3 of 5 - Edit format information'}               = 'Schritt 3 von 5 - Formatinformationen bearbeiten';
    $Lang->{'Step 4 of 5 - Edit mapping information'}              = 'Schritt 4 von 5 - Mappinginformationen bearbeiten';
    $Lang->{'Step 5 of 5 - Edit search information'}               = 'Schritt 5 von 5 - ';
    $Lang->{'Force import in configured customer company backend'} = 'Import in ausgewähltes Kunden-Firmen-Backend erzwingen';
    $Lang->{'Customer Company Backend'}                            = 'Kunden-Firma-Backend';

    # service2customeruser ex-/import...
    $Lang->{'Service available for CU'} = 'Service für Kundennutzer verfügbar';
    $Lang->{'Contact login'}      = 'Ansprechpartner-Login';
    $Lang->{'Validity of service assignment for CU'} =
        'Gültigkeit der Servicezuordnung zu Kundennutzer';

    # service ex-/import...
    $Lang->{'Full Service Name'}                  = 'Vollständiger Servicename';
    $Lang->{'Short Service Name'}                 = 'Kurzservicename';
    $Lang->{'Service Type (ITSM only)'}           = 'Servicetyp (nur ITSM)';
    $Lang->{'Criticality (ITSM only)'}            = 'Kritikalität (nur ITSM)';
    $Lang->{'Current Incident State (ITSM only)'} = 'Akt. Störungsstatus (nur ITSM)';
    $Lang->{'Current Incident State Type (ITSM only)'}
        = 'Akt. Störungsstatustyp (nur ITSM)';
    $Lang->{'Default Service Type'} = 'Standard-Servicetyp';
    $Lang->{'Validity'}             = 'Gültigkeit';
    $Lang->{'Default Validity'}     = 'Standard-Gültigkeit';
    $Lang->{'Default Criticality'}  = 'Standard-Kritikalität';

    # SLA ex-/import...
    $Lang->{'Default SLA Type'}                       = 'Standard-SLA-Typ';
    $Lang->{'Default Minimum Time Between Incidents'} = 'Standard Minimumzeit zwischen Störungen';
    $Lang->{'Max. number of columns which may contain assigned services'}
        = 'Max. Anzahl von Spalten die zugewiesene Services enthalten können';
    $Lang->{'Max. number of assigned services columns'} = 'Max. Spaltenanzahl zugew. Services';

    $Lang->{'SLA Type (ITSM only)'} = 'SLA Typ (nur ITSM)';
    $Lang->{'Min. Time Between Incidents (ITSM only)'}
        = 'Standard Minimumzeit zwischen Störungen (nur ITSM)';
    $Lang->{'SolutionNotify (percent)'}        = 'SolutionNotify (Prozent)';
    $Lang->{'SolutionTime (business minutes)'} = 'SolutionTime (Geschäftsminuten)';
    $Lang->{'UpdateNotify (percent)'}          = 'UpdateNotify (Prozent)';
    $Lang->{'UpdateTime (business minutes)'}   = 'UpdateTime (Geschäftsminuten)';
    $Lang->{'FirstResponseNotify (percent)'}   = 'FirstResponseNotify (Prozent)';
    $Lang->{'FirstResponseTime (business minutes)'}
        = 'FirstResponseTime (Geschäftsminuten)';
    $Lang->{'Calendar Name'} = 'Kalendername';

    $Lang->{'Export with labels'} = 'Mit Beschriftung exportieren';

    # SysConfig descriptions
    $Lang->{'Object backend module registration for the import/export moduls.'} =
        'Objekt-Backend Modul Registration des Import/Export Moduls.';

    # SwitchButton
    $Lang->{'Frontend module registration for the SwitchButton object in the Customer interface.'} =
        'Frontendmodul-Registration des SwitchButton-Objekts im Customer-Interface.';
    $Lang->{'Frontend module registration for the SwitchButton object in the Agents interface.'} =
        'Frontendmodul-Registration des SwitchButton-Objekts im Agenten Interface.';
    $Lang->{'Switch Button'} = 'Wechsel-Button';
    $Lang->{'switch button'} = 'Wechsel-Button';
    $Lang->{'Switch-Button'} = 'Wechsel-Button';
    $Lang->{'Switch to customer frontend and login automatically'} =
        'In das Kunden-Frontend wechseln und automatisch einloggen';
    $Lang->{'Switch to agent frontend and login automatically'} =
        'In das Agenten-Frontend wechseln und automatisch einloggen';

    $Lang->{'Only works for type Answer and Forward'}
        = 'Funktioniert nur für Typen Beantworten und Weiterleiten';

    $Lang->{'Text Modules'}            = 'Text-Bausteine';
    $Lang->{'Text modules'}            = 'Text-Bausteine';
    $Lang->{'Text modules selection'}  = 'Text-Bausteine Auswahl';
    $Lang->{'Text module'}             = 'Text-Baustein';
    $Lang->{'Filter for text modules'} = 'Filter für Text-Bausteine';
    $Lang->{'Filter for queues'}       = 'Filter für Queues';
    $Lang
        ->{'A text module is default text to write faster answer (with default text) to customers.'}
        = 'Ein Text-Baustein ist ein vordefinierter Text, um Kunden schneller antworten zu können.';
    $Lang->{'Don\'t forget to add a new text module a queue!'}
        = 'Ein neuer Text-Baustein muss einer Queue zugewiesen werden!';
    $Lang->{'add a text module'}               = 'Einen Text-Baustein hinzufügen';
    $Lang->{'delete this text module'}         = 'Diesen Text-Baustein löschen';
    $Lang->{'edit'}                            = 'Bearbeiten';
    $Lang->{'(Click here to add)'}             = '(Hier klicken um hinzufügen)';
    $Lang->{'Click here to add a text module'} = 'Hier klicken um einen Text-Baustein hinzufügen';
    $Lang->{'Change Queue relations for text modules'}
        = 'Ändern der Queue-Zuordnung für Text-Baustein';
    $Lang->{'Change text modules relations for Queue'}
        = 'Ändern der Text-Baustein-Zuordnung für Queue';
    $Lang->{'Change text module settings'}
        = 'Ändern der Text-Baustein Einstellungen';
    $Lang->{'A text module should have a name!'}
        = 'Ein Text-Baustein sollte einen Namen haben!';
    $Lang->{'A text module should have a content!'}
        = 'Ein Text-Baustein sollte einen Inhalt haben!';
    $Lang->{'Assume to text'} = 'In den Text übernehmen';
    $Lang->{'Double click on the text module, which should be added to the body'}
        = 'Auf den Text-Baustein doppelt klicken, der in den Text übernommen werden soll';
    $Lang->{'Move over the text module, which should be displayed'}
        = 'Über den Text-Baustein fahren, der angezeigt werden soll';
    $Lang->{'Undo'}                    = 'Rückgängig';
    $Lang->{'Paste'}                   = 'Einfügen';
    $Lang->{'Queue Assignment'}        = 'Zuordnung zu Queue';
    $Lang->{'Ticket Type Assignment'}  = 'Zuordnung zu Tickettyp';
    $Lang->{'Ticket State Assignment'} = 'Zuordnung zu Ticketstatus';
    $Lang->{'Filter Overview'}         = 'Übersicht einschränken';
    $Lang->{'Limit Results'}           = 'Anzahl limitieren';
    $Lang->{'Add a new text module'}   = 'Einen neuen Textbaustein hinzufügen';
    $Lang->{'New text module'}         = 'neuer Textbaustein';
    $Lang->{'Add text module'}         = 'Textbaustein anlegen';
    $Lang->{'entries shown'}           = 'Einträge angezeigt';
    $Lang->{'Download'}                = 'Herunterladen';
    $Lang->{'Text Modules Management'} = 'Verwaltung Textbausteine';
    $Lang->{'Upload text modules'}     = 'Textbausteine hochladen';
    $Lang->{'Import failed - No file uploaded/received'}
        = 'Import fehlgeschlagen - keine Datei hochgeladen/empfangen';
    $Lang->{'Result of the upload'}      = 'Ergebnis des Imports';
    $Lang->{'entries uploaded'}          = 'Hochgeladene Einträge';
    $Lang->{'updated'}                   = 'aktualisiert';
    $Lang->{'added'}                     = 'hinzugefügt';
    $Lang->{'update failed'}             = 'Aktualisierung fehlgeschlagen';
    $Lang->{'insert failed'}             = 'Hinzufügen fehlgeschlagen';
    $Lang->{'Download all text modules'} = 'Alle Textbausteine herunterladen';
    $Lang->{'Download result as XML'}
        = 'Herunterladen des Ergebnisses als XML';
    $Lang->{'Summary'}           = 'Zusammenfassung';
    $Lang->{'Available in'}      = 'Verfügbar in';
    $Lang->{'Agent Frontend'}    = 'Agentenfrontend';
    $Lang->{'Customer Frontend'} = 'Kundenfrontend';
    $Lang->{'Public Frontend'}   = 'Öffentliches Frontend';
    $Lang->{'A: agent frontend; C: customer frontend, P: public frontend'} =
        'A: Agentenoberfläche; C: Kundenoberfläche; P: Öffentliche Oberfläche';
    $Lang->{'Assigend To'} = 'Zugeordnet zu';
    $Lang->{'No existing or matching text module'}
        = 'Es sind keine oder keine passenden Text-Bausteine vorhanden';
    $Lang->{'No existing or matching text module category'}
        = 'Es sind keine oder keine passenden Textbaustein-Kategorien vorhanden';
    $Lang->{'Categories'}                      = 'Kategorien';
    $Lang->{'Text Module Category Management'} = 'Verwaltung Textbaustein-Kategorien';
    $Lang->{'Text Module Categories'}          = 'Text-Baustein-Kategorien';
    $Lang->{'Create and manage text module categories.'}
        = 'Erstellen und Verwalten von Textbaustein-Kategorien.';
    $Lang->{'Category Selection'}  = 'Kategorienauswahl';
    $Lang->{'Category Assignment'} = 'Zuordnung zur Kategorie';
    $Lang->{'List for category'}   = 'Liste für Kategorie';
    $Lang->{'ALL'}                 = 'ALLE';
    $Lang->{'NOT ASSIGNED'}        = 'NICHT ZUGEWIESEN';
    $Lang->{'Do you really want to delete this category and all of it\'s subcategories ?'}
        = 'Wollen Sie diese Kategorie und alle ihre Unterkategorien wirklich löschen ?';
    $Lang->{'Keywords'}                = 'Schlüsselwörter';
    $Lang->{'Add category'}            = 'Kategorie hinzufügen';
    $Lang->{'Download all categories'} = 'Alle Kategorien herunterladen';
    $Lang->{'Upload categories'}       = 'Kategorien hochladen';
    $Lang->{'Parent Category'}         = 'Übergeordnete Kategorie';
    $Lang->{'Text module category'}    = 'Textmodulkategorie';
    $Lang->{'successful loaded.'}      = 'erfolgreich hochgeladen.';
    $Lang->{'Import failed - No file uploaded/received.'}
        = 'Import fehlgeschlagen - Keine Datei hochgeladen/erhalten.';
    $Lang->{'Do you really want to delete this text module?'}
        = 'Wollen Sie diesen Textbaustein wirklich löschen?';
    $Lang->{'Delete this text module'}
        = 'Diese Textbaustein löschen';

    # TextModules
    $Lang->{'Frontend module registration for the AdmintTextModules object in the admin interface.'}
        =
        'Frontendmodul-Registration des AdminTextModules-Objekts im Admin-Interface.';
    $Lang->{'Frontend module registration for the AdminQueueTextModules object in the admin area.'}
        =
        'Frontendmodul-Registration des AdminQueueTextModules-Objekts im Admin-Bereich.';
    $Lang->{
        'Defines if the messages body is reset after ticket type or queue change. Relevant for automatic loading of a single text module.'
        } =
        'Definiert ob die Nachricht bei Aenderung von Tickettyp oder Queue zurueckgesetzt wird. Relevant fuer autom. Laden eines einzelnen Textbausteins.';
    $Lang->{'Default value for maximum number of entries shown in TextModule overview.'} =
        'Standardauswahl fuer maximale Anzahl an angezeigten Textbausteinen in Uebersicht.';
    $Lang->{'Default value for Do-Not-Add-Flag in XML-textmodule upload.'} =
        'Standardauswahl fuer Nicht-Hinzufuegen-Kennung in XML-Textbausteinupload.';
    $Lang->{
        'If activated queues offered for use in EditView are limited by the selected language (language short identifier must be contained as subqueuename in complete queue name).'
        } =
        'Wenn aktiviert, werden die Queues in der Bearbeitenansicht basierend auf der Sprachauswahl eingeschraenkt (Sprachkuerzel muss als Subqueuename in vollstaendigem Queuenamen enthalten sein).';
    $Lang->{'Select frontend agent modules where text modules are activated.'} =
        'Festlegung in welchen Agent-Frontend-Modulen die Textbausteine aktiviert sind.';
    $Lang->{'Additional and extended TextModule methods.'} =
        'Zusaetzliche und erweiterte TextModule-Methoden.';
    $Lang->{'Default values for uploaded TextModules.'} =
        'Standardwerte fuer hochgeladene Textbausteine.';
    $Lang->{'List of JS files to always be loaded for the customer interface.'} =
        'Liste von JS-Dateien, die immer im Kunden-Interface geladen werden.';
    $Lang->{'Show or hide the text modules'} = 'Text-Bausteine zeigen oder verstecken';
    $Lang->{'Default value for maximum number of entries shown in TextModuleCategory overview.'} = 'Standardwert für die maximale Anzahl an angezeigten Einträgen.';

    $Lang->{'Create and manage text templates.'} = 'Erstellen und verwalten von Textbausteinen.';
    $Lang->{'Text module Management'}            = 'Text-Bausteine Verwaltung';
    $Lang->{'Text modules <-> Queue Management'} = 'Text-Bausteine <-> Queue Verwaltung';
    $Lang->{'Text Modules <-> Queues'}           = 'Text-Bausteine <-> Queues';
    $Lang->{'Assign text templates to queues.'}  = 'Textbausteine zu Queues zuordnen.';

    $Lang->{'Please select the type of printout'} = 'Bitte den Typ des Ausdrucks auswählen';

    $Lang->{'Print Richtext'} = 'Richtextausdruck';
    $Lang->{'Print Standard'} = 'Standardausdruck';

    $Lang->{'Ask every time'} = 'Immer nachfragen';
    $Lang->{'Print richtext'} = 'Richtextausdruck';
    $Lang->{'Print standard'} = 'Standardausdruck';

    # translations missing in ImportExport...
    $Lang->{'Column Seperator'}           = 'Spaltentrenner';
    $Lang->{'Charset'}                    = 'Zeichensatz';
    $Lang->{'Restrict export per search'} = 'Export mittels Suche einschränken';
    $Lang->{'ValidID (not used in import anymore, use Validity instead)'}
        = 'ValidID (wird nicht im Import verwendet, bitte stattdessen Validity nutzen';
    $Lang->{'Default Email'}                                   = 'Standard Email';
    $Lang->{'Default Validity'}                                = 'Standard Gültigkeit';
    $Lang->{'Password Suffix (pw=login+suffix - only import)'} = 'Passwortsuffix (pw=Login+Suffix)';
    $Lang->{'Max. number of Custom Queues'}                    = 'Max. Anzahl Meine Queues';
    $Lang->{'Max. number of roles'}                            = 'Max. Anzahl der Rollen';
    $Lang->{'Partially changed - see log for details'}         = 'Teilweise geändert - siehe Log';

    # Template: AAAITSMIncidentProblemManagement
    $Lang->{'Add decision to ticket'} = 'Entscheidung an Ticket hängen';
    $Lang->{'Decision Date'}          = 'Entscheidung';
    $Lang->{'Decision Result'}        = 'Entscheidung';
    $Lang->{'Due Date'}               = 'Fälligkeitsdatum';
    $Lang->{'Reason'}                 = 'Begründung';
    $Lang->{'Recovery Start Time'}    = 'Wiederherstellung Startzeit';
    $Lang->{'Repair Start Time'}      = 'Reparatur Startzeit';
    $Lang->{'Review Required'}        = 'Nachbearbeitung erforderlich';
    $Lang->{'closed with workaround'} = 'provisorisch geschlossen';

    # Template: AgentTicketActionCommon
    $Lang->{'Change Decision of Ticket'}    = 'Die Entscheidung des Tickets ändern';
    $Lang->{'Change ITSM fields of ticket'} = 'Ändern der ITSM Felder des Tickets';
    $Lang->{'Service Incident State'}       = 'Service Vorfallsstatus';

    # Template: AgentTicketEmail
    $Lang->{'Link ticket'} = 'Ticket verknüpfen';

    # Template: AgentTicketOverviewPreview
    $Lang->{'Criticality'} = 'Kritikalität';
    $Lang->{'Impact'}      = 'Auswirkung';

    # Template: AgentTicketOverview...
    $Lang->{'From which page should be selected the tickets.'}
        = 'Von welchen Seiten sollen die Tickets ausgewählt werden';
    $Lang->{'From which page should be selected the config items.'}
        = 'Von welchen Seiten sollen die ConfigItems ausgewählt werden';
    $Lang->{'Current Page'}     = 'aktuelle Seite';
    $Lang->{'All Pages'}        = 'alle Seiten';
    $Lang->{'Ticket selection'} = 'Ticketauswahl';
    $Lang->{'CI selection'}     = 'CI-Auswahl';
    $Lang->{'passed Objects'}   = 'übergebene Objekte';
    $Lang->{'You have selected a larger number (###) of objects. Please note that this can lead to a loss of performance! Do you want to continue?'}
        = 'Sie haben eine größere Anzahl (###) an Objekten selektiert. Bitte beachten Sie, dass dies zu Performanceeinbußen führen kann! Möchten Sie fortfahren?';
    $Lang->{'Locking the tickets, please wait a moment...'}
        = 'Die Tickets werden gesperrt, bitte warten Sie einen Moment...';
    $Lang->{'Tickets will be saved, please wait a moment...'}
        = 'Tickets werden gespeichert, bitte warten Sie einen Moment...';
    $Lang->{'Unlocking the tickets, please wait a moment...'}
        = 'Die Tickets werden entsperrt, bitte warten Sie einen Moment...';
    $Lang->{'Config items will be saved, please wait a moment...'}
        = 'ConfigItems werden gespeichert, bitte warten Sie einen Moment...';
    $Lang->{'The current process has been canceled because no objects to be processed are available.'}
        = 'Der laufende Prozess wurde abgebrochen, da keine zu bearbeitenden Objekte verfügbar sind.';
    $Lang->{'%s objects are skipped during the process.'}
        = 'Es werden im laufendem Prozess %s Objekte übersprungen.';

    # SysConfig
    $Lang->{'Add a decision!'}                = 'Hinzufügen einer Entscheidung!';
    $Lang->{'Additional ITSM Fields'}         = 'Zusätzliche ITSM Felder';
    $Lang->{'Additional ITSM ticket fields.'} = '';
    $Self->{Translation}
        ->{'Allows adding notes in the additional ITSM field screen of the agent interface.'}
        =
        'Erlaubt das Hinzufügen von Notizen in der zusätzlichen ITSM-Oberfläche im Agenten-Interface.';
    $Lang->{'Allows adding notes in the decision screen of the agent interface.'} =
        'Erlaubt das Hinzufügen von Notizen im Entscheidungs-Bildschirm im Agenten-Interface.';
    $Lang->{'Change the ITSM fields!'} = 'Ändern der ITSM-Felder!';
    $Lang->{'Decision'}                = 'Entscheidung';
    $Lang->{
        'Defines if a ticket lock is required in the additional ITSM field screen of the agent interface (if the ticket isn\'t locked yet, the ticket gets locked and the current agent will be set automatically as its owner).'
        }
        =
        'Bestimmt, ob dieser Screen im Agenten-Interface das Sperren des Tickets voraussetzt. Das Ticket wird (falls nötig) gesperrt und der aktuelle Agent wird als Bearbeiter gesetzt.';
    $Lang->{
        'Defines if a ticket lock is required in the decision screen of the agent interface (if the ticket isn\'t locked yet, the ticket gets locked and the current agent will be set automatically as its owner).'
        }
        =
        'Bestimmt, ob dieser Screen im Agenten-Interface das Sperren des Tickets voraussetzt. Das Ticket wird (falls nötig) gesperrt und der aktuelle Agent wird als Bearbeiter gesetzt.';
    $Lang->{
        'Defines if the service incident state should be shown during service selection in the agent interface.'
        }
        =
        'Bestimmt, ob der Service Incident Status während der Service-Auswahl im Agenten-Interface angezeigt werden soll.';
    $Lang->{
        'Defines the default body of a note in the additional ITSM field screen of the agent interface.'
        }
        =
        'Definiert den Standard-Inhalt einer Notiz in der zusätzliche ITSM Felder-Oberfläche im Agenten-Interface.';
    $Self->{Translation}
        ->{'Defines the default body of a note in the decision screen of the agent interface.'}
        =
        'Definiert den Standard-Inhalt einer Notiz in der Entscheidungs-Oberfläche im Agenten-Interface.';
    $Lang->{
        'Defines the default next state of a ticket after adding a note, in the additional ITSM field screen of the agent interface.'
        }
        =
        'Bestimmt den Folgestatus für Tickets, für die über die zusätzlichen ITSM Felder im Agenten-Interface eine Notiz hinzugefügt wurde.';
    $Lang->{
        'Defines the default next state of a ticket after adding a note, in the decision screen of the agent interface.'
        }
        =
        'Bestimmt den Folgestatus für Tickets, für die in der Entscheiduns-Oberfläche im Agenten-Interface eine Notiz hinzugefügt wurde.';
    $Lang->{
        'Defines the default subject of a note in the additional ITSM field screen of the agent interface.'
        }
        =
        'Definiert den Standard-Betreff einer Notiz in der zusätzliche ITSM Felder-Oberfläche im Agenten-Interface.';
    $Self->{Translation}
        ->{'Defines the default subject of a note in the decision screen of the agent interface.'}
        =
        'Definiert den Standard-Betreff einer Notiz in der Entscheidungs-Oberfläche im Agenten-Interface.';
    $Lang->{
        'Defines the default ticket priority in the additional ITSM field screen of the agent interface.'
        }
        =
        'Definiert die Standard-Priorität in der zusätzliche ITSM Felder-Oberfläche im Agenten-Interface.';
    $Self->{Translation}
        ->{'Defines the default ticket priority in the decision screen of the agent interface.'}
        =
        'Definiert die Standard-Priorität in der Entscheidungs-Oberfläche im Agenten-Interface.';
    $Lang->{
        'Defines the default type of the note in the additional ITSM field screen of the agent interface.'
        }
        =
        'Definiert den Standard-Typ einer Notiz in der zusätzliche ITSM Felder-Oberfläche im Agenten-Interface.';
    $Self->{Translation}
        ->{'Defines the default type of the note in the decision screen of the agent interface.'}
        =
        'Definiert den Standard-Typ einer Notiz in der Entscheidungs-Oberfläche im Agenten-Interface.';
    $Lang->{
        'Defines the history comment for the additional ITSM field screen action, which gets used for ticket history.'
        }
        =
        'Steuert den Historien-Kommentar für die Aktionen in der Oberfläche zusätzliche ITSM-Felder im Agentenbereich.';
    $Lang->{
        'Defines the history comment for the decision screen action, which gets used for ticket history.'
        }
        =
        'Steuert den Historien-Kommentar für die Entscheidungs-Aktion im Agentenbereich.';
    $Lang->{
        'Defines the history type for the additional ITSM field screen action, which gets used for ticket history.'
        }
        =
        '';
    $Lang->{
        'Defines the history type for the decision screen action, which gets used for ticket history.'
        }
        =
        '';
    $Lang->{
        'Defines the next state of a ticket after adding a note, in the additional ITSM field screen of the agent interface.'
        }
        =
        '';
    $Lang->{
        'Defines the next state of a ticket after adding a note, in the decision screen of the agent interface.'
        }
        =
        '';
    $Lang->{
        'Dynamic fields shown in the additional ITSM field screen of the agent interface. Possible settings: 0 = Disabled, 1 = Enabled, 2 = Enabled and required.'
        }
        =
        '';
    $Lang->{
        'Dynamic fields shown in the decision screen of the agent interface. Possible settings: 0 = Disabled, 1 = Enabled, 2 = Enabled and required.'
        }
        =
        '';
    $Lang->{
        'Dynamic fields shown in the ticket search screen of the agent interface. Possible settings: 0 = Disabled, 1 = Enabled.'
        }
        =
        '';
    $Lang->{
        'Dynamic fields shown in the ticket zoom screen of the agent interface. Possible settings: 0 = Disabled, 1 = Enabled.'
        }
        =
        '';
    $Lang->{
        'Enables the stats module to generate statistics about the average of ITSM ticket first level solution rate.'
        }
        =
        '';
    $Lang->{
        'Enables the stats module to generate statistics about the average of ITSM ticket solution.'
        }
        =
        '';
    $Lang->{
        'If a note is added by an agent, sets the state of a ticket in the additional ITSM field screen of the agent interface.'
        }
        =
        '';
    $Lang->{
        'If a note is added by an agent, sets the state of a ticket in the decision screen of the agent interface.'
        }
        =
        '';
    $Self->{Translation}
        ->{'Required permissions to use the additional ITSM field screen in the agent interface.'}
        =
        '';
    $Self->{Translation}
        ->{'Required permissions to use the decision screen in the agent interface.'}
        =
        '';
    $Lang->{
        'Sets the service in the additional ITSM field screen of the agent interface (Ticket::Service needs to be activated).'
        }
        =
        'Setzt den Service in der zusätzliche ITSM-Felder-Oberfläche für Tickets im Agentenbereich (Ticket::Type muss aktiviert sein).';
    $Lang->{
        'Sets the service in the decision screen of the agent interface (Ticket::Service needs to be activated).'
        }
        =
        'Setzt den Service in der Entscheidungs-Oberfläche für Tickets im Agentenbereich (Ticket::Service muss aktiviert sein).';
    $Self->{Translation}
        ->{'Sets the ticket owner in the additional ITSM field screen of the agent interface.'}
        =
        'Setzt den Ticket-Bearbeiter in der zusätzliche ITSM Felder-Oberfläche im Agenten-Interface.';
    $Lang->{'Sets the ticket owner in the decision screen of the agent interface.'} =
        'Setzt den Bearbeiter in der Entscheidungs-Oberfläche für Tickets im Agentenbereich.';
    $Lang->{
        'Sets the ticket responsible in the additional ITSM field screen of the agent interface.'
        }
        =
        'Setzt den Ticket-Verantwortlichen in der zusätzliche ITSM Felder-Oberfläche im Agenten-Interface.';
    $Self->{Translation}
        ->{'Sets the ticket responsible in the decision screen of the agent interface.'}
        =
        'Setzt den Ticket-Verantwortlichen in der Entscheidungs-Oberfläche für Tickets im Agentenbereich.';
    $Lang->{
        'Sets the ticket type in the additional ITSM field screen of the agent interface (Ticket::Type needs to be activated).'
        }
        =
        'Setzt den Ticket-Typ in der zusätzliche ITSM-Felder-Oberfläche für Tickets im Agentenbereich (Ticket::Type muss aktiviert sein).';
    $Lang->{
        'Sets the ticket type in the decision screen of the agent interface (Ticket::Type needs to be activated).'
        }
        =
        'Setzt den Ticket-Typ in der Entscheidungs-Oberfläche für Tickets im Agentenbereich (Ticket::Type muss aktiviert sein).';
    $Lang->{
        'Shows a link in the menu to change the decision of a ticket in its zoom view of the agent interface.'
        }
        =
        'Zeigt in der Agenten-Oberfläche imTicket-Menü einen Link an um die Entscheidung an einem Ticket zu ändern';
    $Lang->{
        'Shows a link in the menu to modify additional ITSM fields in the ticket zoom view of the agent interface.'
        }
        =
        'Zeigt einen Link in der Menu-Leiste in der Zoom-Ansicht im Agenten-Interface an, der es ermöglicht die zusätzlichen ITSM-Felder zu bearbeiten.';
    $Lang->{
        'Shows a list of all the involved agents on this ticket, in the additional ITSM field screen of the agent interface.'
        }
        =
        'Zeigt in der Oberfläche zusätzliche ITSM-Felder der Agenten-Oberfläche eine Liste aller am Ticket beteiligten Agenten.';
    $Lang->{
        'Shows a list of all the involved agents on this ticket, in the decision screen of the agent interface.'
        }
        =
        'Zeigt in der Oberfläche Entscheidung der Agenten-Oberfläche eine Liste aller am Ticket beteiligten Agenten.';
    $Lang->{
        'Shows a list of all the possible agents (all agents with note permissions on the queue/ticket) to determine who should be informed about this note, in the additional ITSM field screen of the agent interface.'
        }
        =
        '';
    $Lang->{
        'Shows a list of all the possible agents (all agents with note permissions on the queue/ticket) to determine who should be informed about this note, in the decision screen of the agent interface.'
        }
        =
        '';
    $Lang->{
        'Shows the ticket priority options in the additional ITSM field screen of the agent interface.'
        }
        =
        'Zeigt die Ticket-Priorität in der zusätzliche ITSM-Felder-Oberfläche im Agenten-Interface.';
    $Self->{Translation}
        ->{'Shows the ticket priority options in the decision screen of the agent interface.'}
        =
        'Zeigt die Ticket-Priorität in der Entscheidungs-Oberfläche im Agenten-Interface.';
    $Self->{Translation}
        ->{'Shows the title fields in the additional ITSM field screen of the agent interface.'}
        =
        'Zeigt den Ticket-Titel in der zusätzliche ITSM-Felder-Oberfläche für Tickets im Agentenbereich.';
    $Lang->{'Shows the title fields in the decision screen of the agent interface.'}
        =
        'Zeigt den Ticket-Titel in der Entscheidungs-Oberfläche für Tickets im Agentenbereich.';
    $Lang->{'Ticket decision.'} = '';

    # Template: AAAITSMConfigItem
    $Lang->{'Address'}                     = 'Adresse';
    $Lang->{'Admin Tool'}                  = 'Admin Tool';
    $Lang->{'Backup Device'}               = 'Backup Gerät';
    $Lang->{'Beamer'}                      = 'Beamer';
    $Lang->{'Building'}                    = 'Gebäude';
    $Lang->{'CIHistory::ConfigItemCreate'} = 'Neues ConfigItem (ID=%s)';
    $Lang->{'CIHistory::ConfigItemDelete'} = 'ConfigItem (ID=%s) gelöscht';
    $Lang->{'CIHistory::DefinitionUpdate'}
        = 'Definition des ConfigItems aktualisiert (ID=%s)';
    $Lang->{'CIHistory::DeploymentStateUpdate'}
        = 'Verwendungsstatus geändert (neu=%s; alt=%s)';
    $Lang->{'CIHistory::IncidentStateUpdate'}
        = 'Vorfallsstatus geändert (neu=%s; alt=%s)';
    $Lang->{'CIHistory::LinkAdd'}       = 'Link auf %s (Typ=%s) hinzugefügt';
    $Lang->{'CIHistory::LinkDelete'}    = 'Link auf %s (Typ=%s) gelöscht';
    $Lang->{'CIHistory::NameUpdate'}    = 'Name geändert (neu=%s; alt=%s)';
    $Lang->{'CIHistory::ValueUpdate'}   = 'Attribut %s von "%s" auf "%s" geändert';
    $Lang->{'CIHistory::VersionCreate'} = 'Neue Version erzeugt (ID=%s)';
    $Lang->{'CIHistory::VersionDelete'} = 'Version %s gelöscht';
    $Lang->{'CIHistory::AttachmentAdd'} = 'Anhang (%s) hinzugefügt';
    $Lang->{'CIHistory::AttachmentDelete'} = 'Anhang (%s) gelöscht';
    $Lang->{'CPU'}                         = 'CPU';
    $Lang->{'Camera'}                      = 'Kamera';
    $Lang->{'Capacity'}                    = 'Kapazität';
    $Lang->{'Change Definition'}           = 'Definition ändern';
    $Lang->{'Change of definition failed! See System Log for details.'}
        = 'Ändern der Definition fehlgeschlagen! Im System Log finden Sie weitere Informationen.';
    $Lang->{'Client Application'}     = 'Client Anwendung';
    $Lang->{'Client OS'}              = 'Client Betriebssystem';
    $Lang->{'Concurrent Users'}       = 'Gleichzeitige User';
    $Lang->{'Config Item-Area'}       = 'Config Item-Bereich';
    $Lang->{'Config Items available'} = 'Config Items verfügbar';
    $Lang->{'Config Items shown'}     = 'Config Items angezeigt';
    $Lang->{'CMDB'}                   = 'CMDB';
    $Lang->{'Demo'}                   = 'Demo';
    $Lang->{'Desktop'}                = 'Desktop';
    $Lang->{'Developer Licence'}      = 'Entwickler Lizenz';
    $Lang->{'Docking Station'}        = 'Docking Station';
    $Lang->{'Duplicate'}              = 'Duplizieren';
    $Lang->{'Embedded'}               = 'Embedded';
    $Lang->{'Empty fields indicate that the current values are kept'}
        = 'Leere Felder belassen den aktuellen Wert';
    $Lang->{'Enterprise Licence'}            = 'Enterprise Lizenz';
    $Lang->{'Expiration Date'}               = 'Ablaufdatum';
    $Lang->{'Expired'}                       = 'Abgelaufen';
    $Lang->{'Floor'}                         = 'Etage';
    $Lang->{'Freeware'}                      = 'Freeware';
    $Lang->{'GSM'}                           = 'GSM';
    $Lang->{'Gateway'}                       = 'Gateway';
    $Lang->{'Graphic Adapter'}               = 'Grafik Adapter';
    $Lang->{'Hard Disk'}                     = 'Festplatte';
    $Lang->{'Hard Disk::Capacity'}           = 'Festplatte::Kapazität';
    $Lang->{'Hide Versions'}                 = 'Versionen ausblenden';
    $Lang->{'IP Address'}                    = 'IP Adresse';
    $Lang->{'IP over DHCP'}                  = 'IP über DHCP';
    $Lang->{'IT Facility'}                   = 'IT Einrichtung';
    $Lang->{'Inactive'}                      = 'Inaktiv';
    $Lang->{'Incident'}                      = 'Vorfall';
    $Lang->{'Install Date'}                  = 'Installationsdatum';
    $Lang->{'Keyboard'}                      = 'Tastatur';
    $Lang->{'LAN'}                           = 'LAN';
    $Lang->{'Laptop'}                        = 'Laptop';
    $Lang->{'Last Change'}                   = 'Letzte Änderung';
    $Lang->{'Licence Key'}                   = 'Lizenzschlüssel';
    $Lang->{'Licence Key::Expiration Date'}  = 'Lizenzschlüssel::Ablaufdatum';
    $Lang->{'Licence Key::Quantity'}         = 'Lizenzschlüssel::Menge';
    $Lang->{'Licence Type'}                  = 'Lizenztyp';
    $Lang->{'Maintenance'}                   = 'In Wartung';
    $Lang->{'Maximum number of one element'} = 'Maximale Anzahl eines Elements';
    $Lang->{'Media'}                         = 'Medium';
    $Lang->{'Middleware'}                    = 'Middleware';
    $Lang->{'Model'}                         = 'Model';
    $Lang->{'Modem'}                         = 'Modem';
    $Lang->{'Monitor'}                       = 'Monitor';
    $Lang->{'Mouse'}                         = 'Maus';
    $Lang->{'Network Adapter'}               = 'Netzwerk Adapter';
    $Lang->{'Network Adapter::IP Address'}   = 'Netzwerk Adapter::IP Adresse';
    $Lang->{'Network Adapter::IP over DHCP'} = 'Netzwerk Adapter::IP über DHCP';
    $Lang->{'Network Address'}               = 'Netzwerk Adresse';
    $Lang->{'Network Address::Gateway'}      = 'Netzwerk Adresse::Gateway';
    $Lang->{'Network Address::Subnet Mask'}  = 'Netzwerk Adresse::Subnetz Maske';
    $Lang->{'Open Source'}                   = 'Open Source';
    $Lang->{'Operational'}                   = 'Operativ';
    $Lang->{'Other'}                         = 'Sonstiges';
    $Lang->{'Other Equipment'}               = 'Sonstige Ausstattung';
    $Lang->{'Outlet'}                        = 'Anschlussdose';
    $Lang->{'PCMCIA Card'}                   = 'PCMCIA Karte';
    $Lang->{'PDA'}                           = 'PDA';
    $Lang->{'Per Node'}                      = 'Pro Knoten';
    $Lang->{'Per Processor'}                 = 'Pro Prozessor';
    $Lang->{'Per Server'}                    = 'Pro Server';
    $Lang->{'Per User'}                      = 'Pro Benutzer';
    $Lang->{'Phone 1'}                       = 'Telefon 1';
    $Lang->{'Phone 2'}                       = 'Telefon 2';
    $Lang->{'Pilot'}                         = 'Pilotbetrieb';
    $Lang->{'Planned'}                       = 'Geplant';
    $Lang->{'Printer'}                       = 'Drucker';
    $Lang->{'Production'}                    = 'Produktiv';
    $Lang->{'Quantity'}                      = 'Menge';
    $Lang->{'Rack'}                          = 'Rack';
    $Lang->{'Ram'}                           = 'Arbeitsspeicher';
    $Lang->{'Repair'}                        = 'In Reparatur';
    $Lang->{'Retired'}                       = 'Außer Dienst';
    $Lang->{'Review'}                        = 'Unter Review';
    $Lang->{'Room'}                          = 'Raum';
    $Lang->{'Router'}                        = 'Router';
    $Lang->{'Scanner'}                       = 'Scanner';
    $Lang->{'Search Config Items'}           = 'Config Item Suche';
    $Lang->{'Security Device'}               = 'Sicherheitsgerät';
    $Lang->{'Serial Number'}                 = 'Seriennummer';
    $Lang->{'Server'}                        = 'Server';
    $Lang->{'Server Application'}            = 'Server Anwendung';
    $Lang->{'Server OS'}                     = 'Server Betriebssystem';
    $Lang->{'Show Versions'}                 = 'Versionen einblenden';
    $Lang->{'Single Licence'}                = 'Einzellizenz';
    $Lang->{'Subnet Mask'}                   = 'Subnetz Maske';
    $Lang->{'Switch'}                        = 'Switch';
    $Lang->{'Telco'}                         = 'Telko';
    $Lang->{'Test/QA'}                       = 'Test/QS';
    $Lang->{'The deployment state of this config item'}
        = 'Der Verwendungsstatus dieses Config Items';
    $Lang->{'The incident state of this config item'}
        = 'Der Vorfallsstatus dieses Config Items';
    $Lang->{'Time Restricted'}          = 'Zeitlich begrenzt';
    $Lang->{'USB Device'}               = 'USB Gerät';
    $Lang->{'Unlimited'}                = 'Unlimitiert';
    $Lang->{'User Tool'}                = 'User Tool';
    $Lang->{'Volume Licence'}           = 'Volumen Lizenz';
    $Lang->{'WLAN'}                     = 'WLAN';
    $Lang->{'WLAN Access Point'}        = 'WLAN Access Point';
    $Lang->{'Warranty Expiration Date'} = 'Garantie Ablaufdatum';
    $Lang->{'Workplace'}                = 'Arbeitsplatz';

    # Template: AdminITSMConfigItem
    $Lang->{'Config Item Management'}  = 'Config Item Verwaltung';
    $Lang->{'Change class definition'} = 'Klassen-Definition ändern';
    $Lang->{'Config Item'}             = 'Config Item';
    $Lang->{'Class'}                   = 'Klasse';
    $Lang->{'Definition'}              = 'Definition';

    # Template: AgentITSMConfigItemAdd
    $Lang->{'Filter for Classes'} = 'Filter für Klassen';
    $Lang->{'Select a Class from the list to create a new Config Item.'}
        = 'Wählen Sie eine Klasse aus der Liste aus um ein neues Config Item zu erstellen.';

    # Template: AgentITSMConfigItemBulk
    $Lang->{'ITSM ConfigItem Bulk Action'} = 'ITSM ConfigItem Sammel-Aktion';
    $Lang->{'Deployment state'}            = 'Verwendungsstatus';
    $Lang->{'Incident state'}              = 'Vorfallsstatus';
    $Lang->{'Link to another'}             = 'Zu einem anderen verlinken';
    $Lang->{'Invalid Configuration Item number!'}
        = 'Ungültige Configuration Item Nummer!';
    $Lang->{'The number of another Configuration Item to link with.'} = 'Die Nummer eines anderen ConfigItems mit dem verlinkt werden soll.';

    # Template: AgentITSMConfigItemEdit
    $Lang->{'The name of this config item'} = 'Der Name dieses Config Items';
    $Self->{Translation}
        ->{'Name is already in use by the ConfigItems with the following Number(s): %s'}
        =
        'Name wird bereits von den ConfigItems mit den folgenden Nummern verwendet: %s';
    $Lang->{'Deployment State'} = 'Verwendungsstatus';
    $Lang->{'Incident State'}   = 'Vorfallsstatus';

    # Template: AgentITSMConfigItemHistory
    $Lang->{'History of'} = 'Änderungsverlauf von';

    # Template: AgentITSMConfigItemOverviewNavBar
    $Lang->{'Context Settings'}      = 'Kontext-Eintstellungen';
    $Lang->{'Config Items per page'} = 'Config Items pro Seite';

    # Template: AgentITSMConfigItemOverviewSmall
    $Lang->{'Deployment State Type'}       = 'Verwendungsstatus-Typ';
    $Lang->{'Current Incident State'}      = 'Aktueller Vorfallsstatus';
    $Lang->{'Current Incident State Type'} = 'Aktueller Vorfallsstatus-Typ';
    $Lang->{'Last changed'}                = 'Zuletzt geändert';

    # Template: AgentITSMConfigItemSearch
    $Lang->{'Create New Template'} = 'Neue Vorlage erstellen';
    $Lang->{'Run Search'}          = 'Suche ausführen';
    $Lang->{'Also search in previous versions?'}
        = 'Auch in früheren Versionen suchen?';

    # Template: AgentITSMConfigItemZoom
    $Lang->{'Configuration Item'}             = 'Configuration Item';
    $Lang->{'Configuration Item Information'} = 'Configuration Item Information';
    $Lang->{'Current Deployment State'}       = 'Aktueller Verwendungsstatus';
    $Lang->{'Last changed by'}                = 'Zuletzt geändert von';
    $Lang->{'Ok'}                             = 'Ok';
    $Lang->{'Show one version'}               = 'Zeige nur eine Version';
    $Lang->{'Show all versions'}              = 'Zeige alle Versionen';
    $Lang->{'Version Incident State'}         = 'Versions-Vorfallstatus';
    $Lang->{'Version Deployment State'}       = 'Versions-Verwendungsstatus';
    $Lang->{'Version Number'}                 = 'Versionsnummer';
    $Lang->{'Configuration Item Version Details'}
        = 'Configuration Item Versions-Details';
    $Lang->{'Property'} = 'Eigenschaft';

    # Perl Module: Kernel/Modules/AgentITSMConfigItem.pm
    $Lang->{'ITSM ConfigItem'} = '';

    # Perl Module: Kernel/Modules/AgentITSMConfigItemHistory.pm
    $Lang->{'CIHistory::'} = '';

    # Perl Module: Kernel/Modules/AgentITSMConfigItemPrint.pm
    $Lang->{'ConfigItem'} = 'ConfigItem';

    # Perl Module: Kernel/Modules/AgentITSMConfigItemSearch.pm
    $Lang->{'No Result!'}                 = 'Kein Ergebnis!';
    $Lang->{'Config Item Search Results'} = 'ConfigItem Suchergebnisse';

    # SysConfig
    $Lang->{
        'Check for a unique name only within the same ConfigItem class (\'class\') or globally (\'global\'), which means every existing ConfigItem is taken into account when looking for duplicates.'
        }
        =
        'Prüfe Namen auf Eindeutigkeit innerhalb der selben ConfigItem-Klasse oder global, d.h. es werden alle ConfigItems jeglicher ConfigItem-Klasse bei der Prüfung auf einen eindeutigen Namen berücksichtigt.';
    $Lang->{'Config Items'} = 'Config Items';
    $Lang->{'Config item event module that enables logging to history in the agent interface.'} = '';
    $Lang->{'ITSM ConfigItem Overview "Small" Limit'}
        = 'ITSM-ConfigItem Anzeige-Limit für die Small-Ansicht';
    $Lang->{'ITSM ConfigItem Overview "Custom" Limit'}
        = 'ITSM-ConfigItem Anzeige-Limit für die Custom-Ansicht';
    $Lang->{'ConfigItem limit per page ITSM ConfigItem Overview "Small"'}
        = 'ConfigItem limit pro Seite für die Small-Ansicht.';
    $Lang->{'ConfigItem limit per page ITSM ConfigItem Overview "Custom"'}
        = 'ConfigItem limit pro Seite für die Custom-Ansicht.';
    $Lang->{'Configuration item search backend router of the agent interface.'} =
        '';
    $Lang->{
        'Defines Required permissions to create ITSM configuration items using the Generic Interface.'
        }
        =
        '';
    $Lang->{
        'Defines Required permissions to get ITSM configuration items using the Generic Interface.'
        }
        =
        '';
    $Lang->{
        'Defines Required permissions to search ITSM configuration items using the Generic Interface.'
        }
        =
        '';
    $Lang->{
        'Defines Required permissions to update ITSM configuration items using the Generic Interface.'
        }
        =
        '';
    $Self->{Translation}
        ->{'Defines an overview module to show the small view of a configuration item list.'}
        =
        '';
    $Lang->{
        'Defines regular expressions individually for each ConfigItem class to check the ConfigItem name and to show corresponding error messages.'
        }
        =
        '';
    $Lang->{'Defines the default subobject of the class \'ITSMConfigItem\'.'} =
        'Definiert das Standard-Subobject der Klasse';
    $Self->{Translation}
        ->{'Defines the number of rows for the CI definition editor in the admin interface.'}
        =
        '';
    $Lang->{'Defines the search limit for the AgentITSMConfigItem screen.'} =
        '';
    $Lang->{'Defines the search limit for the AgentITSMConfigItemSearch screen.'} =
        '';
    $Lang->{
        'Defines the shown columns in the config item overview. This option has no effect on the position of the column. Note: Class column is always available if filter \'All\' is selected.'
        }
        =
        '';
    $Lang->{
        'Defines the shown columns in the config item search. This option has no effect on the position of the column.'
        }
        =
        '';
    $Lang->{
        'Defines the shown columns of CIs in the config item overview depending on the CI class. Each entry must be prefixed with the class name and double colons (i.e. Computer::). There are a few CI-Attributes that are common to all CIs (example for the class Computer: Computer::Name, Computer::CurDeplState, Computer::CreateTime). To show individual CI-Attributes as defined in the CI-Definition, the following scheme must be used (example for the class Computer): Computer::HardDisk::1, Computer::HardDisk::1::Capacity::1, Computer::HardDisk::2, Computer::HardDisk::2::Capacity::1. If there is no entry for a CI class, then the default columns are shown as defined in the setting ITSMConfigItem::Frontend::AgentITSMConfigItem###ShowColumns.'
        }
        =
        '';
    $Lang->{
        'Defines the shown columns of CIs in the config item search depending on the CI class. Each entry must be prefixed with the class name and double colons (i.e. Computer::). There are a few CI-Attributes that are common to all CIs (example for the class Computer: Computer::Name, Computer::CurDeplState, Computer::CreateTime). To show individual CI-Attributes as defined in the CI-Definition, the following scheme must be used (example for the class Computer): Computer::HardDisk::1, Computer::HardDisk::1::Capacity::1, Computer::HardDisk::2, Computer::HardDisk::2::Capacity::1. If there is no entry for a CI class, then the default columns are shown as defined in the setting ITSMConfigItem::Frontend::AgentITSMConfigItem###ShowColumns.'
        }
        =
        '';
    $Lang->{
        'Defines the shown columns of CIs in the link table complex view, depending on the CI class. Each entry must be prefixed with the class name and double colons (i.e. Computer::). There are a few CI-Attributes that common to all CIs (example for the class Computer: Computer::Name, Computer::CurDeplState, Computer::CreateTime). To show individual CI-Attributes as defined in the CI-Definition, the following scheme must be used (example for the class Computer): Computer::HardDisk::1, Computer::HardDisk::1::Capacity::1, Computer::HardDisk::2, Computer::HardDisk::2::Capacity::1. If there is no entry for a CI class, then the default columns are shown.'
        }
        =
        '';
    $Lang->{
        'Enables configuration item bulk action feature for the agent frontend to work on more than one configuration item at a time.'
        }
        =
        '';
    $Self->{Translation}
        ->{'Enables configuration item bulk action feature only for the listed groups.'}
        =
        '';
    $Lang->{
        'Enables/disables the functionality to check ConfigItems for unique names. Before enabling this option you should check your system for already existing config items with duplicate names. You can do this with the You can do this with the console command Admin::ITSM::Configitem::ListDuplicates.'
        }
        =
        '(De-)Aktiviert die Funktionalität um ConfigItems auf eindeutige Namen zu überprüfen. Bevor Sie diese Option aktivieren, sollten Sie Ihr System auf bereits vorhandene ConfigItems mit gleichem Namen überprüfen. Sie können dies mit Hilfe des Konsolenbefehls Admin::ITSM::Configitem::ListDuplicates tun.';
    $Lang->{'Module to check the group responsible for a class.'} = '';
    $Lang->{'Module to check the group responsible for a configuration item.'} =
        '';
    $Lang->{'Module to generate ITSM config item statistics.'} = '';
    $Lang->{'Object backend module registration for the import/export module.'} =
        'Objekt-Backend Modul Registration des Import/Export Moduls.';
    $Lang->{
        'Parameters for the deployment states color in the preferences view of the agent interface.'
        }
        =
        '';
    $Self->{Translation}
        ->{'Parameters for the deployment states in the preferences view of the agent interface.'}
        =
        '';
    $Self->{Translation}
        ->{'Parameters for the example permission groups of the general catalog attributes.'}
        =
        'Parameter für die zugriffsberechtigte Gruppe der General-Katalog-Attribute.';
    $Lang->{'Parameters for the pages (in which the configuration items are shown).'}
        =
        '';
    $Self->{Translation}
        ->{'Required permissions to use the ITSM configuration item screen in the agent interface.'}
        =
        '';
    $Lang->{
        'Required permissions to use the ITSM configuration item search screen in the agent interface.'
        }
        =
        '';
    $Lang->{
        'Required permissions to use the ITSM configuration item zoom screen in the agent interface.'
        }
        =
        '';
    $Lang->{
        'Required permissions to use the add ITSM configuration item screen in the agent interface.'
        }
        =
        '';
    $Lang->{
        'Required permissions to use the edit ITSM configuration item screen in the agent interface.'
        }
        =
        '';
    $Lang->{
        'Required permissions to use the history ITSM configuration item screen in the agent interface.'
        }
        =
        '';
    $Lang->{
        'Required permissions to use the print ITSM configuration item screen in the agent interface.'
        }
        =
        '';
    $Lang->{
        'Selects the configuration item number generator module. "AutoIncrement" increments the configuration item number, the SystemID, the ConfigItemClassID and the counter are used. The format is "SystemID.ConfigItemClassID.Counter", e.g. 1205000004, 1205000005.'
        }
        =
        '';
    $Lang->{
        'Sets the deployment state in the configuration item bulk screen of the agent interface.'
        }
        =
        '';
    $Self->{Translation}
        ->{'Sets the incident state in the configuration item bulk screen of the agent interface.'}
        =
        '';
    $Lang->{
        'Shows a link in the menu that allows linking a configuration item with another object in the config item zoom view of the agent interface.'
        }
        =
        '';
    $Lang->{
        'Shows a link in the menu to access the history of a configuration item in the configuration item overview of the agent interface.'
        }
        =
        '';
    $Lang->{
        'Shows a link in the menu to access the history of a configuration item in the its zoom view of the agent interface.'
        }
        =
        '';
    $Lang->{
        'Shows a link in the menu to duplicate a configuration item in the configuration item overview of the agent interface.'
        }
        =
        '';
    $Lang->{
        'Shows a link in the menu to duplicate a configuration item in the its zoom view of the agent interface.'
        }
        =
        '';
    $Lang->{
        'Shows a link in the menu to edit a configuration item in the its zoom view of the agent interface.'
        }
        =
        '';
    $Lang->{
        'Shows a link in the menu to go back in the configuration item zoom view of the agent interface.'
        }
        =
        '';
    $Lang->{
        'Shows a link in the menu to print a configuration item in the its zoom view of the agent interface.'
        }
        =
        '';
    $Lang->{
        'Shows a link in the menu to zoom into a configuration item in the configuration item overview of the agent interface.'
        }
        =
        '';
    $Self->{Translation}
        ->{'Shows the config item history (reverse ordered) in the agent interface.'}
        =
        '';
    $Lang->{
        'The identifier for a configuration item, e.g. ConfigItem#, MyConfigItem#. The default is ConfigItem#.'
        }
        =
        '';

    $Lang->{'Open link in new window'} = 'Öffnet den Link in einem neuem Fenster';
    $Lang->{'Defines values shown for agent user attributes.'} =
        'Definiert Werte die fuer Attribut Agentennutzer angezeigt werden.';
    $Lang->{'Defines information shown for company attributes.'} =
        'Definiert die zu einem Companyattribut angezeigten Werte.';
    $Lang->{'Defines information imported/exported as CustomerCompany attribute.'} =
        'Definiert die bei einem CustomerCompany-Attribut importierten/exportierten Werte.';
    $Lang->{
        'Searches for attributes of type CIClassReference in the new CIs version data and refreshes all links to that class. It deletes links to this class if the value is not existent in the CIs version data.'
        }
        =
        'Sucht nach Attributen vom Typ CIClassReference in der neuen Version des CIs und aktualisiert alle Verknuepfungen zu CIs dieser Klasse. Alle Verknuepfungen zu dieser Klasse zu denen kein Wert in der CI-Version existiert werden geloescht.';
    $Lang->{
        'Searches for attributes of type ServiceReference in the new CIs version data and refreshes all links to that class. It deletes links to this class if the value is not existent in the CIs version data.'
        }
        =
        'Sucht nach Attributen vom Typ ServiceReference in der neuen Version des CIs und aktualisiert alle Verknuepfungen zu CIs dieser Klasse. Alle Verknuepfungen zu dieser Klasse zu denen kein Wert in der CI-Version existiert werden geloescht.';

    $Lang->{'Assigned Queue'}   = 'Zugewiesene Queue';
    $Lang->{'Assigned Service'} = 'Zugeordneter Service';

    # Template: AAAImportExport
    $Lang->{'Add mapping template'}   = 'Mapping-Template hinzufügen';
    $Lang->{'Charset'}                = 'Zeichensatz';
    $Lang->{'Colon (:)'}              = 'Doppelpunkt (:)';
    $Lang->{'Column'}                 = 'Spalte';
    $Lang->{'Column Separator'}       = 'Spaltentrenner';
    $Lang->{'Dot (.)'}                = 'Punkt (.)';
    $Lang->{'Semicolon (;)'}          = 'Semicolon (;)';
    $Lang->{'Tabulator (TAB)'}        = 'Tabulator (TAB)';
    $Lang->{'Include Column Headers'} = 'Mit Spaltenüberschriften';
    $Lang->{'Import summary for'}     = 'Import-Bericht für';
    $Lang->{'Imported records'}       = 'Importierte Datensätze';
    $Lang->{'Exported records'}       = 'Exportierte Datensätze';
    $Lang->{'Records'}                = 'Datensätze';
    $Lang->{'Skipped'}                = 'Übersprungen';

    # Template: AdminImportExport
    $Lang->{'Import/Export Management'} = 'Import/Export-Verwaltung';
    $Lang->{'Create a template to import and export object information.'}
        = 'Erstellen einer Vorlage zum Importieren und Exportieren von Objekt-Informationen.';
    $Lang->{'Start Import'}                           = 'Import starten';
    $Lang->{'Start Export'}                           = 'Export starten';
    $Lang->{'Step 1 of 5 - Edit common information'}  = '';
    $Lang->{'Name is required!'}                      = 'Name wird benötigt!';
    $Lang->{'Object is required!'}                    = 'Objekt ist erforderlich!';
    $Lang->{'Format is required!'}                    = 'Format ist erforderlich!';
    $Lang->{'Step 2 of 5 - Edit object information'}  = '';
    $Lang->{'Step 3 of 5'}                            = '';
    $Lang->{'is required!'}                           = 'wird benötigt!';
    $Lang->{'Step 4 of 5 - Edit mapping information'} = '';
    $Lang->{'No map elements found.'} = 'Keine Mapping-Elemente gefunden.';
    $Lang->{'Add Mapping Element'}    = 'Mapping-Element hinzufügen';
    $Lang->{'Step 5 of 5 - Edit search information'} = '';
    $Lang->{'Restrict export per search'} = 'Export per Suche einschränken';
    $Lang->{'Import information'}         = 'Import-Informationen';
    $Lang->{'Source File'}                = 'Quell-Datei';
    $Lang->{'Success'}                    = 'Erfolgreich';
    $Lang->{'Failed'}                     = 'Nicht erfolgreich';
    $Lang->{'Duplicate names'}            = 'Doppelte Namen';
    $Lang->{'Last processed line number of import file'}
        = 'Zuletzt verarbeitete Zeile der Import-Datei';
    $Lang->{'Ok'} = 'Ok';

    # Perl Module: Kernel/Modules/AdminImportExport.pm
    $Lang->{'No object backend found!'}                                   = '';
    $Lang->{'No format backend found!'}                                   = '';
    $Lang->{'Template not found!'}                                        = '';
    $Lang->{'Can\'t insert/update template!'}                             = '';
    $Lang->{'Needed TemplateID!'}                                         = '';
    $Lang->{'Error occurred. Import impossible! See Syslog for details.'} = '';
    $Lang->{'Error occurred. Export impossible! See Syslog for details.'} = '';
    $Lang->{'number'}                                                     = '';
    $Lang->{'number bigger than zero'}                                    = '';
    $Lang->{'integer'}                                                    = '';
    $Lang->{'integer bigger than zero'}                                   = '';
    $Lang->{'Element required, please insert data'}                       = '';
    $Lang->{'Invalid data, please insert a valid %s'}                     = '';
    $Lang->{'Format not found!'}                                          = '';

    # SysConfig
    $Lang->{'Format backend module registration for the import/export module.'} =
        'Format-Backend Modul-Registration des Import/Export Moduls.';
    $Lang->{'Import and export object information.'}
        = 'Importieren und Exportieren von Objekt-Informationen.';
    $Lang->{'Import/Export'} = 'Import/Export';

    # Template: AAAGeneralCatalog
    $Lang->{'Functionality'} = 'Funktionalität';

    # Template: AdminGeneralCatalog
    $Lang->{'General Catalog Management'} = 'General-Katalog-Verwaltung';
    $Lang->{'Add Catalog Item'}           = 'Katalog-Eintrag hinzufügen';
    $Lang->{'Add Catalog Class'}          = 'Katalog-Klasse hinzufügen';
    $Lang->{'Catalog Class'}              = 'Katalog-Klasse';

    # SysConfig
    $Lang->{'Admin.'} = 'Admin.';
    $Lang->{'Create and manage the General Catalog.'}
        = 'General-Katalog erstellen und verwalten.';
    $Lang->{
        'Frontend module registration for the AdminGeneralCatalog configuration in the admin area.'
        }
        =
        'Frontendmodul-Registration der AdminGeneralCatalog Konfiguration im Admin-Bereich.';
    $Lang->{'General Catalog'} = 'General-Katalog';
    $Self->{Translation}
        ->{'Parameters for the example comment 2 of the general catalog attributes.'}
        =
        'Parameter für den Beispiel-Kommentar 2 der General-Katalog-Attribute.';
    $Self->{Translation}
        ->{'Parameters for the example permission groups of the general catalog attributes.'}
        =
        'Parameter für die zugriffsberechtigte Gruppe der General-Katalog-Attribute.';

    # translations missing in ImportExport...
    $Lang->{'Column Seperator'}           = 'Spaltentrenner';
    $Lang->{'Charset'}                    = 'Zeichensatz';
    $Lang->{'Restrict export per search'} = 'Export mittels Suche einschränken';
    $Lang->{'Validity'}                   = 'Gültigkeit';

    #    $Lang->{'Export with labels'}         = 'Mit Beschriftung exportieren';
    $Lang->{'Default Category (if empty/invalid)'}
        = 'Standardkategorie (wenn leer/ungültig)';
    $Lang->{'Default State (if empty/invalid)'}
        = 'Standardstatus (wenn leer/ungültig)';
    $Lang->{'Default group for new category'} = 'Standardgruppe für neue Kategorie';
    $Lang->{'Default Language (if empty/invalid)'}
        = 'Standardsprache (wenn leer/ungültig)';
    $Lang->{'Approved'} = 'Freigegeben';
    $Lang->{'Object backend module registration for the import/export module.'} =
        'Objekt-Backend Modul Registration des Import/Export Moduls.';

    # Template: AAAFAQ
    $Lang->{'internal'}                        = 'intern';
    $Lang->{'public'}                          = 'öffentlich';
    $Lang->{'external'}                        = 'extern';
    $Lang->{'FAQ Number'}                      = 'FAQ-Nummer';
    $Lang->{'Latest updated FAQ articles'}     = 'Zuletzt geänderte FAQ-Artikel';
    $Lang->{'Latest created FAQ articles'}     = 'Zuletzt erstellte FAQ-Artikel';
    $Lang->{'Top 10 FAQ articles'}             = 'Top 10 FAQ-Artikel';
    $Lang->{'Subcategory of'}                  = 'Unterkategorie von';
    $Lang->{'No rate selected!'}               = 'Keine Bewertung ausgewählt!';
    $Lang->{'Explorer'}                        = 'Ansicht nach Kategorien';
    $Lang->{'public (all)'}                    = 'öffentlich (Alle)';
    $Lang->{'external (customer)'}             = 'extern (Kunde)';
    $Lang->{'internal (agent)'}                = 'intern (Agent)';
    $Lang->{'Start day'}                       = 'Start Tag';
    $Lang->{'Start month'}                     = 'Start Monat';
    $Lang->{'Start year'}                      = 'Start Jahr';
    $Lang->{'End day'}                         = 'End Tag';
    $Lang->{'End month'}                       = 'End Monat';
    $Lang->{'End year'}                        = 'End Jahr';
    $Lang->{'Thanks for your vote!'}           = 'Vielen Dank für Ihre Bewertung!';
    $Lang->{'You have already voted!'}         = 'Sie haben bereits abgestimmt!';
    $Lang->{'FAQ Article Print'}               = 'FAQ-Artikel-Ausdruck';
    $Lang->{'FAQ Articles (Top 10)'}           = 'FAQ-Artikel (Top 10)';
    $Lang->{'FAQ Articles (new created)'}      = 'FAQ-Artikel (neu erstellte)';
    $Lang->{'FAQ Articles (recently changed)'} = 'FAQ-Artikel (aktualisierte)';
    $Lang->{'FAQ category updated!'}           = 'FAQ-Kategorie aktualisiert!';
    $Lang->{'FAQ category added!'}             = 'FAQ-Kategorie hinzugefügt!';
    $Lang->{'A category should have a name!'}
        = 'Eine Kategorie benötigt einen Namen!';
    $Lang->{'This category already exists'}  = 'Diese Kategorie existiert bereits!';
    $Lang->{'FAQ language added!'}           = 'FAQ-Sprache hinzugefügt!';
    $Lang->{'FAQ language updated!'}         = 'FAQ-Sprache aktualisiert!';
    $Lang->{'The name is required!'}         = 'Der Name ist erforderlich!';
    $Lang->{'This language already exists!'} = 'Diese Sprache existiert bereits!';
    $Lang->{'Symptom'}                       = 'Symptom';
    $Lang->{'Solution'}                      = 'Lösung';

    # Template: AgentFAQAdd
    $Lang->{'Add FAQ Article'}         = 'FAQ-Artikel hinzufügen';
    $Lang->{'Keywords'}                = 'Schlüsselwörter';
    $Lang->{'A category is required.'} = 'Eine Kategorie ist erforderlich.';
    $Lang->{'Approval'}                = 'Freigabe';

    # Template: AgentFAQCategory
    $Lang->{'FAQ Category Management'} = 'FAQ-Kategorien-Verwaltung';
    $Lang->{'Add category'}            = 'Kategorie hinzufügen';
    $Lang->{'Delete Category'}         = 'Kategorie löschen';
    $Lang->{'Ok'}                      = 'Ok';
    $Lang->{'Add Category'}            = 'Kategorie hinzufügen';
    $Lang->{'Edit Category'}           = 'Kategorie bearbeiten';
    $Lang->{'Please select at least one permission group.'}
        = 'Wählen Sie mindestens eine Berechtigungsgruppe.';
    $Lang->{'Agent groups that can access articles in this category.'}
        = 'Agenten-Gruppen, die berechtigt sind, auf FAQ-Artikel in dieser Kategorie zuzugreifen.';
    $Lang->{'Will be shown as comment in Explorer.'}
        = 'Wird im Explorer als Kommentar angezeigt.';
    $Lang->{'Do you really want to delete this category?'}
        = 'Wollen Sie diese Kategorie wirklich löschen?';
    $Lang->{
        'You can not delete this category. It is used in at least one FAQ article and/or is parent of at least one other category'
        }
        =
        'Sie können diese Kategorie nicht löschen. Sie wird in mindestens einem FAQ-Artikel verwendet!';
    $Lang->{'This category is used in the following FAQ article(s)'}
        = 'Diese Kategorie wird in den folgenden FAQ-Artikeln verwendet';
    $Lang->{'This category is parent of the following subcategories'}
        = 'Diese Kategorie ist eine Eltern-Kategorie für folgende Kategorien';

    # Template: AgentFAQDelete
    $Lang->{'Do you really want to delete this FAQ article?'}
        = 'Wollen Sie diesen FAQ-Artikel wirklich löschen?';

    # Template: AgentFAQEdit
    $Lang->{'FAQ'} = 'FAQ';

    # Template: AgentFAQExplorer
    $Lang->{'FAQ Explorer'}            = 'FAQ-Explorer';
    $Lang->{'Quick Search'}            = 'Schnellsuche';
    $Lang->{'Wildcards are allowed.'}  = 'Wildcards sind erlaubt.';
    $Lang->{'Advanced Search'}         = 'Erweiterte Suche';
    $Lang->{'Subcategories'}           = 'Unterkategorien';
    $Lang->{'FAQ Articles'}            = 'FAQ-Artikel';
    $Lang->{'No subcategories found.'} = 'Keine Unterkategorien gefunden.';

    # Template: AgentFAQHistory
    $Lang->{'History of'} = 'Änderungsverlauf von';

    # Template: AgentFAQJournalOverviewSmall
    $Lang->{'No FAQ Journal data found.'} = 'Keine FAQ-Journaldaten gefunden.';

    # Template: AgentFAQLanguage
    $Lang->{'FAQ Language Management'} = 'FAQ-Sprachen-Verwaltung';
    $Lang->{'Use this feature if you want to work with multiple languages.'} =
        'Verwenden Sie diese Funktion, wenn Sie mit mehreren Sprachen arbeiten wollen.';
    $Lang->{'Add language'}       = 'Sprache hinzufügen';
    $Lang->{'Delete Language %s'} = 'Sprache Löschen %s';
    $Lang->{'Add Language'}       = 'Sprache hinzufügen';
    $Lang->{'Edit Language'}      = 'Sprache Bearbeiten';
    $Lang->{'Do you really want to delete this language?'}
        = 'Wollen Sie diese Sprache wirklich löschen?';
    $Self->{Translation}
        ->{'You can not delete this language. It is used in at least one FAQ article!'}
        =
        'Sie können diese Sprache nicht löschen. Sie wird in mindestens einem FAQ-Artikel verwendet!';
    $Lang->{'This language is used in the following FAQ Article(s)'}
        = 'Diese Sprache wird in den folgenden FAQ-Artikeln verwendet';

    # Template: AgentFAQOverviewNavBar
    $Lang->{'Context Settings'}      = 'Kontext-Einstellungen';
    $Lang->{'FAQ articles per page'} = 'FAQ-Artikel pro Seite';

    # Template: AgentFAQOverviewSmall
    $Lang->{'No FAQ data found.'} = 'Keine FAQ-Daten gefunden.';

    # Template: AgentFAQSearch
    $Lang->{'Keyword'} = 'Schlüsselwort';
    $Lang->{'Vote (e. g. Equals 10 or GreaterThan 60)'}
        = 'Abstimmung (Zum Beispiel: =10 oder >60)';
    $Lang->{'Rate (e. g. Equals 25% or GreaterThan 75%)'}
        = 'Anteil (Zum Beispiel: =25% oder >75%)';
    $Lang->{'Approved'}        = 'Genehmigt';
    $Lang->{'Last changed by'} = 'Letzte Änderung von:';
    $Lang->{'FAQ Article Create Time (before/after)'}
        = 'Erstellzeit des FAQ-Artikel (davor/danach)';
    $Lang->{'FAQ Article Create Time (between)'}
        = 'Erstellzeit des FAQ-Artikel (zwischen)';
    $Lang->{'FAQ Article Change Time (before/after)'}
        = 'Letzte Änderung des FAQ-Artikel (davor/danach)';
    $Lang->{'FAQ Article Change Time (between)'}
        = 'Letzte Änderung des FAQ-Artikel (zwischen)';

    # Template: OpenSearch
    $Lang->{'FAQFulltext'} = 'FAQ-Volltext';
    $Lang->{'Public'}      = 'Öffentlich';

    # Template: AgentFAQSearchSmall
    $Lang->{'FAQ Search'}                          = 'FAQ Suche';
    $Lang->{'Profile Selection'}                   = 'Profilauswahl';
    $Lang->{'Vote'}                                = 'Abstimmen';
    $Lang->{'No vote settings'}                    = 'Keine Abstimmungseinstellung';
    $Lang->{'Specific votes'}                      = 'spezifische Abstimmung';
    $Lang->{'e. g. Equals 10 or GreaterThan 60'}   = 'Zum Beispiel: =10 oder >60';
    $Lang->{'Rate'}                                = 'Anteil';
    $Lang->{'No rate settings'}                    = 'Keine Anteil-Einstellungen';
    $Lang->{'Specific rate'}                       = 'bestimmter Anteil';
    $Lang->{'e. g. Equals 25% or GreaterThan 75%'} = 'Zum Beispiel: =25% oder >75%';
    $Lang->{'FAQ Article Create Time'}             = 'Erstellzeit des FAQ-Artikel';
    $Lang->{'FAQ Article Change Time'} = 'letzte Änderung des FAQ-Artikel';

    # Template: AgentFAQZoom
    $Lang->{'FAQ Information'} = 'FAQ-Information';
    $Lang->{'Rating'}          = 'Bewertung';
    $Lang->{'out of 5'}        = 'von 5';
    $Lang->{'Votes'}           = 'Bewertungen';
    $Lang->{'No votes found!'} = 'Keine Bewertungen gefunden!';
    $Lang->{'No votes found! Be the first one to rate this FAQ article.'}
        = 'Keine Bewertungen gefunden! Seien Sie der erste der diesen FAQ-Artikel bewertet.';
    $Lang->{'Download Attachment'} = 'Attachment Herunterladen';
    $Lang->{
        'To open links in the following description blocks, you might need to press Ctrl or Cmd or Shift key while clicking the link (depending on your browser and OS).'
        }
        =
        'Um die Links im folgenden Beitrag zu öffnen, kann es notwendig sein Strg oder Shift zu drücken, während auf den Link geklickt wird (abhängig vom verwendeten Browser und Betriebssystem).';
    $Lang->{
        'How helpful was this article? Please give us your rating and help to improve the FAQ Database. Thank You!'
        }
        =
        'Wie hilfreich war dieser Artikel? Bitte geben Sie Ihre Bewertung ab und helfen Sie mit die Qualität der FAQ-Datenbank zu verbessern. Vielen Dank!';
    $Lang->{'not helpful'}  = 'nicht hilfreich';
    $Lang->{'very helpful'} = 'sehr hilfreich';

    # Template: AgentFAQZoomSmall
    $Lang->{'Add FAQ title to article subject'}
        = 'Füge den FAQ-Titel als Artikelbetreff hinzu.';
    $Lang->{'Insert FAQ Text'}        = 'FAQ-Text einfügen';
    $Lang->{'Insert Full FAQ'}        = 'Vollständige FAQ einfügen';
    $Lang->{'Insert FAQ Link'}        = 'FAQ-Link einfügen';
    $Lang->{'Insert FAQ Text & Link'} = 'FAQ-Text & Link einfügen';
    $Lang->{'Insert Full FAQ & Link'} = 'Vollständige FAQ & Link einfügen';

    # Template: CustomerFAQExplorer
    $Lang->{'No FAQ articles found.'} = 'Keine FAQ-Artikel gefunden.';

    # Template: CustomerFAQSearch
    $Lang->{'Fulltext search in FAQ articles (e. g. "John*n" or "Will*")'}
        = 'Volltext-Suche in FAQ-Artikeln (z. B. "John*n" or "Will*")';
    $Lang->{'Vote restrictions'}               = 'Wahleinschränkungen';
    $Lang->{'Only FAQ articles with votes...'} = 'Nur FAQ-Artikel mit Abstimmungen';
    $Lang->{'Rate restrictions'}               = 'Anteilsbeschränkungen';
    $Lang->{'Only FAQ articles with rate...'}
        = 'Nur FAQ-Artikel mit einem Anteil von...';
    $Lang->{'Only FAQ articles created'} = 'Nur FAQ-Artikel erstellt';
    $Lang->{'Only FAQ articles created between'}
        = 'Nur Tickets, die erstellt wurden zwischen';
    $Lang->{'Search-Profile as Template?'} = 'Suchprofil als Vorlage?';

    # Template: CustomerFAQZoom
    $Lang->{'Article Number'} = 'Artikelnummer';
    $Lang->{'Search for articles with keyword'}
        = 'Suche nach Artikeln mit Schlüsselwörtern';

    # Template: PublicFAQSearchResultShort
    $Lang->{'Back to FAQ Explorer'} = 'Zurück zum FAQ-Explorer';

    # Perl Module: Kernel/Modules/AgentFAQJournal.pm
    $Lang->{'FAQ Journal'} = 'FAQ Journal';

    # Perl Module: Kernel/Modules/AgentFAQPrint.pm
    $Lang->{'Last update'}        = 'Letzte Aktualisierung';
    $Lang->{'FAQ Dynamic Fields'} = 'FAQ Dynamische Felder';

    # Perl Module: Kernel/Modules/AgentFAQSearch.pm
    $Lang->{'No Result!'} = 'Kein Ergebnis!';

    # Perl Module: Kernel/Output/HTML/HeaderMeta/AgentFAQSearch.pm
    $Lang->{'%s (FAQFulltext)'} = '';

    # Perl Module: Kernel/Output/HTML/HeaderMeta/CustomerFAQSearch.pm
    $Lang->{'%s - Customer (%s)'}          = '%s - Kunde (%s)';
    $Lang->{'%s - Customer (FAQFulltext)'} = '';

    # Perl Module: Kernel/Output/HTML/HeaderMeta/PublicFAQSearch.pm
    $Lang->{'%s - Public (%s)'}          = '%s - Öffentlich (%s)';
    $Lang->{'%s - Public (FAQFulltext)'} = '';

    # Perl Module: Kernel/Output/HTML/Layout/FAQ.pm
    $Lang->{'This article is empty!'} = 'Dieser Artikel ist leer!';

    # SysConfig
    $Lang->{
        'A filter for HTML output to add links behind a defined string. The element Image allows two input kinds. First the name of an image (e.g. faq.png). In this case the KIX image path will be used. The second possibility is to insert the link to the image.'
        }
        =
        'Ein Filter zur automatischen Generierung von FAQ-Links, wenn ein Hinweis auf einen FAQ-Artikel identifiziert wird. Das Element Image erlaubt zwei Eingabeformen: Erstens der Name eines Icons (z. B. faq.png). In diesem Fall wird auf das Grafik-Verzeichnis des KIX zugegriffen. Als zweite Möglichkeit kann man aber auch den direkten Link zur Grafik angeben (z. B. http://kixdesk.com/faq.png).';
    $Lang->{'Add FAQ article'} = 'FAQ-Artikel hinzufügen';
    $Lang->{'CSS color for the voting result.'}
        = 'CSS-Farbe für das Bewertungs-Ergebnis.';
    $Lang->{'Cache Time To Leave for FAQ items.'} = 'Cachezeit für FAQ-Artikel.';
    $Lang->{'Category Management'}                = 'Kategorien-Verwaltung';
    $Lang->{'Customer FAQ Print.'}                = 'Kunden-FAQ Drucken.';
    $Lang->{'Customer FAQ Zoom.'}                 = '';
    $Lang->{'Customer FAQ search.'}               = 'Kunden-FAQ Suchen.';
    $Lang->{'Customer FAQ.'}                      = 'Kunden-FAQ.';
    $Lang->{'Decimal places of the voting result.'}
        = 'Dezimalstellen des Ergebnisses der Artikelbewertung.';
    $Lang->{'Default category name.'} = 'Root-Kategorie-Name.';
    $Lang->{'Default language for FAQ articles on single language mode.'}
        = 'Standard-Sprache für FAQ-Artikel im Einzel-Sprach-Modus.';
    $Lang->{'Default maximum size of the titles in a FAQ article to be shown.'} =
        'Standardmäßig maximal angezeigte Zeichen in den Titeln der FAQ-Artikel.';
    $Lang->{'Default priority of tickets for the approval of FAQ articles.'} =
        'Standard-Priorität von Tickets für die Freigabe von FAQ-Artikeln.';
    $Lang->{'Default state for FAQ entry.'} = 'Standard Status eines FAQ-Eintrags.';
    $Lang->{'Default state of tickets for the approval of FAQ articles.'}
        = 'Standard-Status von Tickets für die Freigabe von FAQ-Artikeln.';
    $Lang->{'Default type of tickets for the approval of FAQ articles.'}
        = 'Standard Tickettyp für die Genehmigung von FAQ-Artikeln';
    $Lang->{
        'Default value for the Action parameter for the public frontend. The Action parameter is used in the scripts of the system.'
        }
        =
        'Standardwert des Action-Parameters für den öffentlichen FAQ-Bereich. Der Action-Parameter wird von den Skripten des Systems benutzt.';
    $Lang->{
        'Define Actions where a settings button is available in the linked objects widget (LinkObject::ViewMode = "complex"). Please note that these Actions must have registered the following JS and CSS files: Core.AllocationList.css, Core.UI.AllocationList.js, Core.UI.Table.Sort.js, Core.Agent.TableFilters.js and Core.Agent.LinkObject.js.'
        }
        =
        '';
    $Lang->{'Define if the FAQ title should be concatenated to article subject.'} =
        'Definiert ob der FAQ-Titel mit dem Artikelbetreff verkettet werden soll.';
    $Lang->{
        'Define which columns are shown in the linked FAQs widget (LinkObject::ViewMode = "complex"). Note: Only FAQ attributes and Dynamic Fields (DynamicField_NameX) are allowed for DefaultColumns. Possible settings: 0 = Disabled, 1 = Available, 2 = Enabled by default.'
        }
        =
        '';
    $Lang->{'Defines an overview module to show the small view of a FAQ journal.'} =
        'Definiert ein Übersichts-Modul um die Small-Ansicht im FAQ-Journal anzuzeigen.';
    $Lang->{'Defines an overview module to show the small view of a FAQ list.'} =
        'Definiert ein Übersichts-Modul um die Small-Ansicht einer FAQ-Liste anzuzeigen.';
    $Lang->{
        'Defines the default FAQ attribute for FAQ sorting in a FAQ search of the agent interface.'
        }
        =
        'Definiert das Standard-FAQ-Attribut für die Sortierung der FAQ-Suche im Agenten-Interface.';
    $Lang->{
        'Defines the default FAQ attribute for FAQ sorting in a FAQ search of the customer interface.'
        }
        =
        'Definiert das Standard-FAQ-Attribut für die Sortierung des FAQ-Suche im Kunden-Interface.';
    $Lang->{
        'Defines the default FAQ attribute for FAQ sorting in a FAQ search of the public interface.'
        }
        =
        'Definiert das Standard-FAQ-Attribut für die Sortierung des FAQ-Suche im Public-Interface.';
    $Lang->{
        'Defines the default FAQ attribute for FAQ sorting in the FAQ Explorer of the agent interface.'
        }
        =
        'Definiert das Standard-FAQ-Attribut für die Sortierung des FAQ-Explorer im Agenten-Interface.';
    $Lang->{
        'Defines the default FAQ attribute for FAQ sorting in the FAQ Explorer of the customer interface.'
        }
        =
        'Definiert das Standard-FAQ-Attribut für die Sortierung des FAQ-Explorer im Kunden-Interface.';
    $Lang->{
        'Defines the default FAQ attribute for FAQ sorting in the FAQ Explorer of the public interface.'
        }
        =
        'Definiert das Standard-FAQ-Attribut für die Sortierung des FAQ-Explorer im Public-Interface.';
    $Lang->{
        'Defines the default FAQ order in the FAQ Explorer result of the agent interface. Up: oldest on top. Down: latest on top.'
        }
        =
        'Definiert die Standard-Sortierung des FAQ-Explorer im Agenten-Interface. Auf: Ältester FAQ-Artikel oben. Ab: Neuester FAQ-Artikel oben.';
    $Lang->{
        'Defines the default FAQ order in the FAQ Explorer result of the customer interface. Up: oldest on top. Down: latest on top.'
        }
        =
        'Definiert die Standard-Sortierung des FAQ-Explorer im Kunden-Interface. Auf: Ältester FAQ-Artikel oben. Ab: Neuester FAQ-Artikel oben.';
    $Lang->{
        'Defines the default FAQ order in the FAQ Explorer result of the public interface. Up: oldest on top. Down: latest on top.'
        }
        =
        'Definiert die Standard-Sortierung des FAQ-Explorers im Public-Interface. Auf: Ältester FAQ-Artikel oben. Ab: Neuester FAQ-Artikel oben.';
    $Lang->{
        'Defines the default FAQ order of a search result in the agent interface. Up: oldest on top. Down: latest on top.'
        }
        =
        'Definiert die Standard-Sortierung der FAQ-Suche im Agenten-Interface. Auf: Ältester FAQ-Artikel oben. Ab: Neuester FAQ-Artikel oben.';
    $Lang->{
        'Defines the default FAQ order of a search result in the customer interface. Up: oldest on top. Down: latest on top.'
        }
        =
        'Definiert die Standard-Sortierung der FAQ-Suche im Kunden-Interface. Auf: Ältester FAQ-Artikel oben. Ab: Neuester FAQ-Artikel oben.';
    $Lang->{
        'Defines the default FAQ order of a search result in the public interface. Up: oldest on top. Down: latest on top.'
        }
        =
        'Definiert die Standard-Sortierung der FAQ-Suche im Public-Interface. Auf: Ältester FAQ-Artikel oben. Ab: Neuester FAQ-Artikel oben.';
    $Lang->{'Defines the default shown FAQ search attribute for FAQ search screen.'}
        =
        'Definiert die Standardattribute für die Suche in den Häufig-gestellten-Fragen im Häufig-gestellte-Fragen Suchdialog.';
    $Lang->{
        'Defines the information to be inserted in a FAQ based Ticket. "Full FAQ" includes text, attachments and inline images.'
        }
        =
        'Definiert die Informationen, welche in ein FAQ-basierendes Ticket eingegeben werden. "Komplette FAQ" beinhaltet den Text, Anhänge und Inline-Bilder.';
    $Lang->{
        'Defines the parameters for the dashboard backend. "Limit" defines the number of entries displayed by default. "Group" is used to restrict access to the plugin (e. g. Group: admin;group1;group2;). "Default" indicates if the plugin is enabled by default or if the user needs to enable it manually.'
        }
        =
        'Definiert die Parameter für das Übersichtsseiten-Backend. "Limit" definiert die Anzahl der Einträge, die standardmäßig angezeigt werden. "Group" wird verwendet, um den Zugriff auf das Plugin zu begrenzen (bspw. Group: admin;group1;group2;). "Default" steuert, ob das Plugin standardmäßig aktiviert ist oder ob der User es manuell aktivieren muss.';
    $Lang->{
        'Defines the shown columns in the FAQ Explorer. This option has no effect on the position of the column.'
        }
        =
        'Definert die angezeigten Spalten im FAQ-Explorer. Diese Option hat keine Auswirkung auf die Position der Spalten.';
    $Lang->{
        'Defines the shown columns in the FAQ journal. This option has no effect on the position of the column.'
        }
        =
        'Definert die angezeigten Spalten im FAQ-Journal. Diese Option hat keine Auswirkung auf die Position der Spalten.';
    $Lang->{
        'Defines the shown columns in the FAQ search. This option has no effect on the position of the column.'
        }
        =
        'Definert die angezeigten Spalten in der FAQ-Suche. Diese Option hat keine Auswirkung auf die Position der Spalten.';
    $Lang->{'Defines where the \'Insert FAQ\' link will be displayed.'}
        = 'Definiert wo der Link aus \'FAQ einfügen\' angezeigt wird.';
    $Lang->{'Definition of FAQ item free text field.'}
        = 'Definition der freien Textfelder.';
    $Lang->{'Delete this FAQ'} = 'Diese FAQ löschen!';
    $Lang->{
        'Dynamic fields shown in the FAQ add screen of the agent interface. Possible settings: 0 = Disabled, 1 = Enabled, 2 = Enabled and required.'
        }
        =
        'Anzeige von dynamischen Felder in der Öberfläche "FAQ hinzufügen" im Agenten-Interface. Mögliche Einstellungen: 0 = deaktiviert, 1 = aktiviert, 2 = aktiviert und benötigt.';
    $Lang->{
        'Dynamic fields shown in the FAQ edit screen of the agent interface. Possible settings: 0 = Disabled, 1 = Enabled, 2 = Enabled and required.'
        }
        =
        'Anzeige von dynamischen Felder in der Öberfläche "FAQ bearbeiten" im Agenten-Interface. Mögliche Einstellungen: 0 = deaktiviert, 1 = aktiviert, 2 = aktiviert und benötigt.';
    $Lang->{
        'Dynamic fields shown in the FAQ overview screen of the customer interface. Possible settings: 0 = Disabled, 1 = Enabled, 2 = Enabled and required.'
        }
        =
        'Anzeige von dynamischen Felder in der Öberfläche "FAQ Übersicht" im Kunden-Interface. Mögliche Einstellungen: 0 = deaktiviert, 1 = aktiviert, 2 = aktiviert und benötigt.';
    $Lang->{
        'Dynamic fields shown in the FAQ overview screen of the public interface. Possible settings: 0 = Disabled, 1 = Enabled, 2 = Enabled and required.'
        }
        =
        'Anzeige von dynamischen Felder in der Öberfläche "FAQ Übersicht" im Public-Interface. Mögliche Einstellungen: 0 = deaktiviert, 1 = aktiviert, 2 = aktiviert und benötigt.';
    $Lang->{
        'Dynamic fields shown in the FAQ print screen of the agent interface. Possible settings: 0 = Disabled, 1 = Enabled.'
        }
        =
        'Anzeige von dynamischen Felder in der Öberfläche "FAQ drucken" im Agenten-Interface. Mögliche Einstellungen: 0 = deaktiviert, 1 = aktiviert, 2 = aktiviert und benötigt.';
    $Lang->{
        'Dynamic fields shown in the FAQ print screen of the customer interface. Possible settings: 0 = Disabled, 1 = Enabled.'
        }
        =
        'Anzeige von dynamischen Felder in der Öberfläche "FAQ drucken" im Kunden-Interface. Mögliche Einstellungen: 0 = deaktiviert, 1 = aktiviert, 2 = aktiviert und benötigt.';
    $Lang->{
        'Dynamic fields shown in the FAQ print screen of the public interface. Possible settings: 0 = Disabled, 1 = Enabled.'
        }
        =
        'Anzeige von dynamischen Felder in der Öberfläche "FAQ drucken" im Public-Interface. Mögliche Einstellungen: 0 = deaktiviert, 1 = aktiviert, 2 = aktiviert und benötigt.';
    $Lang->{
        'Dynamic fields shown in the FAQ search screen of the agent interface. Possible settings: 0 = Disabled, 1 = Enabled, 2 = Enabled and shown by default.'
        }
        =
        'Anzeige von dynamischen Felder in der Öberfläche "FAQ durchsuchen" im Agenten-Interface. Mögliche Einstellungen: 0 = deaktiviert, 1 = aktiviert, 2 = aktiviert und benötigt.';
    $Lang->{
        'Dynamic fields shown in the FAQ search screen of the customer interface. Possible settings: 0 = Disabled, 1 = Enabled, 2 = Enabled and shown by default.'
        }
        =
        'Anzeige von dynamischen Felder in der Öberfläche "FAQ durchsuchen" im Kunden-Interface. Mögliche Einstellungen: 0 = deaktiviert, 1 = aktiviert, 2 = aktiviert und benötigt.';
    $Lang->{
        'Dynamic fields shown in the FAQ search screen of the public interface. Possible settings: 0 = Disabled, 1 = Enabled, 2 = Enabled and shown by default.'
        }
        =
        'Anzeige von dynamischen Felder in der Öberfläche "FAQ durchsuchen" im Public-Interface. Mögliche Einstellungen: 0 = deaktiviert, 1 = aktiviert, 2 = aktiviert und benötigt.';
    $Lang->{
        'Dynamic fields shown in the FAQ small format overview screen of the agent interface. Possible settings: 0 = Disabled, 1 = Enabled.'
        }
        =
        'Anzeige von dynamischen Felder in der Öberfläche "small FAQ Übersicht" im Agenten-Interface. Mögliche Einstellungen: 0 = deaktiviert, 1 = aktiviert, 2 = aktiviert und benötigt.';
    $Lang->{
        'Dynamic fields shown in the FAQ zoom screen of the agent interface. Possible settings: 0 = Disabled, 1 = Enabled.'
        }
        =
        'Anzeige von dynamischen Feldern in der Oberfläche "FAQ Zoom" im Agenten-Interface. Mögliche Einstellungen: 0 = deaktiviert, 1 = aktiviert, 2 = aktiviert und benötigt.';
    $Lang->{
        'Dynamic fields shown in the FAQ zoom screen of the customer interface. Possible settings: 0 = Disabled, 1 = Enabled.'
        }
        =
        'Anzeige von dynamischen Feldern in der Oberfläche "FAQ Zoom" im Kunden-Interface. Mögliche Einstellungen: 0 = deaktiviert, 1 = aktiviert, 2 = aktiviert und benötigt.';
    $Lang->{
        'Dynamic fields shown in the FAQ zoom screen of the public interface. Possible settings: 0 = Disabled, 1 = Enabled.'
        }
        =
        'Anzeige von dynamischen Feldern in der Oberfläche "FAQ Zoom" im Public-Interface. Mögliche Einstellungen: 0 = deaktiviert, 1 = aktiviert, 2 = aktiviert und benötigt.';
    $Lang->{'Edit this FAQ'} = 'FAQ bearbeiten';
    $Lang->{'Enable multiple languages on FAQ module.'}
        = 'Multiple Sprachen im FAQ-Modul aktivieren.';
    $Lang->{'Enable voting mechanism on FAQ module.'}
        = 'Bewertungs-Mechanismus im FAQ-Modul aktivieren.';
    $Lang->{'FAQ AJAX Responder'}               = '';
    $Lang->{'FAQ AJAX Responder for Richtext.'} = '';
    $Lang->{'FAQ Area'}                         = 'FAQ-Bereich';
    $Lang->{'FAQ Area.'}                        = 'FAQ-Bereich.';
    $Lang->{'FAQ Delete.'}                      = 'FAQ Löschen.';
    $Lang->{'FAQ Edit.'}                        = 'FAQ Bearbeiten.';
    $Lang->{'FAQ Journal Overview "Small" Limit'}
        = 'FAQ-Journal Anzeige-Limit für die Small-Ansicht';
    $Lang->{'FAQ Overview "Small" Limit'} = 'FAQ-Übersicht "kleines" Limit';
    $Lang->{'FAQ Print.'}                 = 'FAQ Drucken.';
    $Lang->{'FAQ limit per page for FAQ Journal Overview "Small"'}
        = 'FAQ limit pro Seite für das FAQ-Journal in der Small-Ansicht.';
    $Lang->{'FAQ limit per page for FAQ Overview "Small"'}
        = 'FAQ limit pro Seite für die Small-Ansicht.';
    $Lang->{'FAQ search backend router of the agent interface.'}
        = 'Such-Backend-Router für die FAQ-Suche im Agenten-Interface.';
    $Lang->{'Field4'} = 'Feld4';
    $Lang->{'Field5'} = 'Feld5';
    $Lang->{'Frontend module registration for the public interface.'}
        = 'Frontend-Modul-Registrierung für das Public-Interface';
    $Lang->{'Full FAQ'} = 'Vollständiges FAQ';
    $Lang->{'Group for the approval of FAQ articles.'}
        = 'Gruppe für die Freigabe von FAQ-Artikeln.';
    $Lang->{'History of this FAQ'} = 'FAQ-Historie';
    $Lang->{'Include internal fields on a FAQ based Ticket.'}
        = 'Interne FAQ-Felder in einem FAQ-basiertenTicket verwenden.';
    $Lang->{'Include the name of each field in a FAQ based Ticket.'}
        = 'Den Namen jedes FAQ-Feldes einem FAQ-basierten Ticket verwenden.';
    $Lang->{'Interfaces where the quick search should be shown.'}
        = 'Oberfläche auf der die Schnellsuche angezeigt werden soll';
    $Lang->{'Journal'}             = 'Journal';
    $Lang->{'Language Management'} = 'Sprachen-Verwaltung';
    $Lang->{'Link another object to this FAQ item'}
        = 'Diese FAQ mit einem anderen Objekt verknüpfen';
    $Lang->{'List of state types which can be used in the agent interface.'} =
        'Liste der Statustypen, die in der Agentenoberfläche genutzt werden können.';
    $Lang->{'List of state types which can be used in the customer interface.'} =
        'Liste der Statustypen, die in der Kundenoberfläche genutzt werden können.';
    $Lang->{'List of state types which can be used in the public interface.'} =
        'Liste der Statustypen, die in der öffentlichen Oberfläche genutzt werden können.';
    $Lang->{
        'Maximum number of FAQ articles to be displayed in the FAQ Explorer result of the agent interface.'
        }
        =
        'Maximale Anzahl von FAQ-Artikeln die im FAQ-Explorerl im Agenten-Interface angezeigt werden.';
    $Lang->{
        'Maximum number of FAQ articles to be displayed in the FAQ Explorer result of the customer interface.'
        }
        =
        'Maximale Anzahl von FAQ-Artikeln die in der FAQ-Explorer im Kunden-Interface angezeigt werden.';
    $Lang->{
        'Maximum number of FAQ articles to be displayed in the FAQ Explorer result of the public interface.'
        }
        =
        'Maximale Anzahl von FAQ-Artikeln die in der FAQ-Explorer im Public-Interface angezeigt werden.';
    $Lang->{
        'Maximum number of FAQ articles to be displayed in the FAQ journal in the agent interface.'
        }
        =
        'Maximale Anzahl von FAQ-Artikeln die im FAQ-Journal im Agenten-Interface angezeigt werden.';
    $Lang->{
        'Maximum number of FAQ articles to be displayed in the result of a search in the agent interface.'
        }
        =
        'Maximale Anzahl von FAQ-Artikeln die in der FAQ-Suche im Agenten-Interface angezeigt werden.';
    $Lang->{
        'Maximum number of FAQ articles to be displayed in the result of a search in the customer interface.'
        }
        =
        'Maximale Anzahl von FAQ-Artikeln die in der FAQ-Suche im Kunden-Interface angezeigt werden.';
    $Lang->{
        'Maximum number of FAQ articles to be displayed in the result of a search in the public interface.'
        }
        =
        'Maximale Anzahl von FAQ-Artikeln die in der FAQ-Suche im Public-Interface angezeigt werden.';
    $Lang->{
        'Maximum size of the titles in a FAQ article to be shown in the FAQ Explorer in the agent interface.'
        }
        =
        'Maximale Größe von Titeln in Häufig-gestellten-Fragen-Beiträgen welche im Häufig-gestellte-Fragen-Explorer der Agentenübersicht angezeigt werden.';
    $Lang->{
        'Maximum size of the titles in a FAQ article to be shown in the FAQ Explorer in the customer interface.'
        }
        =
        'Maximale Größe von Titeln in Häufig-gestellten-Fragen-Beiträgen welche im Häufig-gestellte-Fragen-Explorer der Kundenübersicht angezeigt werden.';
    $Lang->{
        'Maximum size of the titles in a FAQ article to be shown in the FAQ Explorer in the public interface.'
        }
        =
        'Maximale Größe von Titeln in Häufig-gestellten-Fragen-Beiträgen welche im Häufig-gestellte-Fragen-Explorer der öffentlichen Übersicht angezeigt werden.';
    $Lang->{
        'Maximum size of the titles in a FAQ article to be shown in the FAQ Search in the agent interface.'
        }
        =
        'Maximale Größe von Titeln in Häufig-gestellten-Fragen-Beiträgen welche in der Häufig-gestellte-Fragen-Suche der Agentenübersicht angezeigt werden.';
    $Lang->{
        'Maximum size of the titles in a FAQ article to be shown in the FAQ Search in the customer interface.'
        }
        =
        'Maximale Größe von Titeln in Häufig-gestellten-Fragen-Beiträgen welche in der Häufig-gestellte-Fragen-Suche der Kundenübersicht angezeigt werden.';
    $Lang->{
        'Maximum size of the titles in a FAQ article to be shown in the FAQ Search in the public interface.'
        }
        =
        'Maximale Größe von Titeln in Häufig-gestellten-Fragen-Beiträgen welche in der Häufig-gestellte-Fragen-Suche der öffentlichen Übersicht angezeigt werden.';
    $Lang->{
        'Maximum size of the titles in a FAQ article to be shown in the FAQ journal in the agent interface.'
        }
        =
        'Maximale Größe von Titeln in Häufig-gestellten-Fragen-Beiträgen welche in FAQ-Berichten in der Agentenübersicht angezeigt werden.';
    $Lang->{'New FAQ Article'} = 'Neuer FAQ-Artikel';
    $Lang->{'New FAQ articles need approval before they get published.'}
        = 'Neue FAQ-Artikel benötigen eine Freigabe vor der Veröffentlichung.';
    $Self->{Translation}
        ->{'Number of FAQ articles to be displayed in the FAQ Explorer of the customer interface.'}
        =
        'Maximale Anzahl von FAQ-Artikeln die im FAQ-Explorer im Kunden-Interface angezeigt werden.';
    $Self->{Translation}
        ->{'Number of FAQ articles to be displayed in the FAQ Explorer of the public interface.'}
        =
        'Maximale Anzahl von FAQ-Artikeln die im FAQ-Explorer in der öffentlichen Oberfläche angezeigt werden.';
    $Lang->{
        'Number of FAQ articles to be displayed on each page of a search result in the customer interface.'
        }
        =
        'Setzt in Suchergebnissen die Anzahl von FAQ-Artikeln pro Seite in der Kundenoberfläche.';
    $Lang->{
        'Number of FAQ articles to be displayed on each page of a search result in the public interface.'
        }
        =
        'Setzt in Suchergebnissen die Anzahl von FAQ-Artikeln pro Seite in der öffentlichen Oberfläche.';
    $Lang->{'Number of shown items in last changes.'}
        = 'Anzahl der zu anzeigenden Artikel in letzten Änderungen.';
    $Lang->{'Number of shown items in last created.'}
        = 'Anzahl der anzuzeigenden Artikel in zuletzt erstellte Artikel.';
    $Lang->{'Number of shown items in the top 10 feature.'}
        = 'Anzahl der anzuzeigenden Artikel im Top 10 Feature.';
    $Lang->{
        'Parameters for the pages (in which the FAQ items are shown) of the small FAQ journal overview.'
        }
        =
        'Parameter für die Seiten (in denen FAQ-Artikel angezeigt werden) für die Small-Ansicht des FAQ-Journals.';
    $Self->{Translation}
        ->{'Parameters for the pages (in which the FAQ items are shown) of the small FAQ overview.'}
        =
        'Parameter für die Seiten (in denen FAQ-Artikel angezeigt werden) für die Small-Ansicht des FAQ-Overiews.';
    $Lang->{'Print this FAQ'}     = 'FAQ drucken';
    $Lang->{'Public FAQ Print.'}  = 'Öffentliches FAQ Drucken.';
    $Lang->{'Public FAQ Zoom.'}   = '';
    $Lang->{'Public FAQ search.'} = 'Öffentliches FAQ Suchen.';
    $Lang->{'Public FAQ.'}        = 'Öffentliches FAQ.';
    $Lang->{'Queue for the approval of FAQ articles.'}
        = 'Queue für die Freigabe von FAQ-Artikeln.';
    $Lang->{'Rates for voting. Key must be in percent.'}
        = 'Gewichtung für die Bewertung. Der Key muss in Prozent angegeben werden.';
    $Lang->{'S'}          = 'S';
    $Lang->{'Search FAQ'} = 'FAQ durchsuchen';
    $Self->{Translation}
        ->{'Set the default height (in pixels) of inline HTML fields in AgentFAQZoom.'}
        =
        'Setzt die maximale Höhe (in Pixeln) von Inline-HTML-Felder in AgentFAQZoom.';
    $Lang->{
        'Set the default height (in pixels) of inline HTML fields in CustomerFAQZoom (and PublicFAQZoom).'
        }
        =
        'Setzt die maximale Höhe (in Pixeln) von Inline-HTML-Felder in CustomerFAQZoom (und PublicFAQZoom).';
    $Self->{Translation}
        ->{'Set the maximum height (in pixels) of inline HTML fields in AgentFAQZoom.'}
        =
        'Setzt die maximale Höhe (in Pixeln) von Inline-HTML-Felder in AgentFAQZoom.';
    $Lang->{
        'Set the maximum height (in pixels) of inline HTML fields in CustomerFAQZoom (and PublicFAQZoom).'
        }
        =
        'Setzt die maximale Höhe (in Pixeln) von Inline-HTML-Felder in CustomerFAQZoom (und PublicFAQZoom).';
    $Self->{Translation}
        ->{'Disable sandbox-attribute for the FAQ content (AgentFAQZoom and AgentFAQZoomSmall). Disabling this attribute can be a security issue!'}
        =
        'Deaktiviert das sandbox-Attribut für den FAQ-Inhalt (AgentFAQZoom und AgentFAQZoomSmall). Die Deaktivierung kann ein Sicherheitsthema sein!';
    $Lang->{
        'Disable sandbox-attribute for the FAQ content (CustomerFAQZoom and PublicFAQZoom). Disabling this attribute can be a security issue!'
        }
        =
        'Deaktiviert das sandbox-Attribut für den FAQ-Inhalt (CustomerFAQZoom und PublicFAQZoom). Die Deaktivierung kann ein Sicherheitsthema sein!';
    $Self->{Translation}
        ->{'Show "Insert FAQ Link" Button in AgentFAQZoomSmall for public FAQ Articles.'}
        =
        'Zeigt die Schaltfläche "FAQ-Link einfügen" in AgentFAQZoomSmall für öffentliche FAQ-Artikel an.';
    $Lang->{
        'Show "Insert FAQ Text & Link" / "Insert Full FAQ & Link" Button in AgentFAQZoomSmall for public FAQ Articles.'
        }
        =
        'Zeigt die Schaltfläche "FAQ-Text & Link einfügen / Komplette FAQ & Link einfügen" in AgentFAQZoomSmall für öffentliche FAQ-Artikel an.';
    $Self->{Translation}
        ->{'Show "Insert FAQ Text" / "Insert Full FAQ" Button in AgentFAQZoomSmall.'}
        =
        'Zeigt die Schaltfläche "FAQ-Text einfügen / Komplette FAQ einfügen" in AgentFAQZoomSmall an.';
    $Lang->{'Show FAQ Article with HTML.'}
        = 'HTML Darstellung der FAQ-Artikel einschalten.';
    $Lang->{'Show FAQ path yes/no.'} = 'FAQ Pfad anzeigen ja/nein.';
    $Lang->{'Show invalid items in the FAQ Explorer result of the agent interface.'}
        =
        '';
    $Lang->{'Show items of subcategories.'}
        = 'Artikel aus Subkategorien anzeigen ja/nein.';
    $Lang->{'Show last change items in defined interfaces.'}
        = 'Interfaces in denen das LastChange Feature angezeigt werden soll.';
    $Lang->{'Show last created items in defined interfaces.'}
        = 'Interfaces in denen das LastCreate Feature angezeigt werden soll.';
    $Lang->{'Show top 10 items in defined interfaces.'}
        = 'Interfaces in denen das Top 10 Feature angezeigt werden soll.';
    $Lang->{'Show voting in defined interfaces.'}
        = 'Interfaces in denen das Voting Feature angezeigt werden soll.';
    $Lang->{
        'Shows a link in the menu that allows linking a FAQ with another object in the zoom view of such FAQ of the agent interface.'
        }
        =
        'Zeigt einen Link in der Menu-Leiste in der Zoom-Ansicht im Agenten-Interface an, der es ermöglicht einen FAQ-Artikel mit anderen Objekten zu verknüpfen.';
    $Lang->{
        'Shows a link in the menu that allows to delete a FAQ in its zoom view in the agent interface.'
        }
        =
        'Zeigt einen Link in der Menu-Leiste in der Zoom-Ansicht im Agenten-Interface an, der es ermöglicht einen FAQ-Artikel zu löschen.';
    $Lang->{
        'Shows a link in the menu to access the history of a FAQ in its zoom view of the agent interface.'
        }
        =
        'Zeigt einen Link in der Menu-Leiste in der Zoom-Ansicht im Agenten-Interface an, um die Historie eines FAQ-Artikels anzuzeigen.';
    $Self->{Translation}
        ->{'Shows a link in the menu to edit a FAQ in the its zoom view of the agent interface.'}
        =
        'Zeigt einen Link in der Menu-Leiste in der Zoom-Ansicht im Agenten-Interface an, der es ermöglicht einen FAQ-Artikel zu bearbeiten.';
    $Self->{Translation}
        ->{'Shows a link in the menu to go back in the FAQ zoom view of the agent interface.'}
        =
        'Zeigt einen Link in der Menu-Leiste in der Zoom-Ansicht im Agenten-Interface an, der es ermöglicht zur vorherigen Seite zurück zu gehen.';
    $Self->{Translation}
        ->{'Shows a link in the menu to print a FAQ in the its zoom view of the agent interface.'}
        =
        'Zeigt einen Link in der Menu-Leiste in der Zoom-Ansicht im Agenten-Interface an, der es ermöglicht einen FAQ-Artikel zu drucken.';
    $Lang->{'Text Only'} = 'Nur Text';
    $Lang->{'The identifier for a FAQ, e.g. FAQ#, KB#, MyFAQ#. The default is FAQ#.'}
        =
        'Der Identifikator für einen FAQ-Artikel, z. B. FAQ#, KB#, MyFAQ#. Der Standardwert ist FAQ#.';
    $Lang->{
        'This setting defines that a \'FAQ\' object can be linked with other \'FAQ\' objects using the \'Normal\' link type.'
        }
        =
        'Definiert, dass ein \'FAQ\'-Objekte mit dem Linktyp \'Normal\' mit anderen \'FAQ\'-Objekten verlinkt werden kann.';
    $Lang->{
        'This setting defines that a \'FAQ\' object can be linked with other \'FAQ\' objects using the \'ParentChild\' link type.'
        }
        =
        'Definiert, dass ein \'FAQ\'-Objekte mit dem Linktyp \'ParentChild\' mit anderen \'FAQ\'-Objekten verlinkt werden kann.';
    $Lang->{
        'This setting defines that a \'FAQ\' object can be linked with other \'Ticket\' objects using the \'Normal\' link type.'
        }
        =
        'Definiert, dass ein \'FAQ\'-Objekte mit dem Linktyp \'Normal\' mit anderen \'Ticket\'-Objekten verlinkt werden kann.';
    $Lang->{
        'This setting defines that a \'FAQ\' object can be linked with other \'Ticket\' objects using the \'ParentChild\' link type.'
        }
        =
        'Definiert, dass ein \'FAQ\'-Objekte mit dem Linktyp \'ParentChild\' mit anderen \'Ticket\'-Objekten verlinkt werden kann.';
    $Lang->{'Ticket body for approval of FAQ article.'}
        = 'Body des Tickets zur Freigabe eines FAQ-Artikels.';
    $Lang->{'Ticket subject for approval of FAQ article.'}
        = 'Betreff des Tickets zur Freigabe eines FAQ-Artikels.';
    $Lang->{'Toolbar Item for a shortcut.'}
        = 'Werkzeugleisteneintrag für den Schnellzugriff.';
    $Lang->{'public (public)'} = 'öffentlich (öffentlich)';

    $Lang->{'First Customer Article'}        = 'Erste Kundenmeldung';
    $Lang->{'General Ticket Data'}           = 'Allgemeine Vorgangsinformationen';
    $Lang->{'Related CI Data'}               = 'Daten verbundener CIs';
    $Lang->{'Fax to'}                        = 'Telefax an';
    $Lang->{'Order for Incident Processing'} = 'Auftrag zur Bearbeitung';
    $Lang->{'ADDITIONAL NOTE'}               = 'ZUSÄTZLICHE ANMERKUNG';
    $Lang->{'RELATED OBJECT DATA'}           = 'DATEN VERKNÜPFTER OBJEKTE';
    $Lang->{'FORM DATA'}                     = 'FORMULAR DATEN';
    $Lang->{'CUSTOMER DATA'}                 = 'KUNDENDATEN';
    $Lang->{'PROBLEM DESCRIPTION'}           = 'PROBLEMBESCHREIBUNG';
    $Lang->{'Sincerly, Yours'}               = 'viele Grüße, Ihr';
    $Lang->{'Ticket Title'}                  = 'Tickettitel';
    $Lang->{'Ticket Number'}                 = 'Ticketnummer';
    $Lang->{'Ticket information forwarded to external supplier!'} =
        'Ticketinformation an externen Dienstleister gesendet!';
    $Lang->{
        'This issue/information update has automatically been forwarded to you as external supplier for'
        }
        = 'Diese Anfrage/Aktualisierung wurde automatisch an Sie weitergeleitet, als externen Dienstleister für'
        ;
    $Lang->{'NOTE: Please do NOT remove the processing number from your response - Thank you.'}
        = 'NOTIZ: Bitte entfernen Sie die Ticketnummer NICHT aus Ihrer Antwort - Danke.';
    $Lang->{'This issue has automatically been forwarded to you as external supplier for'}
        = 'Diese Anfrage wurde automatisch an Sie weitergeleitet, als externen Dienstleister für';
    $Lang->{'A new information has been added to an issue which has already been forwarded to you.'}
        = 'Eine neue Information wurde zu einem bereits an Sie weitergeleitetes Ticket hinzugefügt.';
    $Lang->{'Class'}                = 'Klasse';
    $Lang->{'CurInciState'}         = 'Zwischenfallsstatus';
    $Lang->{'InciState'}            = 'Akt. Zwischenfallsstatus';
    $Lang->{'DeplState'}            = 'Status';
    $Lang->{'CurDeplState'}         = 'Akt. Status';
    $Lang->{'Print Forward Fax'}    = 'Weiterleitungsfax drucken';
    $Lang->{'Location Information'} = 'Lokationsinformationen';
    $Lang->{'NameShort'}            = 'Name (kurz)';
    $Lang->{'Phone1'}               = 'Telefon 1';
    $Lang->{'Phone2'}               = 'Telefon 2';
    $Lang->{'Further ticket data'}  = 'Weitere Ticketdaten';
    $Lang->{'Edit this ticket'}     = 'Dieses Ticket bearbeiten';
    $Lang->{'Print forward fax for this ticket!'}
        = 'Weiterleitungsfax für dieses Ticket drucken!';
    $Lang->{'Defines CI-attributes for CI-Classes which are not forwarded.'}
        = 'Definiert CI-Attribute fuer CI-Klassen, die nicht weitergeleitet werden.';
    $Lang->{'Defines only CI-attributes for CI-Classes which are forwarded.'}
        = 'Definiert nur die CI-Attribute fuer CI-Klassen, die weitergeleitet werden.';
    $Lang->{
        'Defines BCC-Mailaddress for ExternalSupplierForwarding-Submissions - useful for debugging, does not provide separate encryption forr bcc-receipient.'
        }
        = 'Definiert BCC-Mailadresse fuer ExternalSupplierForwarding-Uebermittlungen - nuetzlich zum Debuggen, stellt keine separate Verschluesselung fuer BCC-Empfaenger zur Verfuegung.';
    $Lang->{'Defines the classes of linked object which are relevant to be forwarded (included).'}
        = 'Legt die Klassen der weiterzuleitenden (zu inkludierenden) Objekte fest';
    $Lang->{
        'Defines article types which are forwarded if added to tickets in Fwd-Queues (note-report will NOT be considered!).'
        }
        = 'Definiert Artikeltypen die weiterleitet werden, wenn sie zu Tickets in spez. Queues hinzugefuegt werden (Note-Report wird NICHT beachtet).';
    $Lang->{'Defines PGP-Keys for mail addresses which are not registered in the key.'}
        = 'Definiert PGP-Schluessel fuer Mailadressen die im Schluessel nicht registriert sind.';
    $Lang->{'Defines mapping of KIX queues to be forwarded and corresponding email-addresses.'}
        = 'Definiert Mapping von weiterzuleitenden KIX-queues und den entsprechenden Email-Adressen.';
    $Lang->{'Module to decrypt PGP-encrypted mails before any other processing.'}
        = 'Modul zum Entschluesseln von PGP-verschluesselten Emails vor allen weiteren Bearbeitungen.';
    $Lang->{'Ticket-ACL to show/hide ticket action AgentTicketPrintForwardFax.'}
        = 'Ticket-ACL zum Anzeigen/Verstecken von Ticket-Aktion AgentTicketPrintForwardFax.';
    $Lang->{'Workflowmodule which forwards the ticket (1st article) and related CIs.'}
        = 'Workflow-Modul welches das Ticket (1. Artikel) und verknuepfte CIs weiterleitet.';
    $Lang->{'Extended organization description.'} = 'Erweiterte Organisationsbeschreibung.';
    $Lang->{'Defines which ticket dynamic fields are forwarded.'}
        = 'Definiert welche dynamischen Felder weitergeleitet werden.';
    $Lang->{'Defines mapping of KIX queues to be fax-forwarded and corresponding fax-numbers.'}
        = 'Definiert Mapping von per Fax weiterzuleitenden KIX-queues und den entsprechenden FAX-Nummern.';
    $Lang->{
        'Frontend module registration for the AgentTicketPrintForwardFax object in the agent interface.'
        } = 'Frontendmodul-Registration des AgentTicketPrintForwardFax-Objekts im Agent-Interface.';
    $Lang->{'Module to show print forward fax link in menu.'}
        = 'Über dieses Modul wird der Weiterleitungs-Fax-Drucken-Link in der Linkleiste der Ticketansicht angezeigt.';
    $Lang->{'Available articles'} = 'Verfügbare Artikel';
    $Lang->{'Article selection for PrintForwardFax'}
        = 'Artikelauswahl für das Weiterleitungsfax';

    $Lang->{'notesupplier-external'} = 'Notiz extern an Dienstleister';
    $Lang->{'notesupplier-internal'} = 'Notiz intern an Dienstleister';

    # Options
    $Lang->{'MaxArraySize'}      = 'Anzahl Einträge';
    $Lang->{'Number of records'} = 'Anzahl Datensätze';
    $Lang->{'ItemSeparator'}     = 'Anzeigetrenner';

    $Lang->{'DatabaseDSN'}         = 'Datenbank DSN';
    $Lang->{'DatabaseUser'}        = 'Datenbank Benutzer';
    $Lang->{'DatabaseType'}        = 'Datenbank Typ';
    $Lang->{'DatabasePw'}          = 'Datenbank Passwort';
    $Lang->{'DatabaseTable'}       = 'Datenbank Tabelle';
    $Lang->{'DatabaseFieldKey'}    = 'Datenbank Schlüsselspalte';
    $Lang->{'DatabaseFieldValue'}  = 'Datenbank Wertspalte';
    $Lang->{'DatabaseFieldSearch'} = 'Datenbank Suchspalte';

    $Lang->{'SearchPrefix'} = 'Suchprefix';
    $Lang->{'SearchSuffix'} = 'Suchsuffix';

    $Lang->{'CachePossibleValues'} = 'Cache für mögliche Werte';

    $Lang->{'Constrictions'} = 'Einschränkungen';

    $Lang->{'ShowKeyInTitle'}     = 'Zeige Schlüssel in Tooltip';
    $Lang->{'ShowKeyInSearch'}    = 'Zeige Schlüssel in Sucheinträgen';
    $Lang->{'ShowKeyInSelection'} = 'Zeige Schlüssel in Auswahl';
    $Lang->{'ShowMatchInResult'}  = 'Zeige Treffer in Ergebnis';

    $Lang->{'EditorMode'} = 'Editormodus';

    $Lang->{'MinQueryLength'} = 'Mindeste Querylänge';
    $Lang->{'QueryDelay'}     = 'Queryverzögerung';
    $Lang->{'MaxQueryResult'} = 'Maximale Queryergebnisse';

    # Descriptions...
    $Lang->{'Specify the maximum number of entries.'}  = 'Gibt die maximale Anzahl möglicher Einträge an.';
    $Lang->{'Specify the maximum number of records.'}  = 'Gibt die maximale Anzahl möglicher Datensätze an.';
    $Lang->{'Specify the DSN for used database.'}      = 'Gibt die DSN der Datenbank an.';
    $Lang->{'Specify the user for used database.'}     = 'Gibt den Benutzer der Datenbank an.';
    $Lang->{'Specify the password for used database.'} = 'Gibt das Passwort der Datenbank an.';
    $Lang->{'Specify the table for used database.'}    = 'Gibt die Tabelle der Datenbank an.';
    $Lang->{'Specify the type of used database.'}      = 'Gibt den Typ der Datenbank an.';
    $Lang->{'The key column of the database is the column which the data record identifies and from where the value to be stored can be obtained.'}
        = 'Die Schlüsselspalte der Datenbank ist die Spalte, womit der Datensatz identifiziert und woher der zu speichernde Wert bezogen werden kann.';
    $Lang->{'The value column is the column of the table used that returns the value of the data record for display. If no value column has been specified, the key column is used as a fallback.'}
        = 'Die Wertespalte ist die Spalte der Tabelle, die genutzt wird, um den Wert des Datensatzes für die Anzeige zurückzugeben. Wenn keine Wertespalte angegeben wurde,wird die Schlüsselspalte genutzt.';
    $Lang->{'The search column is the column (or several columns separated by commas) of the table used in which a suitable data record can be searched for. If no search column has been specified, the key column is used as a fallback.'}
        = 'Die Suchspalte ist die Spalte (oder mehrere Spalten getrennt mit Kommas) der Tabelle, die genutzt wird, um dort nach einem passenden Datensatz zu suchen. Wenn keine Wertespalte angegeben wurde,wird die Schlüsselspalte genutzt.';
    $Lang->{'The value of the key column is used as an identifier of the selected data record.'}
        = 'Der Wert des Schlüsselspalte wird als Kenner des gewählten Datensatzes genutzt.';
    $Lang->{'The value column is the column of the database table that returns the value of the data record for display. If no value column has been specified, the key column is used as a fallback.'}
        = 'Die Wertspalte ist die Spalte der verwendeten Tabelle, die den Wert des Datensatzes zur Anzeige zurück gibt. Ist keine Wertspalte festgelegt worden, wird die Schlüsselspalte als Fallback verwendet.';
    $Lang->{'The search column is the column (or several columns separated by commas) of the database table in which a suitable data record can be searched for. If no search column has been specified, the key column is used as a fallback.'}
        = 'Die Suchspalte ist die Spalte (oder kommasepariert mehrere Spalten) der verwendeten Tabelle, worin nach einen passenden Datensatz gesucht werden kann. Ist keine Suchspalte festgelegt worden, wird die Schlüsselspalte als Fallback verwendet.';
    $Lang->{'Needed for ODBC connections.'}
        = 'Wird für ODBC-Verbindungen benötigt.';
    $Lang->{'Supported are mssql, mysql, oracle and postgresql.'}
        = 'Unterstützt werden mssql, mysql, oracle und postgresql.';
    $Lang->{'Specify constrictions for search-queries. [TableColumn]::[Object]::[Attribute/Value]::[Mandatory]'}
        = 'Gibt Einschränkungen für Suchanfragen an. [Tabellenspalte]::[Objekt]::[Attribut/Wert]::[Pflichtfeld]';
    $Lang->{'Cache any database queries for time in seconds.'}
        = 'Gibt die Zeit in Sekunden an, welche Datenbankanfragen gecached werden.';
    $Lang->{'Cache all possible values.'} = 'Mögliche Werte der Datenbank werden gecached.';
    $Lang->{'0 deactivates caching.'}     = '0 deaktiviert den Cache.';
    $Lang->{'If active, the usage of values which recently added to the database may cause an error.'}
        = 'Wenn aktiv, kann die Verwendung von Werten, welche kürzlich zur Datenbank hinzugefügt wurden, Fehler verursachen.';
    $Lang->{'Specify if key is added to HTML-attribute title.'}
        = 'Gibt an, ob der Schlüssel im HTML-Attribut title angefügt wird.';
    $Lang->{'Specify if key is added to entries in search.'}
        = 'Gibt an, ob der Schlüssel an Auswahlwerte in der Suche angefügt wird.';
    $Lang->{'Specify the separator of displayed values for this field.'}
        = 'Gibt den Trenner für die angezeigten Werte an.';
    $Lang->{'for Agent'}                 = 'für Agent';
    $Lang->{'Used in AgentFrontend.'}    = 'Verwendet im Agentenfrontend.';
    $Lang->{'for Customer'}              = 'für Kunde';
    $Lang->{'Used in CustomerFrontend.'} = 'Verwendet im Kundenfrontend.';
    $Lang->{'Following placeholders can be used:'}
        = 'Folgende Platzhalter können verwendet werden:';
    $Lang->{'Same placeholders as for agent link available.'}
        = 'Gleiche Platzhalter wie für Agentenlink verfügbar.';
    $Lang->{'Specify the field for search.'} = 'Gibt die Suchspalte in der Datenbank an.';
    $Lang->{'Multiple columns to search can be configured comma separated.'}
        = 'Mehrere Suchspalten können kommasepariert angegeben werden.';
    $Lang->{'Specify a prefix for the search.'} = 'Gib ein Prefix für die Suche an.';
    $Lang->{'Specify a suffix for the search.'} = 'Gib ein Suffix für die Suche an.';
    $Lang->{'Specify the MinQueryLength. 0 deactivates the autocomplete.'}
        = 'Gibt die Mindestzahl von Zeichen an, bevor die Autovervollständigung aktiv wird. 0 deaktiviert die Autovervollständigung.';
    $Lang->{'Specify the QueryDelay.'} = 'Gibt die Verzögerung für die Autovervollständigung an';
    $Lang->{'Specify the MaxQueryResult.'}
        = 'Gibt die Maximalzahl an Vorschlägen für die Autovervollständigung an.';
    $Lang->{'Should the search be case sensitive?'} = 'Soll die Suche "Case Sensitive" sein?';
    $Lang->{'Some database systems don\'t support this. (For example MySQL with default settings)'}
        = 'Manche Datenbanksysteme unterstützen dies nicht. (Beispielsweise MySQL mit Standardkonfiguration)';

    $Lang->{'Comma (,)'}      = 'Komma (,)';
    $Lang->{'Semicolon (;)'}  = 'Semikolon (;)';
    $Lang->{'Whitespace ( )'} = 'Leerzeichen ( )';

    $Lang->{'Config item classes'} = 'Config Item Klassen';
    $Lang->{'Deployment states'}   = 'Verwendungsstatus';
    $Lang->{'Key type'}            = 'Schlüsseltyp';
    $Lang->{'Display pattern'}     = 'Anzeigevorlage';
    $Lang->{'MinQueryLength'}      = 'Mindeste Querylänge';
    $Lang->{'QueryDelay'}          = 'Queryverzögerung';
    $Lang->{'MaxQueryResult'}      = 'Maximale Queryergebnisse';
    $Lang->{'MaxArraySize'}        = 'Anzahl Einträge';
    $Lang->{'ItemSeparator'}       = 'Anzeigetrenner';
    $Lang->{'Default values'}      = 'Standardwerte';

    # Descriptions...
    $Lang->{'Select relevant config item classes.'}
        = 'Relevante Config Item Klassen auswählen.';
    $Lang->{'Select relevant deployment states.'}
        = 'Relevante Verwendungsstatus auswählen.';
    $Lang->{'Permission Check'} = 'Berechtigungsprüfung';
    $Lang->{'Activates the permission check of the classes for the relevant interface.'}
        = 'Aktiviert die Berechtigungsprüfung der Klassen für das relevante Interface.';
    $Lang->{
        'Specify Constrictions for CI-search. [CI-Attribute]::[Object]::[Attribute/Value]::[Mandatory]'
        }
        = 'Einschränkungen für die CI-Suche angeben. [CI-Attribut]::[Objekt]::[Attribut/Wert]::[Pflichtattribut].';
    $Lang->{'Specify pattern used for display.'}
        = 'Vorlage für die Anzeige angeben.';
    $Lang->{'Following placeholders can be used:'}
        = 'Folgende Platzhalter können verwendet werden:';
    $Lang->{'Same placeholders as for display pattern available.'}
        = 'Gleiche Platzhalter wie für Anzeigevorlage verfügbar.';
    $Lang->{'Addtional available:'}
        = 'Zusätzlich verfügbar:';
    $Lang->{'Specify the MinQueryLength. 0 deactivates the autocomplete.'}
        = 'Gibt die Mindestzahl von Zeichen an, bevor die Autovervollständigung aktiv wird. 0 deaktiviert die Autovervollständigung.';
    $Lang->{'Specify the QueryDelay.'}
        = 'Gibt die Verzögerung für die Autovervollständigung an';
    $Lang->{'Specify the MaxQueryResult.'}
        = 'Gibt die Maximalzahl an Vorschlägen für die Autovervollständigung an.';
    $Lang->{'Specify which display type is used.'}
        = 'Gibt an, welcher Anzeigetyp genutzt wird';
    $Lang->{
        'Create link between ticket and config item on DynamicFieldUpdate (This event only create link, links can only be deleted manually).'
        }
        = 'Erzeugt bei einem DynamicFieldUpdate einen Link zwischen Ticket und Config Item (Dieses Event erstellt nur Links - Links müssen manuell entfernt werden).';
    $Lang->{'Specify the separator of displayed values for this field.'}
        = 'Gibt den Trenner für die angezeigten Werte an.';
    $Lang->{'Specify the maximum number of entries.'}
        = 'Gibt die maximale Anzahl möglicher Einträge an.';

    # Other
    $Lang->{'ITSMConfigItemReference'}               = 'ITSM-CMDB Auswahl';
    $Lang->{'Config Item ID'}                        = 'Config Item ID';
    $Lang->{'Config Item Name'}                      = 'Config Item Name';
    $Lang->{'Config Item Number'}                    = 'Config Item Nummer';
    $Lang->{'Config Item Name (Config Item Number)'} = 'Config Item Name (Config Item Nummer)';
    $Lang->{'Config Item Number (Config Item Name)'} = 'Config Item Nummer (Config Item Name)';

    $Lang->{'Comma (,)'}      = 'Komma (,)';
    $Lang->{'Semicolon (;)'}  = 'Semikolon (;)';
    $Lang->{'Whitespace ( )'} = 'Leerzeichen ( )';

    $Lang->{'Filename'}       = 'Dateiname';
    $Lang->{'Path'}           = 'Pfad';
    $Lang->{'DisplayPath'}    = 'Anzeigepfad';
    $Lang->{'DocumentLink'}   = 'Dokument';
    $Lang->{'Document'}       = 'Dokument';
    $Lang->{'Document Name'}  = 'Dokumentenname';
    $Lang->{'Ignore Case'}    = 'Gross-/Kleinschreibung ignorieren';
    $Lang->{'no access'}      = 'Kein Zugriff';
    $Lang->{'link not found'} = 'Keine Verknüpfung gefunden';

    # Document
    $Lang->{'This setting defines the link type \'DocumentLink\'.'} =
        'Definiert den Linktyp \'DocumentLink\'.';
    $Lang->{
        'This setting defines that a \'Ticket\' object can be linked with documents using the \'DocumentLink\' link type.'
        } =
        'Definiert, dass ein \'Ticket\'-Objekt mit dem Linktyp \'DocumentLink\' mit Dokumenten verlinkt werden kann.';
    $Lang->{
        'This setting defines that a \'Service\' object can be linked with documents using the \'DocumentLink\' link type.'
        } =
        'Definiert, dass ein \'Service\'-Objekt mit dem Linktyp \'DocumentLink\' mit Dokumenten verlinkt werden kann.';
    $Lang->{
        'This setting defines that a \'SLA\' object can be linked with documents using the \'DocumentLink\' link type.'
        } =
        'Definiert, dass ein \'SLA\'-Objekt mit dem Linktyp \'DocumentLink\' mit Dokumenten verlinkt werden kann.';
    $Lang->{
        'This setting defines that a \'ITSMConfigItem\' object can be linked with documents using the \'DocumentLink\' link type.'
        } =
        'Definiert, dass ein \'ITSMConfigItem\'-Objekt mit dem Linktyp \'DocumentLink\' mit Dokumenten verlinkt werden kann.';
    $Lang->{
        'This setting defines that a \'ITSMWorkOrder\' object can be linked with documents using the \'DocumentLink\' link type.'
        } =
        'Definiert, dass ein \'ITSMWorkOrder\'-Objekt mit dem Linktyp \'DocumentLink\' mit Dokumenten verlinkt werden kann.';
    $Lang->{
        'This setting defines that a \'ITSMChange\' object can be linked with documents using the \'DocumentLink\' link type.'
        } =
        'Definiert, dass ein \'ITSMChange\'-Objekt mit dem Linktyp \'DocumentLink\' mit Dokumenten verlinkt werden kann.';
    $Lang->{
        'Define the sources of documents. Use key in the following document settings. Prefer short keys.'
        } =
        'Definition der Quellen für Dokumente. Der Schlüssel wird für alle folgenden Einstellungen benötigt. Schlüsselbezeichnung kurz halten.';
    $Lang->{
        'Specify the backend typ for document link source. Equals modul name in document backend folder.'
        } =
        'Gibt das benutzte Backend für die Dokumentenverknüpfung an. Entspricht dem Namen des Dokumentenbackends.';
    $Lang->{'Specify the parameters of the document source.'} =
        'Gibt die Parameter für die Dokumentenquelle an.';
    $Lang->{'Specify groups that will have access the document source.'} =
        'Legt die Gruppen fest, die auf diese Dokumentenquelle zugreifen können.';
    $Lang->{
        'Specify the search type in FS sources ("live" is slower but does a live search in the directory tree and updates the meta data of the resulting files in the DB, "meta" is fast but only uses the meta data stored in the DB).'
        } =
        'Legt den Suchtyp in FS-Quellen fest ("live" ist langsamer, führt aber eine Live-Suche im Verzeichnisbaum durch und aktualisiert die Metadaten der gefundenen Files in der DB, "meta" ist schnell, nutzt aber lediglich die Metadaten in der DB).';
    $Lang->{'Specify the sync type for the periodic full sync of filesystem document sources.'} =
        'Legt den Sync-Typ für die periodische Voll-Synchronisation von Filesystem-Dokumentenquellen fest.';
    $Lang->{'Specify the path and name of the meta data file if sync type is MetaFile.'} =
        'Legt den Pfad und Namen der Metadaten-File für den Sync-Typ MetaFile fest.';
    $Lang->{
        'Columns that can be filtered in the linked object view of the agent interface. Possible settings: 0 = Disabled, 1 = Available, 2 = Enabled by default.'
        }
        = 'Spalten, die in der Anzeige der verlinkten Objekte in der Agentenoberfläche gefiltert werden. Mögliche Einstellungen, 1 = Verfügbar, 2 = Aktiv als Standard.';

    # translations missing in ImportExport...
    $Lang->{'Column Seperator'}           = 'Spaltentrenner';
    $Lang->{'Charset'}                    = 'Zeichensatz';
    $Lang->{'Restrict export per search'} = 'Export mittels Suche einschränken';

    $Lang->{'ValidID (not used in import anymore, use Validity instead)'}
        = 'ValidID (wird nicht im Import verwendet, bitte stattdessen Validity nutzen';
    $Lang->{'Default Customer ID'} = 'Standard Kunden-ID';
    $Lang->{'Maildomain-CustomerID Mapping (see SysConfig)'}
        = 'Maildomänen-Kunden-ID Zuordnung (siehe SysConfig)';
    $Lang->{'Default Email'}             = 'Standard Email';
    $Lang->{'Reset password if updated'} = 'Bei Update Passwort zurücksetzen';
    $Lang->{'Password-Suffix (new password = login + suffix)'}
        = 'Passwort-Suffix (neues Passwort = Login+Suffix)';
    $Lang->{'Force import in configured customer backend'} =
        'Erzwinge Import in konfigurierten Backend';

    $Lang->{'Object backend module registration for the import/export modul.'} =
        'Objekt-Backend Modul Registration des Import/Export Moduls.';
    $Lang->{
        'Defines which email address to use if not defined - strongly depends on backend configuration!!!.'
        } =
        'Definiert welche Mailadresse genutzt wird, wenn nicht gegeben - stark abhaengig von Backendkonfiguration!!!.';
    $Lang->{
        'Defines a mapping of email domains to customer IDs. A special key value is ANYTHINGELSE, which is similar to default customer ID but also affects updates.'
        } =
        'Definiert das Mapping von EMail-Domains zu KundenIDs. Ein besonderer Schluesselwert ist ANYTHINGELSE, welches sich wie DefaultCustomerID verhaelt, aber auch fuer Aktualisierung verwendet wird.';
    $Lang->{'Maximum number of one element'} = 'Maximale Anzahl eines Elements';
    $Lang->{'Empty fields indicate that the current values are kept'}
        = 'Leere Felder belassen den aktuellen Wert';
    $Lang->{'Array convert to'} = 'Liste konvertiern zu';
    $Lang->{'Array Separator by useing format string'}
        = 'Listentrenner bei Verwendung von Zeichenketten';
    $Lang->{'Semicolon (;)'} = 'Semikolon (;)';
    $Lang->{'Comma (,)'}     = 'Komma (,)';

    # translations missing in ImportExport...
    $Lang->{'CustomerCompany'}            = 'Kunden-Firma';
    $Lang->{'Column Seperator'}           = 'Spaltentrenner';
    $Lang->{'Charset'}                    = 'Zeichensatz';
    $Lang->{'Restrict export per search'} = 'Export mittels Suche einschränken';
    $Lang->{'Object backend module registration for the import/export module.'}
        = 'Objekt-Backend Modul Registration des Import/Export Moduls.';
    $Lang->{
        'Defines which customer ID to use if no company defined - only relevant for new contacts.'
        }
        = 'Definiert welche Kunden-ID genutzt wird, falls nicht in Mapping definiert - nur fuer neue Ansprechpartner-Eintraege relevant.';
    $Lang->{'Maximum number of one element'} = 'Maximale Anzahl eines Elements';
    $Lang->{'Empty fields indicate that the current values are kept'}
        = 'Leere Felder belassen den aktuellen Wert';
    $Lang->{'Array convert to'} = 'Liste konvertiern zu';
    $Lang->{'Array Separator by useing format string'}
        = 'Listentrenner bei Verwendung von Zeichenketten';
    $Lang->{'Semicolon (;)'} = 'Semikolon (;)';
    $Lang->{'Comma (,)'}     = 'Komma (,)';

    $Lang->{'Remove attachment'} = 'Anlage entfernen';
    $Lang->{'Select a file to replace current attachment'} =
        'Dateiauswahl um akt. Anlage zu ersetzen';
    $Lang->{'Invalid content - file size on disk has been changed'} =
        'Ungültiger Inhalt - tatsächliche Dateigröße hat sich geändert';
    $Lang->{'Invalid md5sum - The file might have been changed'} =
        'Ungültige MD5-Summe - Der Dateiinhalt wurde wahrscheinlich geändert';
    $Lang->{'Defines the backend module used for attachment storage.'} =
        'Definiert das Backend-Modul für die Speicherung von Anhängen.';
    $Lang->{'A list of all available CI-attachment storage backends.'} =
        'Eine Liste aller verfügbarer Backends für die Speicherung von CI-Anhängen.';
    $Lang->{
        'Frontend module registration for the CI-AgentAttachmentStorage object in the agent interface.'
        }
        =
        'Frontendmodul-Registration des CI-AgentAttachmentStorage-Objekts im Agent-Interface.';
    $Lang->{
        'The path to the directory where the file system backend stores new attachments. The path needs to be specified relative to the KIX-Home.'
        }
        =
        'Pfad zum Verzeichnis in welchem vom Dateisystemspeichermodul (AttachmentStorageFS) neue Anhänge abgelegt werden. Der Pfad wird relativ zum KIX-Home Verzeichnis angegeben.';

    $Lang->{'Welcome to KIX'}     = 'Willkommen bei KIX';
    $Lang->{'show Toolbar'}       = 'Toolbar anzeigen';
    $Lang->{'hide Toolbar'}       = 'Toolbar ausblenden';
    $Lang->{'Toolbar Position'}   = 'Toolbar-Position';
    $Lang->{'Select the position of the toolbar.'} = 'Position der Toolbar auswählen.';
    $Lang->{'Defines for the Toolbar Top a specific CSS for adjusting the position. It is only possible to use the CSS rules Left and Top.'}
        = 'Definiert für die Toolbar Top eine spezifische CSS zur Anpassung der Position. Es ist nur möglich die CSS-Regeln Left und Top zu verwenden.';
    $Lang->{'Right'}              = 'Rechts';
    $Lang->{'Left'}               = 'Links';
    $Lang->{'Above Menu'}         = 'Oberhalb des Menüs';
    $Lang->{'Search Template 01'} = 'Suchvorlage 01';
    $Lang->{'Search Template 02'} = 'Suchvorlage 02';
    $Lang->{'Search Template 03'} = 'Suchvorlage 03';
    $Lang->{'Search Template 04'} = 'Suchvorlage 04';
    $Lang->{'Search Template 05'} = 'Suchvorlage 05';
    $Lang->{'Search Template 06'} = 'Suchvorlage 06';
    $Lang->{'Search Template 07'} = 'Suchvorlage 07';
    $Lang->{'Search Template 08'} = 'Suchvorlage 08';
    $Lang->{'Search Template 09'} = 'Suchvorlage 09';
    $Lang->{'Search Template 10'} = 'Suchvorlage 10';
    $Lang->{'Stats'}              = 'Statistik';
    $Lang->{'KIX runs with a huge lists of browsers, please upgrade to one of these.'}
        = 'KIX funktioniert mit einer großen Auswahl an Browsern, aus denen Sie wählen können. Bitte installieren Sie einen neueren Browser oder upgraden Sie Ihren vorhandenen.';
    $Lang->{'In order to experience KIX, you\'ll need to enable JavaScript in your browser.'}
        = 'Um alle Möglichkeiten von KIX voll ausschöpfen zu können, müssen Sie JavaScript in Ihrem Browser aktivieren.';
    $Lang->{'New ticket'}        = 'Neues Ticket';
    $Lang->{'Create new ticket'} = 'Neues Ticket erstellen';
    $Lang->{'History of'}        = 'Historie von';
    $Lang->{'Print Standard'}    = 'PDF-Ausdruck';
    $Lang->{'Print Richtext'}    = 'HTML-Ausdruck';
    $Lang->{'ascending'}         = 'aufsteigend';
    $Lang->{'descending'}        = 'absteigend';
    $Lang->{'CustomerUserID'}    = 'KundennutzerID';
    $Lang->{'Defines whether the service is translated in the selection box and ticket overviews (except in the admin area).'}
        = 'Definiert, ob der Service in der Auswahlbox und Ticketübersichten übersetzt wird (ausgenommen im Adminbereich).';
    $Lang->{'Defines whether the sla is translated in the selection box and ticket overviews (except in the admin area).'}
        = 'Definiert, ob der SLA in der Auswahlbox und Ticketübersichten übersetzt wird (ausgenommen im Adminbereich).';

    $Lang->{'Alternative to'}        = 'Alternativ zu';
    $Lang->{'Availability'}          = 'Verfügbarkeit';
    $Lang->{'Back End'}              = 'Backend';
    $Lang->{'Connected to'}          = 'Verbunden mit';
    $Lang->{'Current State'}         = 'Aktueller Status';
    $Lang->{'Demonstration'}         = 'Demonstration';
    $Lang->{'Depends on'}            = 'Hängt ab von';
    $Lang->{'End User Service'}      = 'Anwender-Service';
    $Lang->{'Errors'}                = 'Fehler';
    $Lang->{'Front End'}             = 'Frontend';
    $Lang->{'IT Management'}         = 'IT Management';
    $Lang->{'IT Operational'}        = 'IT Betrieb';
    $Lang->{'Impact'}                = 'Auswirkung';
    $Lang->{'Incident State'}        = 'Vorfallsstatus';
    $Lang->{'Includes'}              = 'Beinhaltet';
    $Lang->{'Other'}                 = 'Sonstiges';
    $Lang->{'Part of'}               = 'Teil von';
    $Lang->{'Project'}               = 'Projekt';
    $Lang->{'Recovery Time'}         = 'Wiederherstellungszeit';
    $Lang->{'Relevant to'}           = 'Relevant für';
    $Lang->{'Reporting'}             = 'Reporting';
    $Lang->{'Required for'}          = 'Benötigt für';
    $Lang->{'Resolution Rate'}       = 'Lösungszeit';
    $Lang->{'Response Time'}         = 'Reaktionszeit';
    $Lang->{'SLA Overview'}          = 'SLA-Übersicht';
    $Lang->{'Service Overview'}      = 'Dienstübersicht';
    $Lang->{'Service-Area'}          = 'Service-Bereich';
    $Lang->{'Training'}              = 'Training';
    $Lang->{'Transactions'}          = 'Transaktionen';
    $Lang->{'Underpinning Contract'} = 'Underpinning Contract';
    $Lang->{'allocation'}            = 'zuordnen';

    # Template: AdminITSMCIPAllocate
    $Lang->{'Criticality <-> Impact <-> Priority'} = 'Kritikalität <-> Auswirkung <-> Priorität';
    $Lang->{'Manage the priority result of combinating Criticality <-> Impact.'} =
        'Verwaltung der Priorität aus der Kombination von Kritikalität <-> Impact.';
    $Lang->{'Priority allocation'} = 'Priorität zuordnen';

    # Template: AdminSLA
    $Lang->{'Minimum Time Between Incidents'} = 'Mindestzeit zwischen Incidents';

    # Template: AdminService
    $Lang->{'Criticality'} = 'Kritikalität';

    # Template: AgentITSMSLAZoom
    $Lang->{'SLA Information'}     = 'SLA-Informationen';
    $Lang->{'Last changed'}        = 'Zuletzt geändert';
    $Lang->{'Last changed by'}     = 'Zuletzt geändert von';
    $Lang->{'Associated Services'} = 'Zugehörige Services';

    # Template: AgentITSMServiceZoom
    $Lang->{'Service Information'}    = 'Service-Informationen';
    $Lang->{'Current incident state'} = 'Aktueller Vorfallstatus';
    $Lang->{'Associated SLAs'}        = 'Zugehörige SLAs';

    # Perl Module: Kernel/Modules/AgentITSMServicePrint.pm
    $Lang->{'Current Incident State'} = 'Aktueller Vorfallsstatus';

    # SysConfig
    $Lang->{'Both'} = '';
    $Lang->{
        'Frontend module registration for the AdminITSMCIPAllocate configuration in the admin area.'
        }
        =
        '';
    $Lang->{'Frontend module registration for the AgentITSMSLA object in the agent interface.'} =
        '';
    $Lang->{'Frontend module registration for the AgentITSMSLAPrint object in the agent interface.'}
        =
        '';
    $Lang->{'Frontend module registration for the AgentITSMSLAZoom object in the agent interface.'}
        =
        '';
    $Lang->{'Frontend module registration for the AgentITSMService object in the agent interface.'}
        =
        '';
    $Lang->{
        'Frontend module registration for the AgentITSMServicePrint object in the agent interface.'}
        =
        '';
    $Lang->{
        'Frontend module registration for the AgentITSMServiceZoom object in the agent interface.'}
        =
        '';
    $Lang->{'ITSM SLA Overview.'}                                         = '';
    $Lang->{'ITSM Service Overview.'}                                     = '';
    $Lang->{'Incident'}                                                   = '';
    $Lang->{'Incident State Type'}                                        = 'Vorfallsstatus-Typ';
    $Lang->{'Manage priority matrix.'}                                    = '';
    $Lang->{'Module to show back link in service menu.'}                  = '';
    $Lang->{'Module to show back link in sla menu.'}                      = '';
    $Lang->{'Module to show print link in service menu.'}                 = '';
    $Lang->{'Module to show print link in sla menu.'}                     = '';
    $Lang->{'Module to show the link link in service menu.'}              = '';
    $Lang->{'Operational'}                                                = '';
    $Lang->{'Parameters for the incident states in the preference view.'} = '';
    $Lang->{'SLA Print.'}                                                 = '';
    $Lang->{'SLA Zoom.'}                                                  = '';
    $Lang->{'Service Print.'}                                             = '';
    $Lang->{'Service Zoom.'}                                              = '';
    $Lang->{
        'Set the type and direction of links to be used to calculate the incident state. The key is the name of the link type (as defined in LinkObject::Type), and the value is the direction of the IncidentLinkType that should be followed to calculate the incident state. For example if the IncidentLinkType is set to "DependsOn", and the Direction is "Source"", only "Depends on" links will be followed (and not the opposite link "Required for") to calculate the incident state. You can add more link types and directions as you like, e.g. "Includes" with the direction "Target". All link types defined in the sysconfig options LinkObject::Type are possible and the direction can be "Source", "Target", or "Both". IMPORTANT: AFTER YOU MAKE CHANGES TO THIS SYSCONFIG OPTION YOU NEED TO RUN THE SCRIPT kix.Console.pl Admin::ITSM::IncidentState::Recalculate SO THAT ALL INCIDENT STATES WILL BE RECALCULATED BASED ON THE NEW SETTINGS!'
        }
        =
        'Setzt den Typ und die Richtung von Verknüpfungen, die genutzt werden, um den Vorfallsstatus zu berechnen. Der Schlüssel ist der Name des Verknüpfungstyps (so wie er in LinkObject::Type festgelegt wurde), und der Wert ist die Richtung des IncidentLinkType, welchem gefolgt werden soll, wenn der Vorfallsstatus berechnet wird. Wenn zum Beispiel der IncidentLinkType auf "Hängt ab von" gesetzt wird, und die Richtung ist "Source", wird nur "Hängt ab von" Verknüpfungen gefolgt (und nicht dem zugehörigen gegensätzlichen Verknüpfungstyp "Benötigt für"). Sie können weitere Verknüpfungstypen und Richtungen ergänzen, z.B. "Beinhaltet" mit der Richtung "Target". Alle Verknüpfungstypen, welche in der SysConfig Option LinkObject::Type festgelegt sind, können verwendet werden. Richtungen sind "Source", "Target", oder "Both". Achtung! Sobald Änderungen an diesem Schlüssel gemacht wurden, muss das Script kix.Console.pl Admin::ITSM::IncidentState::Recalculate ausgeführt werden, so dass alle Vorfallsstatus basierend auf den neuen Einstellungen neu berechnet werden.';
    $Lang->{
        'This setting defines that a \'ITSMChange\' object can be linked with \'Ticket\' objects using the \'Normal\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'ITSMConfigItem\' object can be linked with \'FAQ\' objects using the \'Normal\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'ITSMConfigItem\' object can be linked with \'FAQ\' objects using the \'ParentChild\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'ITSMConfigItem\' object can be linked with \'FAQ\' objects using the \'RelevantTo\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'ITSMConfigItem\' object can be linked with \'Service\' objects using the \'AlternativeTo\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'ITSMConfigItem\' object can be linked with \'Service\' objects using the \'DependsOn\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'ITSMConfigItem\' object can be linked with \'Service\' objects using the \'RelevantTo\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'ITSMConfigItem\' object can be linked with \'Ticket\' objects using the \'AlternativeTo\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'ITSMConfigItem\' object can be linked with \'Ticket\' objects using the \'DependsOn\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'ITSMConfigItem\' object can be linked with \'Ticket\' objects using the \'RelevantTo\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'ITSMConfigItem\' object can be linked with other \'ITSMConfigItem\' objects using the \'AlternativeTo\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'ITSMConfigItem\' object can be linked with other \'ITSMConfigItem\' objects using the \'ConnectedTo\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'ITSMConfigItem\' object can be linked with other \'ITSMConfigItem\' objects using the \'DependsOn\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'ITSMConfigItem\' object can be linked with other \'ITSMConfigItem\' objects using the \'Includes\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'ITSMConfigItem\' object can be linked with other \'ITSMConfigItem\' objects using the \'RelevantTo\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'ITSMWorkOrder\' object can be linked with \'ITSMConfigItem\' objects using the \'DependsOn\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'ITSMWorkOrder\' object can be linked with \'ITSMConfigItem\' objects using the \'Normal\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'ITSMWorkOrder\' object can be linked with \'Service\' objects using the \'DependsOn\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'ITSMWorkOrder\' object can be linked with \'Service\' objects using the \'Normal\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'ITSMWorkOrder\' object can be linked with \'Ticket\' objects using the \'Normal\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'Service\' object can be linked with \'FAQ\' objects using the \'Normal\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'Service\' object can be linked with \'FAQ\' objects using the \'ParentChild\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines that a \'Service\' object can be linked with \'FAQ\' objects using the \'RelevantTo\' link type.'
        }
        =
        '';
    $Lang->{
        'This setting defines the link type \'AlternativeTo\'. If the source name and the target name contain the same value, the resulting link is a non-directional one. If the values are different, the resulting link is a directional link.'
        }
        =
        '';
    $Lang->{
        'This setting defines the link type \'ConnectedTo\'. If the source name and the target name contain the same value, the resulting link is a non-directional one. If the values are different, the resulting link is a directional link.'
        }
        =
        '';
    $Lang->{
        'This setting defines the link type \'DependsOn\'. If the source name and the target name contain the same value, the resulting link is a non-directional one. If the values are different, the resulting link is a directional link.'
        }
        =
        '';
    $Lang->{
        'This setting defines the link type \'Includes\'. If the source name and the target name contain the same value, the resulting link is a non-directional one. If the values are different, the resulting link is a directional link.'
        }
        =
        '';
    $Lang->{
        'This setting defines the link type \'RelevantTo\'. If the source name and the target name contain the same value, the resulting link is a non-directional one. If the values are different, the resulting link is a directional link.'
        }
        =
        '';
    $Lang->{'Width of ITSM textareas.'} = '';

    $Lang->{'Call contact'}         = 'Telefonanruf-Kontakt';
    $Lang->{'Call contacts'}        = 'Telefonanruf-Kontakte';
    $Lang->{'As call contact'}      = 'Als Telefonanrufs-Kontakt festlegen';
    $Lang->{'As article recipient'} = 'Als Artikel-Empfänger festlegen';
    $Lang->{'Remove call contact'}  = 'Telefonanruf-Kontakt entfernen';
    $Lang->{'Set this person as call contact.'} = 'Diese Person als Telefonanruf-Kontakt festlegen.';
    $Lang->{'Defines for which actions the linked persons could be set as call contacts.'}
        = 'Legt fest, für welche Actions die verlinkten Personen als Telefonanruf-Kontakte festlegbar sind.';
    $Lang->{'Dynamic field which is used to save the call contact information.'}
        = 'Dynamisches Feld, welches verwendet wird, um die Telefonanruf-Kontakte zu sichern.';
    $Lang->{'Defines if the call contact could be set in the ticket phone outbound screen of the agent interface.'}
        = 'Bestimmt, ob Telefonanruf-Kontakte im Dialog "Ausgehender Telefonanruf" im Agenten-Frontend gesetzt werden können.';
    $Lang->{'Defines if the call contact could be set in the ticket phone inbound screen of the agent interface.'}
        = 'Bestimmt, ob Telefonanruf-Kontakte im Dialog "Eingehender Telefonanruf" im Agenten-Frontend gesetzt werden können.';

    $Lang->{'Mark notification as seen'}
        = 'Benachrichtigung als gesehen markieren';
    $Lang->{'The new email notification article to customers will already be marked as seen for agents.'}
        = 'Der neue E-Mail-Benachrichtigungs-Artikel an Kunden wird für Agenten schon als gesehen markiert.';

    $Lang->{'Event to clear all ttl entries if all dynamic field entries are deleted.'}
          = 'Event um alle TTL-Einträge zu löschen, wenn alle Einträge eines DynamicFields gelöscht werden.';
    $Lang->{'Event to clear the ttl entry if dynamic field entry for an object is deleted.'}
          = 'Event um relevante TTL-Einträge zu löschen, wenn ein Eintrag eines DynamicField gelöscht wird.';
    $Lang->{'Set ttl entry if dynamic field entry for an object is set.'}
          = 'Erstellt den relevanten TTL-Eintrag beim hinzufügen eines DynamicField Eintrages.';
    $Lang->{'Update all existing ttl entries if dynamic field is updated.'}
          = 'Aktualisiert alle bestehenden TTL-Einträge, wenn ein DynamicField aktualisiert wird.';
    $Lang->{'Delete expired dynamic field values.'}
          = 'Löscht abgelaufene Einträge von DynamicFields.';

    # DF Value TTL
    $Lang->{'Years'}              = 'Jahre';
    $Lang->{'Time to live (TTL)'} = 'Wert-Lebenszeit (TTL)';
    $Lang->{'This is the time a value is stored before it expires. Use 0 to deactivate expiration.'}
          = 'Das ist die Zeit für einen Wert bevor dieser ungültig wird. Verwende 0 um den Verfall zu deaktivieren.';

    # Generic Agent
    $Lang->{'Warning: Delete/Empty a ticket attribute or dynamic field has a higher priority than update/add.'}
        = 'Warnung: Löschen/Leeren eines Ticket-Attributs oder dynamischen Feldes hat eine höhere Priorität als Aktualisieren/Hinzufügen.';
    $Lang->{'Delete/Empty Ticket Attributes'} = 'Ticket-Attribute löschen/leeren';
    $Lang->{'Ticket Attributes'}              = 'Ticket-Attribute';
    $Lang->{'Clone Job'}                      = 'Job kopieren';
    $Lang->{'The following tags can be used in the subject and body'}
        = 'Die folgenden Platzhalter können in Betreff und Nachrichtentext verwendet werden';

    # Quick State
    $Lang->{'QuickState'}             = 'Statuswechsel';
    $Lang->{'Quick State'}            = 'Statuswechsel';
    $Lang->{'Quick State Management'} = 'Statuswechsel Verwaltung';
    $Lang->{'Add Quick State'}        = 'Statuswechsel hinzufügen';
    $Lang->{'Quick States per page'}  = 'Statuswechsel pro Seite';
    $Lang->{'Import Quick State'}     = 'Statuswechsel importieren';
    $Lang->{'Quick State deleted!'}   = 'Statuswechsel wurde gelöscht!';
    $Lang->{'Quick State added!'}     = 'Statuswechsel wurde hinzugefügt!';
    $Lang->{'Quick State updated!'}   = 'Statuswechsel wurde aktualisiert!';
    $Lang->{'Quick State imported!'}  = 'Statuswechsel wurde importiert!';
    $Lang->{'Pending time in the future'}     = 'Wartezeit in der Zukunft';
    $Lang->{'Quick State Overview Limit'}     = 'Übersichtsbegrenzung der Statuswechsel';
    $Lang->{'Quick state limit per page for overview.'}   = 'Übersichtsbegrenzung pro Seite der Statuswechsel.';
    $Lang->{'Quick State already exists! (Overwrite not used)'}
        = 'Statuswechsel existiert bereits! (Überscheiben nicht verwendet)';
    $Lang->{'Here you can upload a configuration file to import a Quick State to your system. The file needs to be in .yml format as exported by this module.'}
        = 'Hier können Sie eine Konfigurationdatei hochladen, um einen Statuswechsel in Ihr System zu importieren. Die Datei muss im YAML-Format vorliegen, so wie sie vom Statuswechsel auch exportiert wird. ';
    $Lang->{'Sorry, the quick state \'%s\' couldn\'t use. The current Ticket has the same state as the selected quick state or the quick state is invalid!'}
        = 'Leider konnte der Statuswechsel \'%s\' nicht verwendet werden. Das aktuelle Ticket hat entweder den gleichen Status wie der ausgewählte Statuswechsel oder der Statuswechsel ist ungültig!';
    $Lang->{'Please use a another quick state or contact the administrator.'}
        = 'Bitte verwenden Sie einen anderen Statuswechsel oder wenden Sie sich an einen Administrator.';
    $Lang->{'The specified time is added to the current time when using a quick status with a pending state. (Default: 1 Day)'}
        = 'Die angegebene Zeit wird bei Verwendung eines Statuswechsels mit einem Wartestatus auf die aktuelle Zeit addiert. (Standard: 1 Tag)';
    $Lang->{'Use 0 if no adjustment of the pending time is required.'}
        = 'Verwenden Sie 0, wenn keine Anpassung der Wartezeit erforderlich ist.';
    $Lang->{'Frontend module registration for the quick state in the admin interface.'}
        = 'Frontend-Modulregistrierung für den Statuswechsel in der Admin-Oberfläche.';
    $Lang->{'Defines the default article type of new quick state.'}
        = 'Definiert den Standard-Artikeltyp für den neuen Statuswechsel.';
    $Lang->{'Create and manage quick states.'}
        = 'Statuswechsel erzeugen und verwalten.';
    $Lang->{'Please contact the administrator.'}
        = 'Wenden Sie sich bitte an einen Administrator.';
    $Lang->{'The status couldn\'t be changed with the quick state \'%s\'!'}
        = 'Der Status konnte mit dem gewähltem Statuswechsel \'%s\' nicht geändert werden!';
    $Lang->{'It could not be created the corresponding article to the quick state \'%s\'!'}
        = 'Es konnte nicht der entsprechende Artikel zum Statuswechsel \'%s\' erstellt werden!';
    $Lang->{'A quick state with this name already exists!'}
        = 'Ein Statuswechsel mit diesem Namen existiert bereits!';

    # System Message
    $Lang->{'Defined modules in the blacklist are not displayed in the selection.'}
        = 'Definierte Module in der Blacklist werden nicht in der Auswahl angezeigt.';
    $Lang->{'Defines a restricted list of modules.'}
        = 'Definiert eine eingeschränkte Modulliste.';
    $Lang->{'Dis-/enables displaying the short text of a message entry.'}
        = 'De-/aktiviert die Anzeige des Kurztextes eines Neuigkeiten Eintrages.';
    $Lang->{'Dis-/enables displaying the author of a message entry.'}
        = 'De-/aktiviert die Anzeige des Autor eines Neuigkeiten Eintrages.';
    $Lang->{'Open message when user visits template.'}     = 'Neuigkeit öffnen wenn Anwender den Bereich öffnen.';
    $Lang->{'Template has to be selected at \'Display\'.'} = 'Bereich muss bei \'Anzeige\' ausgewählt sein.';
    $Lang->{'Create and manage messages.'}                 = 'Erstellt und verwaltet Neuigkeiten.';
    $Lang->{'Message Overview Limit'}                      = 'Übersichtsbegrenzung der Neuigkeiten';
    $Lang->{'Message limit per page for overview.'}        = 'Übersichtsbegrenzung pro Seite der Neuigkeiten.';

    $Lang->{'Messages per page'}    = 'Neuigkeiten pro Seite';
    $Lang->{'Mark as read'}         = 'Als gelesen markieren';
    $Lang->{'Invalidation date'}    = 'Neuigkeit gültig bis';
    $Lang->{'Validation date'}      = 'Neuigkeit gültig ab';
    $Lang->{'Teaser'}               = 'Kurztext';
    $Lang->{'Headline'}             = 'Überschrift';
    $Lang->{'Add Message'}          = 'Neuigkeit hinzufügen';
    $Lang->{'Messages Management'}  = 'Neuigkeiten Verwaltung';
    $Lang->{'Short Text'}           = 'Kurztext';
    $Lang->{'Valitiy'}              = 'Gültigkeit';
    $Lang->{'Valid From'}           = 'Gültig ab';
    $Lang->{'Valid To'}             = 'Gültig bis';
    $Lang->{'Author'}               = 'Autor';
    $Lang->{'Message added!'}       = 'Neuigkeit hinzugefügt!';
    $Lang->{'Message updated!'}     = 'Neuigkeit aktualisiert!';
    $Lang->{'Message deleted!'}     = 'Neuigkeit gelöscht!';
    $Lang->{'Read this message'}    = 'Diese Neuigkeit lesen';
    $Lang->{'Messages'}             = 'Neuigkeiten';

    $Lang->{'Display templates'} = 'Anzeige-Bereiche';
    $Lang->{'Popup templates'}   = 'Popup-Bereiche';

    $Lang->{'Show already read messages'} = 'Zeige gelesene Neuigkeiten';

    # CUSTOM FOOTER
    $Lang->{'Defines a link list that can be added in the footer. The links can be assigned separately to the frontends. (Key: <priority>::<link title>; Value: 0 => deactivated, 1 => show everywhere, 2 => only agent frontend, 3 => only customer frontend)'}
        = 'Definiert eine Liste von Links, welche im Footer zusätzlich hinzugefügt werden können. Die Links können den Frontends separat zugewiesen werden. (Schlüssel: <Priorität>::<Linktitel>; Wert: 0 => deaktiviert, 1 => Überall anzeigen, 2 => nur Agentenfrontend, 3 => nur Kundenfrontend)';
    $Lang->{'Defines the associated URL for each link title. It is possible to use KIX placeholder.'}
        = 'Definiert zu den jeweiligen Linktitel die dazugehörige URL. Es ist möglich KIX-Platzhalter zu verwenden.';
    $Lang->{'Defines the target-attribute for each link title.'}
        = 'Definiert zu den jeweiligen Linktitel das zu verwendende target-Attribut.';

    # GEOCOORDINATES
    $Lang->{'Decimal Degree'} = 'Dezimalgrad';
    $Lang->{'Degree'}         = 'Grad';
    $Lang->{'Defines a fallback input format for the form if the format is not set in the config item attribute definition.'}
        = 'Definiert ein Fallback-Eingabeformat für das Formular, wenn das Format nicht in der Attributdefinition des Konfigurationselements festgelegt ist.';
    $Lang->{'Defines a fallback export format for the csv export if the format is not set in the config item attribute definition.'}
        = 'Definiert ein Fallback-Exportformat für den CSV-Export, wenn das Format nicht in der Attributdefinition des Konfigurationselements festgelegt ist.';
    $Lang->{'Defines a fallback display format for the view if the format is not set in the config item attribute definition.'}
        = 'Definiert ein Fallback-Anzeigeformat für die Ansicht, wenn das Format nicht in der Attributdefinition des Konfigurationselements festgelegt ist.';
    $Lang->{'Defines a fallback link for the view if the link is not set in the attribute definition of the configuration item. It is possible to use two placeholders to set latitude and longitude. (<LATITUDE>, <LONGITUDE>)'}
        = 'Definiert einen Fallback-Link für die Ansicht, wenn der Link nicht in der Attributdefinition des Konfigurationselements festgelegt ist. Es ist möglich, zwei Platzhalter zum Festlegen von Breiten- und Längegrad zu verwenden. (<LATITUDE>, <LONGITUDE>)';

    # NEW SKINS
    $Lang->{'Default (green)'} = 'Standard (Grün)';
    $Lang->{'Default (blue)'}  = 'Standard (Blau)';
    $Lang->{'This skin changes the color of the standard skin to "Blue" for the customer interface.'} =
        'Dieser Skin ändert die Farbe des Standard Skin in "Blau" für das Kundeninterface.';
    $Lang->{'This skin changes the color of the standard skin to "Blue" for the agent interface.'} =
        'Dieser Skin ändert die Farbe des Standard Skin in "Blau" für das Agenteninterface.';
    $Lang->{'This skin changes the color of the standard skin to "Dark" for the agent interface.'} =
        'Dieser Skin ändert die Farbe des Standard Skin in "Dark" für das Agenteninterface.';
    $Lang->{'Default skin for the agent interface (blue version).'} =
         'Standard-Skin für die Agentenoberfläche (Blau)';
    $Lang->{'Default skin for the customer interface (blue version).'} =
         'Standard-Skin für die Kundenoberfläche (Blau)';

    # OpenSearch
    $Lang->{'"OpenSearch" profiles.'} =
        '"OpenSearch" Profile.';
    $Lang->{'Module to provide html "OpenSearch" profiles for agent frontend.'} =
        'Modul zur Bereitstellung des HTML "OpenSearch" Profils in der Agentenoberfläche.';
    $Lang->{'Module to generate html OpenSearch profiles for customer frontend.'} =
        'Modul zur Bereitstellung des HTML "OpenSearch" Profils in der Kundenoberfläche.';
    $Lang->{'Module to generate html OpenSearch profiles for public frontend.'} =
        'Modul zur Bereitstellung des HTML "OpenSearch" Profils in der öffentlichen Oberfläche.';

    # OwnerView
    $Lang->{'Agent interface notification module to see the number of tickets an agent is owner for.'}
        = 'Benachrichtigungsmodul im Agenten-Interface um die Zahl der Tickets anzuzeigen, für die ein Agent Besitzer ist.';
    $Lang->{'My Owner Tickets'}               = 'Meine eigenen Tickets';
    $Lang->{'Owner Tickets'}                  = 'Eigene Tickets';
    $Lang->{'Owner Tickets New'}              = 'Neue eigene Tickets';
    $Lang->{'Owner Tickets Reminder Reached'} = 'Eigene Tickets, Erinnerungszeit erreicht';
    $Lang->{'Owner Tickets Total'}            = 'Eigene Tickets insgesamt';

    $Lang->{'Defines the default ticket attribute for ticket sorting in the owner view of the agent interface.'}
        = 'Bestimmt das Standard-Ticket-Attribut für das Sortieren der Tickets in der Besitzer-Anzeige im Agent-Interface.';
    $Lang->{'Defines the default ticket order in the owner view of the agent interface. Up: oldest on top. Down: latest on top.'}
        = 'Bestimmt die Standard-Ticket-Sortierung in der Besitzer-Anzeige im Agent-Interface. Hoch: Ältestes oben. Runter: Letztes/Neustes oben.';
    $Lang->{'Columns that can be filtered in the owner view of the agent interface. Possible settings: 0 = Disabled, 1 = Available, 2 = Enabled by default. Note: Only Ticket attributes and Dynamic Fields (DynamicField_NameX) are allowed.'}
        = 'Spalten, die in der Besitzer-Ansicht im Agenten-Interface gefiltert werden können. Mögliche Einstellungen: 0 = Deaktiviert, 1 = vorhanden, 2 = standardmäßig aktiviert. Hinweis: Nur Ticket-Attribute und Dynamic Fields (DynamicField_NameX) sind erlaubt.';

    # Secure login
    $Lang->{'If enabled, autocomplete will be disabled for agent frontend login.'}
        = 'Wenn aktiviert, wird Autovervollständigung für das Agentenlogin deaktivert. ';
    $Lang->{'If enabled, autocomplete will be disabled for customer frontend login.'}
        = 'Wenn aktiviert, wird Autovervollständigung für das Kundenlogin deaktivert.';

    # SupportBundle Obfuscation
    $Lang->{'Defines obfuscation pattern for support bundle generation. Keys are search pattern. Values are replacement pattern. The global modification is always set.'}
        = 'Definiert die Verschleierung für die Support-Bundle -Erzeugung. Schlüssel sind Suchpattern. Werte sind Ersetzungspattern. Der Global-Modifizierer ist immer gesetzt.';
    # $$STOP$$

    # LoginHeaders
    $Lang->{'Defines the prefix that is placed before the name of the application. This only applies to the "login" and "forgot password" mask.'}
        = 'Definiert den Präfix der vor dem Namen der Anwendung gesetzt wird. Dies gilt nur für die Maske "Login" und "Passwort vergessen".';
    $Lang->{'Defines the prefix that is placed before the name of the application. This only applies to the "login", "forgot password" and "register" mask.'}
        = 'Definiert den Präfix der vor dem Namen der Anwendung gesetzt wird. Dies gilt nur für die Maske "Login", "Passwort vergessen" und "Registieren".';
    $Lang->{'Defines the suffix that is placed after the name of the application. This only applies to the "login" and "forgot password" mask.'}
        = 'Definiert den Suffix der nach dem Namen der Anwendung gesetzt wird. Dies gilt nur für die Maske "Login" und "Passwort vergessen".';
    $Lang->{'Defines the suffix that is placed after the name of the application. This only applies to the "login", "forgot password" and "register" mask.'}
        = 'Definiert den Suffix der nach dem Namen der Anwendung gesetzt wird. Dies gilt nur für die Maske "Login", "Passwort vergessen" und "Registieren".';
    $Lang->{'Defines a subheading which is placed under the main heading. Only applies to the login mask.'}
        = 'Definiert eine Zwischenüberschrift welche unter dem Hauptüberschrift gesetzt wird. Gilt nur für die Maske Login.';
    $Lang->{'Activates the greeting heading in the login.'}
        = 'Aktiviert die Begrüßung Überschrift im Login.';
    $Lang->{'Welcome to'} = 'Willkommen bei';
    # EO LoginHeaders

    # Response Order
    $Lang->{'Select the response format'}     = 'Wählen Sie das Antwortformat';
    $Lang->{'Select response format'}         = 'Antwortformat auswählen';
    $Lang->{'Which response format to use?'}  = 'Welches Antwortformat soll verwendet werden?';
    $Lang->{'Response formats'}               = 'Antwortformate';
    $Lang->{'System configuration'}           = 'Systemkonfiguration';
    $Lang->{'Quote before response template'} = 'Zitat vor Antwortvorlage';
    $Lang->{'Quote after response template'}  = 'Zitat nach Antwortvorlage';
    # EO Response Order

    # BulkTextModules
    $Lang->{'Focused on'} = 'Fokussiert auf';
    $Lang->{'Parameters for the KIXSidebar backend BulkTextModules.'}
        = 'Parameter für das KIXSidebar-Backend BulkTextModules.';
    $Lang->{'Frontend module registration for the BulkTextModuleAJAXHandler object.'}
        = 'Frontendmodul-Registration des Moduls BulkTextModuleAJAXHandler.';
    $Lang->{'Defines a list of allowed placeholders that must be replaced with information. The placeholders entered must be specified without "<KIX_" or "<OTRS_" and ">" (these are added automatically). It is also possible to use a regular expression as a placeholder (example: TICKET_.*). (Key: priority; value: placeholder)'}
        = 'Legt eine Liste mit zulässigen Platzhaltern fest, die mit Informationen ersetzt werden dürfen. Die eingetragenen Platzhalter müssen ohne "<KIX_" oder "<OTRS_" und ">" angegeben werden (diese werden automatisch ergänzt). Es ist möglich auch ein regulären Ausdruck als Platzhalter anzuwenden (Beispiel: TICKET_.*). (Schlüssel: Priorität; Wert: Platzhalter) ';

    # TicketZoom Browsertitle
    $Lang->{'Defines the browser title of the ticket zoom. It is possible to use KIX placeholder.'}
        = 'Definiert den Browsertitel der Ticketansicht. Es ist möglich KIX-Platzhalter zu verwenden.';

    # PreSort/PreOrder
    $Lang->{'Pre-Sort by'}              = 'Vorsortieren nach';
    $Lang->{'Direction of pre-sorting'} = 'Sortierrichtung der Vorsortierung';

    # Date / Time
    $Lang->{'Adds module to calculate date of maundy thursday.'} = 'Fügt Modul hinzu, um Gründonnerstag zu berechnen.';
    $Lang->{'Adds module to calculate date of good friday.'} = 'Fügt Modul hinzu, um Karfreitagg zu berechnen.';
    $Lang->{'Adds module to calculate date of easter monday.'} = 'Fügt Modul hinzu, um Ostermontag zu berechnen.';
    $Lang->{'Adds module to calculate date of ascension day.'} = 'Fügt Modul hinzu, um Christi Himmelfahrt zu berechnen.';
    $Lang->{'Adds module to calculate date of whit monday.'} = 'Fügt Modul hinzu, um Gründonnerstag zu berechnen.';
    $Lang->{'Adds module to calculate date of corpus christi.'} = 'Fügt Modul hinzu, um Fronleichnam zu berechnen.';
    $Lang->{'Adds module to calculate date of epentance and prayer.'} = 'Fügt Modul hinzu, um Buß- und Bettag zu berechnen.';
    $Lang->{'Adds module to calculate date of feast of corpus christi for the indicated calendar.'} = 'Fügt Modul hinzu, um Fronleichnam zu berechnen für den gewählten Kalender.';
    $Lang->{'Adds module to calculate date of day of repentance and prayer for the indicated calendar.'} = 'Fügt Modul hinzu, um den Buß- und Bettag zu berechnen für den gewählten Kalender.';

    # Admin validity fitler
    $Lang->{'Defines the standard filter for the validity, which initially restricts the AdminUser table.'}
        = 'Legt den Standardfilter für die Gültigkeit fest, der die Tabelle von AdminUser initial einschränkt.';
    $Lang->{'Defines the standard filter for the validity, which initially restricts the AdminQueue table.'}
        = 'Legt den Standardfilter für die Gültigkeit fest, der die Tabelle von AdminQueue initial einschränkt.';
    $Lang->{'Defines the standard filter for the validity, which initially restricts the AdminRole table.'}
        = 'Legt den Standardfilter für die Gültigkeit fest, der die Tabelle von AdminRole initial einschränkt.';
    $Lang->{'Defines the standard filter for the validity, which initially restricts the AdminGroup table.'}
        = 'Legt den Standardfilter für die Gültigkeit fest, der die Tabelle von AdminGroup initial einschränkt.';

    # OAuth2
    $Lang->{'If any of the "OAuth2" mechanisms was selected as SendmailModule, the profile to use for OAuth2 must be specified.'}
        = 'Wenn einer der OAuth2-Mechanismen als SendmailModule ausgewählt wurde, muss hier das OAuth2 Profil angegeben werden.';
    $Lang->{'Could not save state token for authentification!'} = 'State-Tocket konnte für Authentifizierung nicht gespeichert werden!';
    $Lang->{'Could not find profile for provided state!'}       = 'Konnte kein Profil für den übergebenen State finden!';
    $Lang->{'A profile with this name already exists!'}         = 'Ein Profil mit diesem Namen existiert bereits!';
    $Lang->{'Need ID of profile!'}                              = 'Benötige ID eines Profils!';
    $Lang->{'Profile updated!'}                                 = 'Profil aktualisiert!';
    $Lang->{'Profile deleted!'}                                 = 'Profil gelöscht!';
    $Lang->{'Could not get access token!'}                      = 'Konnte keinen Zugriffstoken erhalten!';
    $Lang->{'Profile activated!'}                               = 'Profil aktiviert!';
    $Lang->{'OAuth2 Profile Management'}                        = 'OAuth2-Profilverwaltung';
    $Lang->{'Add OAuth2 profile'}                               = 'OAuth2-Profil hinzufügen';
    $Lang->{'Reauthorization'}                                  = 'Erneut authorisieren';
    $Lang->{'Missing refresh token'}                            = 'Erneuerungstoken fehlt';
    $Lang->{'Reauthorize profile'}                              = 'Profil erneut authorisieren';
    $Lang->{'Delete profile'}                                   = 'Profil löschen';
    $Lang->{'Add OAuth2 Profile'}                               = 'OAuth2-Profil hinzufügen';
    $Lang->{'Edit OAuth2 Profile'}                              = 'OAuth2-Profil bearbeiten';
    $Lang->{'URL Authorization'}                                = 'Authorisierungs-URL';
    $Lang->{'URL Token'}                                        = 'Token-URL';
    $Lang->{'URL Redirect'}                                     = 'Weiterleitungs-URL';
    $Lang->{'Client ID'}                                        = 'Client ID';
    $Lang->{'Client Secret'}                                    = 'Client Secret';
    $Lang->{'Scope'}                                            = 'Scope';
    $Lang->{'OAuth2 Profile'}                                   = 'OAuth2-Profil';
    $Lang->{'OAuth2 Profiles'}                                  = 'OAuth2-Profile';
    $Lang->{'Manage OAuth2 profiles.'}                          = 'OAuth2-Profile verwalten.';

    # DynamicField Import/Export
    $Lang->{'Export DynamicFields'}              = 'Dynamische Felder exportieren';
    $Lang->{'Import DynamicFields'}              = 'Dynamische Felder importieren';
    $Lang->{'Overwrite existing DynamicFields?'} = 'Existierende dynamische Felder überschreiben?';
    $Lang->{'Dynamic fields could not be imported due to an unknown error, please check KIX logs for more information.'}
        = 'Dynamische Felder konnten aufgrund eines unbekannten Fehlers nicht importiert werden, bitte prüfen Sie das KIX-Log für mehr Information.';
    $Lang->{'Here you can upload a configuration file to import DynamicFields to your system. The file needs to be in .yml format as exported by this module.'}
        = 'Hier können Sie eine Konfigurationsdatei hochladen, mit der dynamische Felder ins System importiert werden können. Diese Datei muss im .yml-Format vorliegen, so wie sie von diesem Modul exportiert wird.';
    # EO DynamicField Import/Export

    # Ticket Tab Attachments
    $Lang->{'Article attachments'}      = 'Artikelanlagen';
    $Lang->{'DynamicField attachments'} = 'Anlagen dynamischer Felder';
    $Lang->{'Dynamic fields shown in the AgentTicketZoomTab "Attachments". Possible settings: 0 = Disabled, 1 = Enabled.'}
        = 'Dynamische Felder, welche im Tab "Anlagen" der Agentenoberfläche angezeigt werden. Mögliche Einstellungen: 0 = deaktiviert, 1 = aktiviert.';
    # EO Ticket Tab Attachments

    # Ticket::MergeChecklist
    $Lang->{'Source'} = 'Quelle';
    $Lang->{'Append'} = 'Anfügen';
    $Lang->{'The handling of checklists when merged into the main ticket during a merge operation. "Target" keeps the checklist of the main ticket. "Source" inherits the checklist of the source ticket, but only if the main ticket has no own checklist. "Append" adds entries of the source ticket checklist to the main ticket checklist that not already exist. States of entries are always unchanged.'}
        = 'Handhabung von Checklisten beim Zusammenfassen in ein Hauptticket. "Ziel" behält die Checkliste des Haupttickets. "Quelle" übernimmt die Checkliste des Quelltickets, aber nur wenn keine Checkliste am Hauptticket hinterlegt ist. "Anfügen" fügt Einträge, welche noch nicht in der Checkliste des Haupttickets enthalten sind, ans Ende an. Status der Einträge werden immer unverändert gelassen.';
    # EO Ticket::MergeChecklist

    # GenericInferface LinkObject SysConfig
    $Lang->{'Defines if operations of the linkobject can only be used by an agent in group "admin" with "rw" permission.'}
        = 'Bestimmt ob die Operationen des Link-Objektes nur von einem Agenten der Gruppe "admin" mit "rw"-Berechtigung verwendet werden können.';
    # EO GenericInferface LinkObject SysConfig

    # Richtext browser context menu
    $Lang->{'Use browser context menu'} = 'Kontextmenü des Browser verweden';
    $Lang->{'Select to decide whether richtext or browser context menu should be used. Using the browser context menu, you can for example use its spell checker.'}
        = 'Wählen Sie, ob das Kontextmenü des Browsers im Richtext Editor genutzt werden soll. Wird das Kontextmemü des Browsers verwendet, kann beispielsweise dessen Rechtschreibprüfung genutzt werden.';
    # EO Richtext browser context menu

    # AdminDependingDynamicField field explanation
    $Lang->{'You may not use \'::\' within the name'} = 'Im Namen darf \'::\' nicht verwendet werden';

    # KIX17-726: note for changed field behavior
    $Lang->{'Press ENTER to apply unknown contact.'} = 'ENTER drücken, um unbekannte Kontakte zu übernehmen.';

    return 0;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
