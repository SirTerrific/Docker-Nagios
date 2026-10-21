---
type: configuration
title: Variables d'environnement et volumes
description: Variables d'environnement prises en compte au build ou à l'exécution, volumes persistants, exemple docker-compose, identifiants par défaut, et contraintes pour réutiliser les volumes d'une installation jasonrivers/nagios existante.
tags: [environment, volumes, docker-compose, persistence, compatibility]
verified:
  - by: openwiki/0.7.2
    at: 2026-10-21T14:42:04.315Z
sources:
  - id: openwiki-source-b79fbbd921df689b4bbdc82f
    resource: repo://docker-compose.yml
  - id: openwiki-source-bb1ebe868e35e9e500714501
    resource: repo://Dockerfile
  - id: openwiki-source-7ffc6401f752d4262a7cca07
    resource: repo://overlay/etc/sv/apache/run
  - id: openwiki-source-77b22575a9ddd667291f241e
    resource: repo://overlay/etc/sv/postfix/run
  - id: openwiki-source-23775c3de52f3ab95a13cb8b
    resource: repo://README.md
generated: { by: "claude-code", at: "2026-10-21T14:42:04.315Z" }
---

# Variables d'environnement et volumes

## Variables d'environnement

Toutes les variables sont déclarées par `ENV` dans le `Dockerfile`. Pour savoir si un `-e` passé à `docker run` a un effet, il faut regarder **à quel moment** la variable est lue.

| Variable | Défaut | Lue | Effet |
|---|---|---|---|
| `NAGIOSADMIN_USER` / `NAGIOSADMIN_PASS` | `nagiosadmin` / `nagios` | au démarrage | Crée `htpasswd.users` **seulement s'il n'existe pas**. Les droits CGI restent accordés à `nagiosadmin` dans `cgi.cfg`. |
| `MAIL_RELAY_HOST` | vide | au démarrage (postfix) | Définit `relayhost` dans `main.cf`. |
| `MAIL_INET_PROTOCOLS` | vide | au démarrage (postfix) | Définit `inet_protocols`. |
| `NAGIOS_FQDN` | `nagios.example.com` | build **et** démarrage | Au build : `mailname` de postfix et `ServerName` d'Apache. Au démarrage : `mydestination` et `/etc/mailname`. |
| `NAGIOS_TIMEZONE` | `UTC` | build **et** démarrage | Au build : `use_timezone` ajouté à `nagios.cfg`. Au démarrage : `TZ` d'Apache. Avec un volume `etc` existant, le fuseau de Nagios reste celui écrit dans son `nagios.cfg`. |
| `NAGIOS_HOME`, `NAGIOS_USER`, `NAGIOS_GROUP`, `NAGIOS_CMDUSER`, `NAGIOS_CMDGROUP`, `APACHE_RUN_*` | `/opt/nagios`, `nagios` | build | Chemins et comptes figés dans les binaires compilés. Ne pas les changer à l'exécution. |
| `NAGIOS_BRANCH` … `NAGIOSTV_VERSION` | voir Dockerfile | build | Versions des composants (voir [Mise à jour des versions](../operations/mise-a-jour-versions.md)). |

## Volumes

| Chemin | Contenu |
|---|---|
| `/opt/nagios/etc` | Configuration Nagios, `htpasswd.users`, `nsca.cfg`, `conf.d/`, `monitor/` |
| `/opt/nagios/var` | `status.dat`, `retention.dat`, `nagios.log`, `perfdata.log`, pipe `rw/nagios.cmd` |
| `/opt/nagiosgraph/etc` | Configuration nagiosgraph (`ngshared.pm`, `nagiosgraph.conf`, …) |
| `/opt/nagiosgraph/var` | Bases RRD des graphes |
| `/opt/Custom-Nagios-Plugins` | Plugins propres au site, à référencer explicitement dans la configuration |
| `/var/log/apache2` | Journaux Apache |

Au démarrage, `start_nagios` remplit chacun des quatre premiers volumes avec l'exemple de `/orig` **s'il est vide**. Il ne modifie jamais un volume qui contient déjà des fichiers (voir [Démarrage et supervision](../architecture/demarrage-et-supervision.md)).

Le fichier `docker-compose.yml` montre ce modèle : cinq volumes nommés (`nagiosetc`, `nagiosvar`, `customplugins`, `nagiosgraphvar`, `nagiosgraphetc`) sur l'image `jasonrivers/nagios:latest`. Ce fichier utilise l'ancienne clé `version: '3'` et ne déclare aucun port.

## Compatibilité avec les volumes existants

Le fork est conçu pour remplacer l'image `jasonrivers/nagios` sur les mêmes volumes, sans migration :

- **UID et GID.** L'utilisateur `nagios` est créé avec l'UID 997 et le groupe `nagios` avec le GID 1001, comme dans l'image d'origine. Si ces identifiants changeaient, les fichiers des volumes existants, comme `retention.dat` et `htpasswd.users`, appartiendraient à un utilisateur inconnu, et Nagios ne pourrait plus les écrire.
- **Chemins.** Les chemins des volumes et de la configuration (`/opt/nagios`, `/opt/nagiosgraph`) sont inchangés. Un `nagios.cfg` existant continue de pointer vers les bons fichiers.
- **Configuration préservée.** Une nouvelle image n'écrase ni `nagios.cfg`, ni `cgi.cfg`, ni les objets d'un volume existant. En contrepartie, les nouveautés des fichiers d'exemple ne sont pas propagées : il faut les reporter à la main si on en a besoin.

## Identifiants par défaut

L'interface web est accessible sur `/nagios/` avec `nagiosadmin` / `nagios`. **Changez ce mot de passe** sur toute instance exposée : modifiez `htpasswd.users` dans le volume, ou bien fournissez `NAGIOSADMIN_PASS` au tout premier démarrage.
