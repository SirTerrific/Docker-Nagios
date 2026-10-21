#!/bin/bash
# Smoke test for a running container built from this repository.
# Usage: tests/smoke.sh <container-name> [expected-nagios-version]
# HTTP checks run from a curl container that shares the target's network
# namespace, so they work both on GitHub runners and under act.
set -u

C=${1:?container name}
EXPECTED=${2:-}
USER=${NAGIOSADMIN_USER:-nagiosadmin}
PASS=${NAGIOSADMIN_PASS:-nagios}
CURL_IMAGE=${CURL_IMAGE:-curlimages/curl:latest}
FAIL=0

ok()   { echo "PASS: $*"; }
ko()   { echo "FAIL: $*"; FAIL=1; }
curlc() { docker run --rm --network "container:$C" "$CURL_IMAGE" -s "$@"; }

# Wait until Apache answers (max 120 s)
for _ in $(seq 1 60); do
    code=$(curlc -o /dev/null -w '%{http_code}' http://localhost/ 2>/dev/null)
    [ "$code" != "000" ] && [ -n "$code" ] && break
    sleep 2
done

# Nagios version
ver=$(docker exec "$C" /opt/nagios/bin/nagios --version | sed -n 's/^Nagios Core \([0-9.]*\).*/\1/p')
if [ -z "$EXPECTED" ] || [ "$ver" = "$EXPECTED" ]; then ok "Nagios Core $ver"; else ko "Nagios Core $ver, expected $EXPECTED"; fi

# Configuration check
if docker exec "$C" /opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg | grep -q 'Total Errors:   0'; then
    ok "nagios -v: 0 errors"
else
    ko "nagios -v reports errors"
fi

# runit services
for s in apache nagios nsca postfix rsyslog; do
    if docker exec "$C" sv status "/etc/service/$s" | grep -q '^run:'; then ok "service $s running"; else ko "service $s not running"; fi
done

# HTTP checks: path, auth (y/n), expected code
check_http() {
    local path=$1 auth=$2 want=$3 code
    if [ "$auth" = y ]; then
        code=$(curlc -o /dev/null -w '%{http_code}' -u "$USER:$PASS" "http://localhost$path")
    else
        code=$(curlc -o /dev/null -w '%{http_code}' "http://localhost$path")
    fi
    if [ "$code" = "$want" ]; then ok "GET $path -> $code"; else ko "GET $path -> $code, expected $want"; fi
}
check_http /nagios/ n 401
check_http /nagios/ y 200
check_http "/cgi-bin/status.cgi?host=all" y 200
check_http /nagios/nagiostv/ y 200
check_http "/cgi-bin/show.cgi?host=localhost" y 200

# status.cgi must list localhost once Nagios has loaded its objects
if curlc -u "$USER:$PASS" "http://localhost/cgi-bin/status.cgi?host=all" | grep -q 'localhost'; then
    ok "status.cgi lists localhost"
else
    ko "status.cgi does not list localhost"
fi

# cmd.cgi CSRF protection (Nagios >= 4.5.13)
form="cmd_typ=1&cmd_mod=2&host=localhost&persistent=on&com_author=ci&com_data"
out=$(curlc -u "$USER:$PASS" -d "${form}=CI-NOCOOKIE" http://localhost/cgi-bin/cmd.cgi)
if echo "$out" | grep -q 'Invalid or missing CSRF cookie'; then
    ok "cmd.cgi rejects commit without CSRF cookie"
else
    ko "cmd.cgi accepted or failed differently without CSRF cookie"
fi

cookie=$(curlc -D - -o /dev/null -u "$USER:$PASS" "http://localhost/cgi-bin/cmd.cgi?cmd_typ=1&host=localhost" \
    | sed -n 's/^Set-Cookie: NagFormId=\([^;]*\).*/\1/ip' | tr -d '\r')
if [ -n "$cookie" ]; then
    ok "cmd.cgi sets NagFormId cookie"
    out=$(curlc -u "$USER:$PASS" -b "NagFormId=$cookie" -d "${form}=CI-WITHCOOKIE&nagFormId=$cookie" http://localhost/cgi-bin/cmd.cgi)
    if echo "$out" | grep -qi 'successfully submitted'; then
        ok "cmd.cgi accepts commit with valid CSRF cookie"
    else
        ko "cmd.cgi rejected commit with valid CSRF cookie"
    fi
else
    ko "cmd.cgi did not set NagFormId cookie"
fi

# The accepted comment must reach Nagios through the command pipe
found=0
for _ in $(seq 1 15); do
    if docker exec "$C" grep -q 'CI-WITHCOOKIE' /opt/nagios/var/status.dat 2>/dev/null; then found=1; break; fi
    sleep 2
done
if [ $found = 1 ]; then ok "comment written through nagios.cmd"; else ko "comment not found in status.dat"; fi
if docker exec "$C" grep -q 'CI-NOCOOKIE' /opt/nagios/var/status.dat 2>/dev/null; then ko "rejected comment reached Nagios"; else ok "rejected comment did not reach Nagios"; fi

[ $FAIL = 0 ] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit $FAIL
