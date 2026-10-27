---
type: runbook
title: Mise à jour des versions
description: Procédure pour monter les versions de Nagios Core et de ses composants dans le Dockerfile sans casser les installations existantes, avec les points de contrôle et les particularités de Nagios 4.5.13/4.5.14.
tags: [upgrade, versions, compatibility, nagios-core, runbook]
verified:
  - by: openwiki/0.7.2
    at: 2026-10-27T18:14:48.411Z
sources:
  - id: openwiki-source-bb1ebe868e35e9e500714501
    resource: repo://Dockerfile
  - id: openwiki-source-b41c1cb9f9c6db7b0c389a2a
    resource: repo://overlay/usr/local/bin/start_nagios
  - id: openwiki-source-23775c3de52f3ab95a13cb8b
    resource: repo://README.md
  - id: openwiki-source-2c4a8dc1cbd9d20dda8911b0
    resource: repo://tests/smoke.sh
generated: { by: "claude-code", at: "2026-10-27T18:14:48.411Z" }
---

# Mise à jour des versions

## Où se trouvent les versions

Toutes les versions des composants sont déclarées dans les `ENV` en tête du `Dockerfile` :

| Variable | Valeur actuelle | Source |
|---|---|---|
| `NAGIOS_BRANCH` | `nagios-4.5.14` | tag de `NagiosEnterprises/nagioscore` |
| `NAGIOS_PLUGINS_BRANCH` | `release-2.5` | tag de `nagios-plugins/nagios-plugins` |
| `NRPE_BRANCH` | `nrpe-4.1.3` | tag de `NagiosEnterprises/nrpe` |
| `NCPA_BRANCH` | `v3.5.0` | tag de `NagiosEnterprises/ncpa` (client uniquement) |
| `NSCA_BRANCH` | `nsca-2.10.3` | tag de `NagiosEnterprises/nsca` |
| `NAGIOSTV_VERSION` | `0.10.0` | release de `chriscareycode/nagiostv-react` |

L'étape NSCA fait son `git checkout` sur `$NSCA_BRANCH`. Elle utilisait auparavant `$NSCA_TAG`, une variable jamais définie : le build compilait alors la branche par défaut au lieu du tag voulu.

Le tableau des versions du `README.md` indique Nagios Core 4.5.14, comme le Dockerfile, mais il n'est pas synchronisé automatiquement. Il faut le modifier en même temps que le Dockerfile.

## Procédure

1. **Vérifier les versions publiées** sur les pages de release ou avec `git ls-remote --tags`. Lire le Changelog et le document UPGRADING de Nagios Core pour chaque version sautée.
2. **Modifier les `ENV`** concernées dans le `Dockerfile` (et le tableau du `README.md`).
3. **Construire l'image** : `docker build -t nagios-fork:<version> .`.
4. **Lancer le test de fumée** sur un conteneur neuf : `bash tests/smoke.sh <conteneur> <version>`. Le workflow CI fait la même chose (voir [Tests et CI](tests-et-ci.md)).
5. **Tester la migration** : démarrer d'abord `jasonrivers/nagios:latest` sur des volumes, le laisser créer son état, puis relancer la nouvelle image sur **les mêmes volumes**. Vérifier ensuite que :
   - `nagios -v` ne signale aucune erreur sur la configuration existante ;
   - `retention.dat` est relu (commentaires et acquittements toujours présents) ;
   - les fichiers des volumes appartiennent toujours à `nagios` et restent écrivables ;
   - les cinq services runit sont en état `run`.

## Règles pour ne pas casser les installations existantes

- **Ne pas modifier l'UID 997 ni le GID 1001** de `nagios`. Ce sont ceux de l'image d'origine, et les fichiers des volumes leur appartiennent (voir [Variables et volumes](../configuration/variables-et-volumes.md)).
- **Ne pas déplacer** `/opt/nagios`, `/opt/nagiosgraph`, ni les chemins des volumes. Les `nagios.cfg` existants les référencent en dur.
- **Ne pas compter sur l'overlay pour livrer une nouvelle option.** `start_nagios` ne copie les exemples que dans un volume vide. Toute nouveauté de configuration doit soit avoir une valeur par défaut acceptable, soit être documentée pour une application manuelle.
- **Garder les fins de ligne LF** sur les scripts de l'overlay (imposé par `.gitattributes`). Un script `run` en CRLF ne démarre pas.
- **Rendre exécutable** tout nouveau script `run` ajouté dans `overlay/etc/sv/` (`chmod +x` dans le Dockerfile).

## Particularités de 4.5.13 et 4.5.14

D'après le Changelog de Nagios Core (consulté lors du passage à 4.5.14, à revérifier) :

- `cmd.cgi` vérifie un jeton CSRF : le cookie `NagFormId` doit correspondre au champ `nagFormId` du formulaire. L'interface standard le gère d'elle-même. En revanche, les scripts qui envoient directement des POST à `cmd.cgi` sans d'abord récupérer le formulaire sont rejetés avec « Invalid or missing CSRF cookie ». L'option `cgi_cookie_fail_open` désactive ce contrôle, au prix de la protection CSRF. Elle n'est pas définie dans le `cgi.cfg` fourni.
- 4.5.14 nettoie les macros de notification et les variables personnalisées. Le texte des notifications peut donc changer quand il contient des caractères spéciaux, en particulier ceux de `illegal_macro_output_chars`.
- Le Changelog n'indique aucun changement du format de configuration ou de rétention par rapport à 4.5.12.

Le test de fumée vérifie les deux comportements de `cmd.cgi` : un POST sans cookie doit être rejeté, et un POST avec un cookie valide doit être accepté puis atteindre Nagios.

## Fork et upstream

Le dépôt est un fork de `JasonRivers/Docker-Nagios` (remote `upstream`), publié sur `SirTerrific/Docker-Nagios` (`origin`). Les montées de version de l'upstream suivent la même convention de commit : « Update to Nagios Core X.Y.Z and related versions ».
