# Fichiers

- [Construction de l'image](construction-image.md) - Étapes du Dockerfile qui produisent l'image Nagios Core sur Ubuntu 24.04 — paquets, comptes, compilation des composants, Apache, overlay, copie des exemples dans /orig, volumes et ports.
- [Démarrage et supervision runit](demarrage-et-supervision.md) - Rôle de start_nagios comme PID 1 (amorçage des volumes vides, création du compte web, lancement et arrêt de runsvdir) et comportement de chaque service runit — apache, nagios, nsca, postfix, rsyslog.
