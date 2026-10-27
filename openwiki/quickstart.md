---
type: overview
title: Démarrage rapide
description: Point d'entrée du wiki Docker-Nagios — ce que produit le dépôt, organisation des fichiers, commandes de base et page à consulter pour chaque tâche courante.
tags: [overview, quickstart, docker, nagios]
sources:
  - id: openwiki-source-79b37831c9c81206da1d88ec
    resource: repo://.github/dependabot.yml
  - id: openwiki-source-7a80b79a6fb3618cbfab08a2
    resource: repo://.github/workflows/build.yml
  - id: openwiki-source-bb1ebe868e35e9e500714501
    resource: repo://Dockerfile
  - id: openwiki-source-3a44815832a872f4778f822b
    resource: repo://SECURITY.md
  - id: openwiki-source-2c4a8dc1cbd9d20dda8911b0
    resource: repo://tests/smoke.sh
generated: { by: "claude-code", at: "2026-10-27T18:14:48.411Z" }
verified:
  - by: openwiki/0.7.2
    at: 2026-10-27T18:14:48.411Z
---

# Démarrage rapide

Ce dépôt produit une **image Docker de Nagios Core** sur Ubuntu 24.04. L'image contient Nagios Plugins, nagiosgraph, NagiosTV, les clients NRPE et NCPA, le démon NSCA, postfix pour les notifications par mail, et plusieurs collections de plugins tiers. C'est un fork de `JasonRivers/Docker-Nagios`, prévu pour remplacer l'image `jasonrivers/nagios` sur les mêmes volumes.

## Organisation du dépôt

| Chemin | Rôle |
|---|---|
| `Dockerfile` | Toute la construction de l'image et les versions des composants |
| `overlay/` | Fichiers copiés tels quels à la racine de l'image : scripts runit, `start_nagios`, configuration Nagios d'exemple, correctif nagiosgraph |
| `tests/smoke.sh` | Test de fumée d'un conteneur en cours d'exécution |
| `.github/workflows/build.yml` | CI : build, test de fumée, puis publication de l'image sur ghcr.io sur `master` |
| `.github/dependabot.yml` | Mises à jour hebdomadaires de l'image de base et des actions GitHub |
| `SECURITY.md` | Politique de sécurité : versions supportées et signalement privé des vulnérabilités |
| `docker-compose.yml` | Exemple d'utilisation avec des volumes nommés |
| `patches/` | Correctif `check_ifstatus`, non appliqué au build |

## Commandes de base

```sh
docker build -t nagios-fork .
docker run -d --name nagios -p 8080:80 nagios-fork
bash tests/smoke.sh nagios
```

L'interface est servie sur `http://localhost:8080/nagios/` (identifiants par défaut `nagiosadmin` / `nagios`). NagiosTV est sous `/nagios/nagiostv/`, et les graphes sous `/cgi-bin/show.cgi`.

L'image est publiée sur `ghcr.io/sirterrific/docker-nagios`, avec les tags `latest` et la version de Nagios Core (par exemple `4.5.14`). La publication a lieu à chaque push sur `master`, après réussite du test de fumée.

## Quelle page lire ?

| Tâche | Page |
|---|---|
| Comprendre ou modifier une étape du build | [Construction de l'image](architecture/construction-image.md) |
| Diagnostiquer un service qui ne démarre pas, comprendre le premier démarrage ou l'arrêt | [Démarrage et supervision runit](architecture/demarrage-et-supervision.md) |
| Modifier la configuration Nagios livrée par défaut | [Configuration Nagios fournie](configuration/configuration-nagios.md) |
| Choisir les variables d'environnement et les volumes, réutiliser des volumes existants | [Variables d'environnement et volumes](configuration/variables-et-volumes.md) |
| Travailler sur nagiosgraph, NagiosTV, NSCA, NRPE ou les plugins | [Modules complémentaires](integrations/modules-complementaires.md) |
| Monter une version de Nagios ou d'un composant | [Mise à jour des versions](operations/mise-a-jour-versions.md) |
| Lancer ou étendre les tests, faire tourner la CI localement | [Tests et intégration continue](operations/tests-et-ci.md) |

## À retenir

- La configuration du site vit dans les volumes. Une nouvelle image ne remplace jamais un volume non vide.
- L'UID 997 et le GID 1001 de `nagios` sont figés pour rester compatibles avec l'image d'origine.
- Les versions se modifient uniquement dans les `ENV` du `Dockerfile`. Le tableau du `README.md` doit être mis à jour à la main.
