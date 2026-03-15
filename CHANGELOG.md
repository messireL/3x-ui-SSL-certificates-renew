# CHANGELOG

## v1.0.4
- migration release: no manual uninstall required
- added compatibility symlink `/usr/local/sbin/xui-certctl -> /opt/3xuisslcert/xui-certctl`
- installer now rebinds current certificate via `acme.sh --install-cert` to refresh reloadcmd
- old cron `/etc/cron.d/xui-certctl` is removed automatically
- README updated with migration workflow

## v1.0.3
- fixed postdeploy when canonical certificate path equals destination path
- x-ui restart now completes successfully after install/renew
- README examples made generic without project-specific domain or IP

## v1.0.2
- project path changed to /opt/3xuisslcert
- config moved to /etc/3xuisslcert.conf
- cron moved to /etc/cron.d/3xuisslcert
- automatic public IP detection if --id is not specified
- temporary UFW opening of 80/tcp only near renew window
- symlink /usr/local/bin/xui-certctl added
- README expanded with full deployment and update workflow

## v1.0.1
- port 80 via UFW opens only close to renew time
- added UFW_OPEN80_ONLY_WHEN_DUE and UFW_OPEN80_WINDOW_SEC

## v1.0.0
- initial public installer
- certificate issue / renew / install workflow
- cron support
- postdeploy restart for x-ui
