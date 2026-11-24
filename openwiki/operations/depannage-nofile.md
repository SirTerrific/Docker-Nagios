# Dépannage : « Failed to create IO broker set: Cannot allocate memory »

## Symptôme

Le conteneur redémarre en boucle. Chaque démarrage affiche la bannière de Nagios Core (4.5.14 au moment du constat), puis :

```
Error: Failed to create IO broker set: Cannot allocate memory
```

Le superviseur (runit, voir [démarrage et supervision](../architecture/demarrage-et-supervision.md)) relance Nagios après chaque échec, d'où la répétition de `checking permissions for nagios & nagiosgraph`.

## Cause

Nagios dimensionne son « IO broker » d'après la limite de descripteurs ouverts (`RLIMIT_NOFILE`, `nofile`). Si le démon Docker donne `nofile=infinity` au conteneur (environ 1 milliard), la réservation mémoire échoue. L'erreur ne vient donc pas d'un manque de RAM sur l'hôte.

Constaté avec Docker 28.1.1 : le même compose fonctionnait avant et a cessé de fonctionner. La cause du changement n'est pas établie : mise à jour de Docker ou de containerd ou nouvelle image sont des pistes ; la version précise qui a changé la valeur par défaut n'a pas été vérifiée.

## Vérifier

```sh
docker run --rm alpine sh -c 'ulimit -n'
systemctl show docker containerd | grep LimitNOFILE
```

Une valeur de l'ordre de `1073741816` ou `infinity` confirme la cause.

## Correctif

Fixer la limite sur le service. Valeur qui a résolu le problème chez l'utilisateur : `65536` (soft et hard).

```yaml
services:
  nagios:
    ulimits:
      nofile:
        soft: 65536
        hard: 65536
```

Avec `docker run` : `--ulimit nofile=65536:65536`.

Pour tous les conteneurs de l'hôte, `/etc/docker/daemon.json` accepte `default-ulimits` (redémarrage de Docker requis).

Le fichier `docker-compose.yml` du dépôt contient déjà ce réglage.

## Sans rapport

Le log `NAGIOSADMIN_PASS is the default value (nagios)` est un avertissement de sécurité distinct : définir `NAGIOSADMIN_PASS` avant d'exposer l'interface web.
