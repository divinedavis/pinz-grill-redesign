#!/usr/bin/env bash
# Build and publish the concept to https://divinedavis.com/pinz-grill/
# (portfolio host 159.203.110.79, docroot /var/www/divinedavis — plain dir, not a checkout).
set -euo pipefail
cd "$(dirname "$0")"
python3 build.py
HOST=${HOST:-root@159.203.110.79}
# Direct SSH from home sometimes stalls; set JUMP=root@104.236.120.144 to relay.
SSH="ssh -o ConnectTimeout=20${JUMP:+ -J $JUMP}"
DEST=/var/www/divinedavis/pinz-grill
rsync -az --delete -e "$SSH" --exclude '.git' --exclude '_*' --exclude 'build.py' --exclude 'deploy.sh' --exclude 'README.md' --exclude '.gitignore' ./ "$HOST:$DEST/"
$SSH "$HOST" "chown -R www-data:www-data $DEST"
for p in "" menu.html catering.html compare.html styles.css assets/logo-sm.png; do
  printf '%s  ' "$(curl -s -o /dev/null -w '%{http_code}' "https://divinedavis.com/pinz-grill/$p")"; echo "/pinz-grill/$p"
done
