---
type: testing
title: Tests et intégration continue
description: Test de fumée tests/smoke.sh, workflow GitHub Actions build-test, exécution locale avec act, scripts hérités Travis/build.sh, et workflow planifié OpenWiki.
tags: [testing, smoke-test, github-actions, act, ci]
verified:
  - by: openwiki/0.7.2
    at: 2026-10-21T14:42:04.315Z
sources:
  - id: openwiki-source-7a80b79a6fb3618cbfab08a2
    resource: repo://.github/workflows/build.yml
  - id: openwiki-source-6d4b4e707b8d60b6ccfa3425
    resource: repo://.github/workflows/openwiki-update.yml
  - id: openwiki-source-5733839de54e3cc774d6e83d
    resource: repo://.travis.yml
  - id: openwiki-source-8a2e26d4137b8250f68bb869
    resource: repo://build.sh
  - id: openwiki-source-2c4a8dc1cbd9d20dda8911b0
    resource: repo://tests/smoke.sh
generated: { by: "claude-code", at: "2026-10-21T14:42:04.315Z" }
---

# Tests et intégration continue

## Test de fumée : `tests/smoke.sh`

Usage : `bash tests/smoke.sh <conteneur> [version-attendue]`. Le script vérifie un conteneur **déjà démarré** à partir de l'image.

Les requêtes HTTP partent d'un conteneur `curlimages/curl` qui partage l'espace réseau du conteneur testé (`--network container:<nom>`). Le test fonctionne ainsi sans publier de port, aussi bien sur un runner GitHub que sous `act`. Variables utilisables : `NAGIOSADMIN_USER`, `NAGIOSADMIN_PASS`, `CURL_IMAGE`.

Vérifications, dans l'ordre :

1. Attente qu'Apache réponde (au plus 60 essais espacés de 2 s).
2. `nagios --version` correspond à la version attendue, si elle est fournie.
3. `nagios -v nagios.cfg` affiche `Total Errors:   0`.
4. Les services runit `apache`, `nagios`, `nsca`, `postfix` et `rsyslog` sont en état `run:`.
5. Codes HTTP : `/nagios/` sans authentification → 401. Avec authentification → 200 pour `/nagios/`, `status.cgi?host=all`, `/nagios/nagiostv/` et `/cgi-bin/show.cgi?host=localhost` (nagiosgraph).
6. `status.cgi` liste `localhost`.
7. Protection CSRF de `cmd.cgi` (Nagios ≥ 4.5.13) :
   - un POST d'ajout de commentaire sans cookie est rejeté (« Invalid or missing CSRF cookie ») ;
   - un GET sur le formulaire renvoie le cookie `NagFormId` ;
   - un POST avec ce cookie et le champ `nagFormId` est accepté.
8. Pipe de commandes : le commentaire accepté apparaît dans `status.dat` (au plus 30 s d'attente), et le commentaire rejeté n'y apparaît pas.

Le script affiche `PASS:`/`FAIL:` pour chaque contrôle, se termine par `ALL TESTS PASSED` ou `SOME TESTS FAILED`, et renvoie un code de sortie non nul en cas d'échec.

## Workflow GitHub Actions `build-test`

`.github/workflows/build.yml` se déclenche sur `push`, `pull_request` et `workflow_dispatch`, sur `ubuntu-24.04`. Étapes :

1. construction de l'image `nagios-ci:<run_id>` ;
2. démarrage du conteneur `nagios-ci-<run_id>` ;
3. extraction de la version attendue depuis la ligne `ENV NAGIOS_BRANCH` du Dockerfile, puis exécution de `tests/smoke.sh` ;
4. en cas d'échec : `docker logs` et les 50 dernières lignes de `nagios.log` ;
5. dans tous les cas : suppression du conteneur et de l'image.

### Exécution locale avec act

Le même workflow peut être lancé localement avec [act](https://github.com/nektos/act), en utilisant une image de runner compatible :

```sh
act push -P ubuntu-24.04=catthehacker/ubuntu:act-24.04
```

act a besoin d'un accès au démon Docker de l'hôte. Le test de fumée passe par un conteneur curl justement pour ne pas dépendre d'un port publié par le conteneur du runner.

## Scripts hérités

- `.travis.yml` clone le dépôt upstream `JasonRivers/Docker-Nagios` et lance `./build.sh`. Il date de Travis CI et ne teste pas ce fork.
- `build.sh` construit l'image `nagios` et la démarre sur le port 8080, sans aucune vérification.

Ces deux fichiers sont exclus du contexte Docker par `.dockerignore`.

## Workflow OpenWiki

`.github/workflows/openwiki-update.yml` lance chaque jour à 08:00 UTC (ou à la demande) la commande `openwiki code --update`. Le résultat est proposé dans une pull request sur la branche `openwiki/update`. Ce workflow a besoin du secret `OPENAI_API_KEY`, ainsi que des secrets LangSmith s'ils sont utilisés. Sans ces secrets, l'exécution échoue. Il ne fait pas partie des tests de l'image.

Voir aussi [Mise à jour des versions](mise-a-jour-versions.md) pour le test de migration sur des volumes existants.
