# 3xuisslcert v1.0.2

## Что делает
- ставит проект в `/opt/3xuisslcert`
- создаёт конфиг `/etc/3xuisslcert.conf`
- создаёт cron `/etc/cron.d/3xuisslcert`
- если `--id` не указан, автоматически определяет публичный IP
- создаёт ссылку `/usr/local/bin/xui-certctl -> /opt/3xuisslcert/xui-certctl`

## Установка
```bash
tar -xzf 3xuisslcert-v1.0.2.tar.gz
cd 3xuisslcert-v1.0.2
sudo bash install.sh
```

Авто + предложение hostname в SAN:
```bash
sudo bash install.sh --auto
```

Явно:
```bash
sudo bash install.sh --id 89.44.76.8 --san s02.shaten.su
```

## Проверка
```bash
xui-certctl version
xui-certctl status
cat /etc/cron.d/3xuisslcert
```
