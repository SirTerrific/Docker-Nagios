#!/bin/bash
# Migration test: start the old upstream image on fresh volumes, stop it, then start
# the image under test on the SAME volumes and run the smoke test.
# Usage: tests/migrate.sh <new-image> [old-image]
set -eu

NEW=${1:?new image}
OLD=${2:-jasonrivers/nagios:latest}
P=nt-mig-$$

cleanup() {
    docker rm -f "$P-old" "$P-new" >/dev/null 2>&1 || true
    docker volume rm -f "$P-etc" "$P-var" "$P-gpe" "$P-gpv" >/dev/null 2>&1 || true
}
trap cleanup EXIT

VOLS="-v $P-etc:/opt/nagios/etc -v $P-var:/opt/nagios/var -v $P-gpe:/opt/nagiosgraph/etc -v $P-gpv:/opt/nagiosgraph/var"

docker run -d --name "$P-old" $VOLS "$OLD" >/dev/null
for _ in $(seq 1 60); do
    docker exec "$P-old" sv status /etc/service/nagios 2>/dev/null | grep -q '^run' && break
    sleep 2
done
sleep 10
docker exec "$P-old" sh -c 'echo "# MIGRATION-TEST" >> /opt/nagios/etc/objects/contacts.cfg'
docker stop -t 30 "$P-old" >/dev/null
docker rm "$P-old" >/dev/null

docker run -d --name "$P-new" $VOLS "$NEW" >/dev/null
bash "$(dirname "$0")/smoke.sh" "$P-new"
docker exec "$P-new" grep -q MIGRATION-TEST /opt/nagios/etc/objects/contacts.cfg
echo "PASS: existing volumes migrated"
