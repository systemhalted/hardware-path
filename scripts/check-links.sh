#!/usr/bin/env bash
# Check that every URL in the plan resolves. raspberrypi.com answers scripted
# requests with a Cloudflare 403, so 403s from that host only are listed for a
# manual check instead of failing. A 403 from any other host fails.
set -u
fail=0
while read -r url; do
  code=$(curl -sL -o /dev/null -m 20 -A 'Mozilla/5.0 (X11; Linux x86_64)' -w '%{http_code}' "$url")
  case $code in
    2*|3*) ;;
    403)
      case $url in
        https://www.raspberrypi.com/*) echo "blocked (check by hand): $url" ;;
        *) echo "FAIL $code $url"; fail=1 ;;
      esac ;;
    *) echo "FAIL $code $url"; fail=1 ;;
  esac
done < <(grep -ohE 'https?://[^] >"]+' "${PLAN_DIR:-plan}"/*.org | sort -u)
[ $fail -eq 0 ] && echo "links OK"
exit $fail
