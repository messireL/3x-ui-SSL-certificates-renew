# Установка, обновление, деинсталл и проверка

## Установка
```bash
cd /opt/3xuisslcert-repo
sudo bash install.sh
```

## Установка с автодетектом и SAN
```bash
cd /opt/3xuisslcert-repo
sudo bash install.sh --auto
```

## Обновление
```bash
cd /opt/3xuisslcert-repo
sudo git pull
sudo bash install.sh
```

## Полный деинсталл
```bash
cd /opt/3xuisslcert-repo
sudo bash uninstall.sh
```

## Что installer чистит сам
- `/etc/cron.d/xui-certctl`
- старые reloadcmd-привязки через повторный `acme.sh --install-cert`
- создаёт совместимый линк `/usr/local/sbin/xui-certctl`

## Что uninstall.sh удаляет
- `/etc/cron.d/3xuisslcert`
- `/etc/cron.d/xui-certctl`
- `/etc/3xuisslcert.conf`
- `/usr/local/bin/xui-certctl`
- `/usr/local/sbin/xui-certctl`
- `/opt/3xuisslcert`

## Что uninstall.sh не удаляет
- `/root/.acme.sh/...`
- `/root/cert/ip/...`
- `/opt/3xuisslcert-repo`

## Быстрая проверка после установки / обновления
```bash
xui-certctl version
xui-certctl status
cat /etc/cron.d/3xuisslcert
ls -l /usr/local/bin/xui-certctl /usr/local/sbin/xui-certctl
```

## Проверка привязки reloadcmd
```bash
grep -E 'Le_ReloadCmd|Le_RealFullChainPath|Le_RealKeyPath' /root/.acme.sh/<ID>_ecc/<ID>.conf
```

## Проверка сервиса
```bash
sudo systemctl status x-ui --no-pager
sudo systemctl show x-ui -p ActiveEnterTimestamp
```

## Ручной тест применения сертификата
```bash
sudo /opt/3xuisslcert/xui-certctl postdeploy
sudo systemctl show x-ui -p ActiveEnterTimestamp
```
