---
type: integration
title: Modules complémentaires
description: Composants ajoutés autour de Nagios Core — nagiosgraph (chaîne perfdata, CGI, correctif), NagiosTV, clients NRPE et NCPA, démon NSCA, collections de plugins tiers, qstat — et le correctif check_ifstatus présent mais non appliqué.
tags: [nagiosgraph, nagiostv, nrpe, ncpa, nsca, plugins]
verified:
  - by: openwiki/0.7.2
    at: 2026-10-21T14:42:04.315Z
sources:
  - id: openwiki-source-bb1ebe868e35e9e500714501
    resource: repo://Dockerfile
  - id: openwiki-source-be28c8769ed05724bf6b137e
    resource: repo://overlay/opt/nagiosgraph/etc/fix-nagiosgraph-multiple-selection.sh
  - id: openwiki-source-0f9ac0236e0f2ca44d2742be
    resource: repo://patches/nagios-plugins-2.4.0_check_ifstatus.patch
generated: { by: "claude-code", at: "2026-10-21T14:42:04.315Z" }
---

# Modules complémentaires

Tous ces composants sont installés au build par le `Dockerfile` (voir [Construction de l'image](../architecture/construction-image.md)).

## nagiosgraph

**Installation.** Le dépôt SourceForge est cloné sans version fixée, puis installé par `install.pl --install --prefix /opt/nagiosgraph`. L'utilisateur Nagios et l'utilisateur web sont `nagios`, et le fichier perfdata est `/opt/nagios/var/perfdata.log`. Les variables `NG_CGI_DIR=/opt/nagios/sbin`, `NG_WWW_DIR=/opt/nagios/share/nagiosgraph` et `NG_CGI_URL=/cgi-bin` placent les CGI de nagiosgraph à côté de celles de Nagios. Elles sont donc servies sous `/cgi-bin/` (par exemple `/cgi-bin/show.cgi`). Le fichier `share/nagiosgraph.ssi` est copié comme `common-header.ssi` de Nagios. Il injecte dans toutes les pages Nagios le JavaScript de l'info-bulle des graphes.

**Chaîne de données.**

1. Nagios écrit les perfdata des services dans `perfdata.log` (voir [Configuration Nagios](../configuration/configuration-nagios.md)).
2. Toutes les 10 s, la commande `process-service-perfdata` lance `/opt/nagiosgraph/bin/insert.pl`, qui alimente les fichiers RRD de `/opt/nagiosgraph/var`.
3. Les services qui héritent de `graphed-service` affichent un lien vers `show.cgi`.

**Correctif de multi-sélection.** Au build, `fix-nagiosgraph-multiple-selection.sh` modifie `ngshared.pm` par `sed`. Dans les appels `popup_menu` des listes `period` et `db`, `-multiple => 1` devient `-multiple`, ce qui répare la sélection multiple dans l'interface. Le script est ensuite supprimé. Ce correctif ne touche que l'exemple copié dans `/orig/graph-etc` : un volume `nagiosgraph/etc` existant garde son `ngshared.pm`.

**Au démarrage**, le service `nagios` fait un `chown` vers `nagios` de `/opt/nagiosgraph`. Il tente aussi une réinstallation si `ngshared.pm` manque, mais cette tentative ne peut pas aboutir parce que les sources ont été supprimées au build (voir [Démarrage et supervision](../architecture/demarrage-et-supervision.md)).

## NagiosTV

L'archive de release `nagiostv-${NAGIOSTV_VERSION}.tar.gz` est téléchargée depuis `chriscareycode/nagiostv-react` et décompressée dans `/opt/nagios/share/`. L'interface est servie sous `/nagios/nagiostv/`, derrière la même authentification que Nagios.

## Agents et transport

- **NRPE** : seul le client `check_nrpe` est compilé et copié dans `/opt/nagios/libexec`. Il n'y a pas de démon NRPE dans l'image.
- **NCPA** : seul le client `check_ncpa.py` est récupéré, pour le tag `$NCPA_BRANCH`.
- **NSCA** : le démon `nsca` et le client `send_nsca` vont dans `/opt/nagios/bin`, et les fichiers `nsca.cfg` et `send_nsca.cfg` d'exemple dans `/opt/nagios/etc`, avec `server_address=0.0.0.0`. Le démon tourne comme service runit sur le port 5667 exposé. Il transmet les résultats passifs à Nagios via le pipe de commandes externes.

## Plugins

- **Nagios Plugins** officiels (`$NAGIOS_PLUGINS_BRANCH`) dans `/opt/nagios/libexec`. `check_icmp` est setuid root.
- **Collections tierces** clonées sous `/opt` sans version fixée : `WL-Nagios-Plugins`, `JR-Nagios-Plugins`, `JE-Nagios-Plugins`, `nagios-mssql`, `jpmens-mqtt`, `DF-Nagios-Plugins`. Seuls quelques plugins sont copiés dans `libexec` : `check_mem.pl`, `check_mssql_database.py`, `check_mssql_server.py`, `check-mqtt.py`, `check_sql`, `check_jenkins` et `check_vpn`. Les autres sont appelés par leur chemin sous `/opt`. Les dépendances Python `pymssql` et `paho-mqtt` sont installées par `pip --break-system-packages`.
- **qstat** est compilé depuis `multiplay/qstat` (vérification de serveurs de jeux).

## Correctif `check_ifstatus` non appliqué

`patches/nagios-plugins-2.4.0_check_ifstatus.patch` réordonne les OID SNMP de `check_ifstatus` pour n'interroger `ifXTable` que si elle est disponible. **Aucune étape du Dockerfile n'applique ce correctif.** Il reste dans le dépôt comme référence.
