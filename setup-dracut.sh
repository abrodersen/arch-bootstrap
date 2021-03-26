[ -n "${DEBUG}" ] && set -x
set -e

install -Dm0644 -t /etc/dracut.conf.d/ dracut-defaults.conf
install -Dm0755 -t /usr/local/bin dracut-install dracut-remove
install -Dm0644 -t /etc/pacman.d/hooks/ 60-dracut-remove.hook 90-dracut-install.hook
