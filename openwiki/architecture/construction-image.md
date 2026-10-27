---
type: architecture
title: Construction de l'image
description: Étapes du Dockerfile qui produisent l'image Nagios Core sur Ubuntu 24.04 — paquets, comptes, compilation des composants, Apache, overlay, copie des exemples dans /orig, volumes et ports.
tags: [docker, build, dockerfile, nagios-core, apache]
verified:
  - by: openwiki/0.7.2
    at: 2026-10-27T19:16:56.093Z
sources:
  - id: openwiki-source-3c099d9af7cba6b30d6eaf07
    resource: repo://.gitattributes
  - id: openwiki-source-bb1ebe868e35e9e500714501
    resource: repo://Dockerfile
generated: { by: "claude-code", at: "2026-10-27T19:16:56.093Z" }
---

# Construction de l'image

L'image entière est définie par un seul `Dockerfile` à la racine. Il n'y a pas de build multi-étapes : tous les composants sont compilés depuis leurs sources dans l'image finale, et les sources sont supprimées de `/tmp` à la fin de chaque `RUN`.

## Base et versions

- Base : `ubuntu:24.04`.
- Les versions des composants sont fixées par des `ENV` en tête de fichier : `NAGIOS_BRANCH`, `NAGIOS_PLUGINS_BRANCH`, `NRPE_BRANCH`, `NCPA_BRANCH`, `NSCA_BRANCH`, `NAGIOSTV_VERSION`. Ce sont des tags ou branches Git (ou une version de release pour NagiosTV). La procédure pour les modifier est décrite dans [Mise à jour des versions](../operations/mise-a-jour-versions.md).
- D'autres `ENV` définissent les chemins et comptes : `NAGIOS_HOME=/opt/nagios`, `NAGIOS_USER`/`NAGIOS_GROUP`/`NAGIOS_CMDUSER`/`NAGIOS_CMDGROUP` (tous `nagios`), `APACHE_RUN_USER`/`APACHE_RUN_GROUP` (`nagios`), ainsi que les variables `NG_*` lues par l'installateur de nagiosgraph.

## Ordre des étapes

1. **Paquets système** : préconfiguration de postfix via `debconf-set-selections`, puis un seul `apt-get install` (Apache, PHP, outils de compilation, bibliothèques Perl et Python pour les plugins, SNMP, postfix, rsyslog, runit, `parallel`…). Le cache apt est vidé dans la même couche.
2. **Comptes** : le groupe `nagios` est créé avec le GID 1001 et l'utilisateur `nagios` avec l'UID 997 (`useradd --system -u 997`). Ces identifiants fixes sont ceux de l'image d'origine `jasonrivers/nagios`, ce qui permet de garder l'accès aux fichiers des volumes existants (voir [Variables et volumes](../configuration/variables-et-volumes.md)).
3. **qstat** : cloné depuis `multiplay/qstat`, figé sur un commit précis (`git checkout <sha>`), puis compilé.
4. **Nagios Core** : clone de `NagiosEnterprises/nagioscore` au tag `$NAGIOS_BRANCH`, `./configure` avec `--prefix=/opt/nagios`, `--enable-event-broker` et les utilisateurs/groupes de commande, puis `make all install install-config install-commandmode install-webconf`.
5. **Nagios Plugins** : `nagios-plugins` à `$NAGIOS_PLUGINS_BRANCH`, avec IPv6 et des commandes ping explicites. `check_icmp` reçoit le bit setuid root, et `utils.pm` est lié dans `/usr/lib/nagios/plugins`.
6. **NCPA** : seul le client `check_ncpa.py` est téléchargé depuis le tag `$NCPA_BRANCH`.
7. **NRPE** : seul `check_nrpe` est compilé et copié dans `libexec`. La compilation pointe vers `/usr/lib/x86_64-linux-gnu` : le build vise donc amd64.
8. **NSCA** : démon `nsca` et client `send_nsca` compilés au tag `$NSCA_BRANCH`, avec leurs fichiers de configuration d'exemple. `nsca.cfg` est modifié pour écouter sur `0.0.0.0`.
9. **nagiosgraph** : clone SourceForge figé sur un commit précis, puis `install.pl --install` vers `/opt/nagiosgraph`. Le fichier `nagiosgraph.ssi` est copié comme en-tête SSI commun des pages Nagios.
10. **Collections de plugins tiers** sous `/opt` (WL, JR, JE, DF, nagios-mssql, jpmens-mqtt). Les modules Python `pymssql` et `paho-mqtt` sont installés avec `--break-system-packages`.
11. **NagiosTV** : archive de release décompressée dans `/opt/nagios/share/`.
12. **Apache** : suppression de `www-data` dans `envvars`, `DocumentRoot` pointé sur `/opt/nagios/share`, `ScriptAlias /cgi-bin/` vers `/opt/nagios/sbin/`, activation de `cgi` et des modules `session`, `session_cookie`, `session_crypto`, `auth_form` et `request`. `ServerName` et `PassEnv TZ` sont ajoutés dans `conf-available`.
13. **SNMP** : téléchargement des MIBs (`download-mibs`), puis `mibs +ALL` dans `snmp.conf`.
14. **Ajustements** : chemins de `mail` dans `commands.cfg`, postfix forcé en IPv4 (`smtp_address_preference = ipv4`), suppression de la configuration rsyslog d'origine et du service `getty-5`.
15. **Overlay** : `ADD overlay /` copie les scripts runit, `start_nagios`, `rsyslog.conf` et la configuration Nagios d'exemple. `use_timezone=${NAGIOS_TIMEZONE}` est ajouté à `nagios.cfg` **au build**.
16. **Sauvegarde des exemples** : `etc` et `var` de Nagios et de nagiosgraph sont copiés dans `/orig/etc`, `/orig/var`, `/orig/graph-etc` et `/orig/graph-var`. Au premier démarrage, `start_nagios` s'en sert pour remplir les volumes vides.
17. **Permissions et finalisation** : `chown` des fichiers d'exemple vers `nagios`, `chmod +x` des scripts de l'overlay (y compris `/etc/sv/nsca/run`), application puis suppression du correctif nagiosgraph, liens `/etc/service/*` vers `/etc/sv/*`, setuid sur `/usr/bin/ping`.

## Ports, volumes et point d'entrée

- `EXPOSE 80 5667` : interface web, et NSCA en TCP.
- `VOLUME` : `/opt/nagios/var`, `/opt/nagios/etc`, `/var/log/apache2`, `/opt/Custom-Nagios-Plugins`, `/opt/nagiosgraph/var`, `/opt/nagiosgraph/etc`.
- `CMD [ "/usr/local/bin/start_nagios" ]`. Voir [Démarrage et supervision](demarrage-et-supervision.md).

## Points d'attention

- Il n'y a plus de `.dockerignore` : tout le dépôt fait partie du contexte de build.
- qstat, nagiosgraph et les six collections de plugins tiers sont figés sur un commit (`git checkout <sha>`), ce qui rend les builds reproductibles. Pour les mettre à jour, il faut changer ces SHA à la main.
- Les scripts de l'overlay doivent avoir des fins de ligne LF. `.gitattributes` l'impose (`* text=auto eol=lf`) afin qu'un checkout sous Windows ne casse pas les scripts dans l'image.
- Le Dockerfile utilise encore la syntaxe `ENV clé valeur` et l'instruction `MAINTAINER`. Docker signale `LegacyKeyValueFormat` mais le build fonctionne.

Les composants complémentaires sont détaillés dans [Modules complémentaires](../integrations/modules-complementaires.md).
