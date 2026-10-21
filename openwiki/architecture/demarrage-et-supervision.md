---
type: architecture
title: Démarrage et supervision runit
description: Rôle de start_nagios comme PID 1 (amorçage des volumes vides, création du compte web, lancement et arrêt de runsvdir) et comportement de chaque service runit — apache, nagios, nsca, postfix, rsyslog.
tags: [runit, entrypoint, startup, shutdown, services]
verified:
  - by: openwiki/0.7.2
    at: 2026-10-21T14:42:04.315Z
sources:
  - id: openwiki-source-bb1ebe868e35e9e500714501
    resource: repo://Dockerfile
  - id: openwiki-source-af761033c7412d41b42b0af1
    resource: repo://overlay/etc/rsyslog.conf
  - id: openwiki-source-7ffc6401f752d4262a7cca07
    resource: repo://overlay/etc/sv/apache/run
  - id: openwiki-source-649095c620d1b84f545a45d8
    resource: repo://overlay/etc/sv/nagios/run
  - id: openwiki-source-aeadd7acc8f15c26a108d9a6
    resource: repo://overlay/etc/sv/nsca/run
  - id: openwiki-source-77b22575a9ddd667291f241e
    resource: repo://overlay/etc/sv/postfix/run
  - id: openwiki-source-e04f6712ad74afeb508903c6
    resource: repo://overlay/opt/nagios/etc/nagios.cfg
  - id: openwiki-source-b41c1cb9f9c6db7b0c389a2a
    resource: repo://overlay/usr/local/bin/start_nagios
generated: { by: "claude-code", at: "2026-10-21T14:42:04.315Z" }
---

# Démarrage et supervision runit

Le conteneur exécute `/usr/local/bin/start_nagios`, qui devient le PID 1. Le script prépare les volumes, puis lance `runsvdir` pour superviser cinq services définis dans `/etc/sv/` et liés dans `/etc/service/` au build (voir [Construction de l'image](construction-image.md)).

## Séquence de démarrage (`start_nagios`)

1. **Amorçage des volumes vides.** Pour `/opt/nagios/etc`, `/opt/nagios/var`, `/opt/nagiosgraph/etc` et `/opt/nagiosgraph/var` : si le répertoire est vide (`ls -A`), le script y copie le contenu correspondant de `/orig/*` avec `cp -Rp`. Un répertoire qui contient déjà quelque chose n'est **jamais** modifié. C'est ce qui protège la configuration des installations existantes lors d'une mise à jour de l'image.
2. **Compte web.** Si `/opt/nagios/etc/htpasswd.users` n'existe pas, il est créé avec `htpasswd -c -b -s` à partir de `NAGIOSADMIN_USER` et `NAGIOSADMIN_PASS`, puis attribué à `nagios`. Un fichier existant est conservé tel quel : changer ces variables n'a alors aucun effet.
3. **Supervision.** `runsvdir -P /etc/service` est lancé en arrière-plan. Le script attend sa fin avec `wait`.

## Arrêt

À la réception de `SIGTERM`, `SIGHUP` ou `SIGINT`, la fonction `shutdown` :

1. exécute `sv force-stop` sur chaque service, en parallèle avec GNU `parallel` ;
2. envoie `HUP` à `runsvdir` et attend sa fin ;
3. après une seconde, envoie `kill` à chaque processus orphelin restant, puis `kill -9` si le processus n'est pas terminé au bout de 5 s.

## Services runit

| Service | Script | Comportement |
|---|---|---|
| apache | `/etc/sv/apache/run` | Charge `/etc/apache2/envvars` et `/etc/default/apache-htcacheclean`, exporte `TZ=$NAGIOS_TIMEZONE`, puis lance `apache2 -D NO_DETACH` au premier plan. |
| nagios | `/etc/sv/nagios/run` | Fait un `chown` vers `nagios` de tout ce qui, sous `/opt/nagiosgraph`, n'appartient pas à `nagios`. Si `ngshared.pm` manque, tente de relancer l'installateur nagiosgraph depuis `/tmp/nagiosgraph`. Lance ensuite `/opt/nagios/bin/nagios /opt/nagios/etc/nagios.cfg`. |
| nsca | `/etc/sv/nsca/run` | Si `/opt/nagios/etc/nsca.cfg` existe, lance `nsca -f -c … --single` au premier plan. Sinon, affiche « nsca configuration not found; skipping. » et se termine. |
| postfix | `/etc/sv/postfix/run` | Réécrit `main.cf` à chaque démarrage (`relayhost`, `inet_protocols`, `myhostname`, `mydestination`, suppression de `myorigin`), écrit `/etc/mailname`, copie `resolv.conf` dans le chroot postfix, puis lance `master -d`. |
| rsyslog | `/etc/sv/rsyslog/run` | Lance `rsyslogd -n` avec `/etc/rsyslog.conf`. |

### Journalisation

`overlay/etc/rsyslog.conf` reçoit les messages via `imuxsock` et les envoie tous (sauf `auth` et `authpriv`) sur `/dev/stdout`, avec un modèle sans horodatage. Comme `nagios.cfg` active `use_syslog=1`, les événements Nagios apparaissent dans `docker logs`, en plus de `/opt/nagios/var/nagios.log`.

## Pièges connus

- **Branche morte de nagiosgraph.** Le build supprime `/tmp/nagiosgraph`, donc la réinstallation dans `nagios/run` échouerait si `ngshared.pm` manquait. En pratique, le fichier est fourni par l'amorçage depuis `/orig/graph-etc`. Ce n'est un problème que si le volume `nagiosgraph/etc` est non vide mais incomplet.
- **Boucle de redémarrage de nsca.** Sans `nsca.cfg`, le script se termine immédiatement et runit le relance en boucle. C'est sans gravité mais bruyant. Cela arrive avec un volume `etc` ancien qui n'a jamais contenu `nsca.cfg`.
- **Bit exécutable.** Un script `run` sans bit exécutable fait échouer runit avec `unable to start ./run: access denied`. C'est pourquoi le Dockerfile fait un `chmod +x` explicite sur chaque script, `nsca` compris.
- **Modifications de postfix non persistantes.** `main.cf` n'est pas dans un volume et il est réécrit au démarrage. La configuration postfix passe par les variables décrites dans [Variables et volumes](../configuration/variables-et-volumes.md).
