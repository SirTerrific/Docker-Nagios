---
type: configuration
title: Configuration Nagios fournie
description: Contenu et intention des fichiers Nagios d'exemple livrés dans l'overlay — nagios.cfg, cgi.cfg et objets (localhost, commandes, modèles) — et leur lien avec nagiosgraph et le pipe de commandes externes.
tags: [nagios-config, nagios-cfg, cgi-cfg, objects, perfdata]
sources:
  - id: openwiki-source-bb1ebe868e35e9e500714501
    resource: repo://Dockerfile
  - id: openwiki-source-93787893611b8fbd08393144
    resource: repo://overlay/opt/nagios/etc/cgi.cfg
  - id: openwiki-source-e04f6712ad74afeb508903c6
    resource: repo://overlay/opt/nagios/etc/nagios.cfg
  - id: openwiki-source-373d8d99e8c9d958c5a36743
    resource: repo://overlay/opt/nagios/etc/objects/commands.cfg
  - id: openwiki-source-e2e595b8f87d0a41de072e8d
    resource: repo://overlay/opt/nagios/etc/objects/localhost.cfg
  - id: openwiki-source-69961be34500329ae74ec6e2
    resource: repo://overlay/opt/nagios/etc/objects/templates.cfg
generated: { by: "claude-code", at: "2026-10-21T14:42:04.315Z" }
verified:
  - by: openwiki/0.7.2
    at: 2026-10-27T19:16:56.093Z
---

# Configuration Nagios fournie

Le dépôt livre une configuration Nagios d'exemple sous `overlay/opt/nagios/etc/`. Pendant le build, `make install-config` installe d'abord les fichiers d'exemple de Nagios Core. `ADD overlay /` remplace ensuite `nagios.cfg`, `cgi.cfg`, `objects/commands.cfg`, `objects/localhost.cfg` et `objects/templates.cfg`. Les autres fichiers, comme `contacts.cfg`, `timeperiods.cfg` et `resource.cfg`, restent ceux de Nagios Core (voir [Construction de l'image](../architecture/construction-image.md)).

Cette configuration n'est copiée dans `/opt/nagios/etc` que si le volume est vide au démarrage (voir [Démarrage et supervision](../architecture/demarrage-et-supervision.md)). Un volume existant garde sa propre configuration, même après une mise à jour de l'image.

## `nagios.cfg`

| Sujet | Réglage |
|---|---|
| Fichiers d'objets | `commands.cfg`, `contacts.cfg`, `timeperiods.cfg`, `templates.cfg`, `localhost.cfg` sous `/opt/nagios/etc/objects/`. |
| Répertoires chargés en plus | `cfg_dir=/opt/nagios/etc/conf.d` et `cfg_dir=/opt/nagios/etc/monitor`, deux répertoires créés vides au build pour la configuration propre au site. |
| Journal et état | `log_file=/opt/nagios/var/nagios.log`, `status_file=/opt/nagios/var/status.dat`, `use_syslog=1`. |
| Commandes externes | `check_external_commands=1`, pipe `command_file=/opt/nagios/var/rw/nagios.cmd`. C'est par ce pipe que `cmd.cgi` (et NagiosTV) transmettent les commandes. |
| Rétention | `retain_state_information=1`, `state_retention_file=/opt/nagios/var/retention.dat`, `use_retained_program_state=1`, `use_retained_scheduling_info=1`. L'état survit au remplacement du conteneur tant que `var` est un volume. |
| Données de performance | `process_performance_data=1`. Les perfdata des services sont écrites en ajout dans `/opt/nagios/var/perfdata.log`, au format `$LASTSERVICECHECK$\|\|$HOSTNAME$\|\|$SERVICEDESC$\|\|$SERVICEOUTPUT$\|\|$SERVICEPERFDATA$`. Toutes les 10 s, ce fichier est traité par la commande `process-service-perfdata`. |
| Caractères interdits | `illegal_object_name_chars` et `illegal_macro_output_chars` filtrent les noms d'objets et la sortie des macros. |
| Fuseau horaire | Aucune ligne `use_timezone` dans le fichier source. Elle est ajoutée au build à partir de `NAGIOS_TIMEZONE`. |

## `cgi.cfg`

- `use_authentication=1`. L'authentification HTTP Basic d'Apache utilise `htpasswd.users`.
- Seul `nagiosadmin` reçoit les droits `authorized_for_*` (informations système, configuration, commandes système, tous les hôtes et services, et leurs commandes). Si vous changez `NAGIOSADMIN_USER`, il faut aussi modifier ces lignes, sinon le nouvel utilisateur s'authentifie sans avoir aucun droit.
- Les chemins web sont `url_html_path=/nagios` et `physical_html_path=/opt/nagios/share`. Les CGI restent servies sous `/cgi-bin/` via le `ScriptAlias` d'Apache.
- `escape_html_tags=1`, `lock_author_names=1`, `refresh_rate=90`.
- Ce fichier ne contient pas l'option `cgi_cookie_fail_open`, apparue avec Nagios 4.5.13. C'est donc la valeur par défaut de Nagios qui s'applique : la protection CSRF de `cmd.cgi` est active.

## Objets

- **`templates.cfg`** définit les modèles standard de Nagios (`generic-contact`, `generic-host`, `linux-server`, `generic-service`, `local-service`…) et ajoute `graphed-service`. Ce modèle non enregistré renseigne `action_url` avec un lien vers `/cgi-bin/show.cgi` de nagiosgraph et une info-bulle `showgraph.cgi`.
- **`localhost.cfg`** décrit l'hôte `localhost` (modèle `linux-server`) et ses services d'exemple (PING, Root Partition, Current Users, Total Processes, Current Load, …). Chaque service hérite de `local-service,graphed-service` et affiche donc une icône de graphe.
- **`commands.cfg`** reprend les commandes de check standard et définit `process-service-perfdata` avec la ligne de commande `/opt/nagiosgraph/bin/insert.pl`. Le Dockerfile corrige ensuite le chemin de `mail` (`/bin/mail` → `/usr/bin/mail`).

Le traitement des perfdata côté nagiosgraph est décrit dans [Modules complémentaires](../integrations/modules-complementaires.md). Les volumes et variables sont décrits dans [Variables et volumes](variables-et-volumes.md).
