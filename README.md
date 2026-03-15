# 3x-ui SSL certificates renew

Автоматическое получение, установка и продление SSL-сертификатов для **3x-ui / x-ui** с поддержкой:

- автоматического определения публичного IP, если `--id` не указан
- выпуска сертификата для **IP** и/или **домена** (SAN)
- автоматического продления через **cron**
- установки сертификатов в:
  - `/root/cert/ip/<ID>/fullchain.pem`
  - `/root/cert/ip/<ID>/private.key`
- временного открытия `80/tcp` через **UFW** только на время выпуска/обновления
- автоматического перезапуска сервиса **x-ui** после обновления сертификата
- миграции со старых установок (`/usr/local/sbin/xui-certctl`, `/etc/xui-certctl.conf`, `/etc/cron.d/xui-certctl`)

---

## Что устанавливается

Проект устанавливается в постоянную папку:

```bash
/opt/3xuisslcert
```

Создаются и/или обновляются файлы:

```bash
/opt/3xuisslcert/xui-certctl
/etc/3xuisslcert.conf
/etc/cron.d/3xuisslcert
/usr/local/bin/xui-certctl
/usr/local/sbin/xui-certctl
```

Сертификаты сохраняются в:

```bash
/root/cert/ip/<ID>/fullchain.pem
/root/cert/ip/<ID>/private.key
```

---

## Важное изменение в v1.0.4

Полный деинсталл работающего сервиса **не нужен**.

Новый `install.sh` сам:

- ставит актуальную версию в `/opt/3xuisslcert`
- создаёт совместимый линк:
  - `/usr/local/sbin/xui-certctl -> /opt/3xuisslcert/xui-certctl`
- удаляет старый cron:
  - `/etc/cron.d/xui-certctl`
- создаёт новый cron:
  - `/etc/cron.d/3xuisslcert`
- заново перепривязывает текущий сертификат через `acme.sh --install-cert`, чтобы обновить `reloadcmd`

То есть это **миграционный релиз**.

---

## Развёртывание на сервере

### Вариант 1. Установка из GitHub (рекомендуется)

```bash
sudo git clone https://github.com/messireL/3x-ui-SSL-certificates-renew.git /opt/3xuisslcert-repo
cd /opt/3xuisslcert-repo
sudo bash install.sh
```

После этого рабочий проект будет установлен в:

```bash
/opt/3xuisslcert
```

### Вариант 2. Обновление проекта на сервере

Если репозиторий уже клонирован на сервер:

```bash
cd /opt/3xuisslcert-repo
sudo git pull
sudo bash install.sh
```

---

## Установка

### 1. Самый простой вариант

Если нужен сертификат для публичного IP сервера, а IP определится автоматически:

```bash
sudo bash install.sh
```

### 2. Автоопределение IP + предложение hostname в SAN

```bash
sudo bash install.sh --auto
```

### 3. Явно указать IP и домен

```bash
sudo bash install.sh --id <public-ip> --san <dns-name>
```

### 4. Только домен

```bash
sudo bash install.sh --id <dns-name>
```

### 5. Если 80 порт занят и используется webroot

```bash
sudo bash install.sh --id <dns-name> --challenge webroot --webroot /var/www/html
```

---

## Что делает install.sh

Скрипт установки:

1. определяет публичный IP, если `--id` не указан
2. ставит проект в `/opt/3xuisslcert`
3. создаёт конфиг `/etc/3xuisslcert.conf`
4. создаёт cron-задачу `/etc/cron.d/3xuisslcert`
5. создаёт ссылки:
   ```bash
   /usr/local/bin/xui-certctl -> /opt/3xuisslcert/xui-certctl
   /usr/local/sbin/xui-certctl -> /opt/3xuisslcert/xui-certctl
   ```
6. если сертификат для текущего `MAIN_ID` уже существует — перепривязывает `reloadcmd`
7. при первом запуске вызывает:
   ```bash
   xui-certctl sync
   ```

---

## Cron

Файл cron создаётся автоматически:

```bash
/etc/cron.d/3xuisslcert
```

Расписание зависит от типа сертификата:

- если используется **IP** → запуск каждые 6 часов
- если используются только домены → 2 раза в сутки

Проверка:

```bash
cat /etc/cron.d/3xuisslcert
```

---

## UFW и порт 80

Если используется `standalone`, проект умеет:

- **не держать 80/tcp открытым постоянно**
- временно открывать `80/tcp` только во время выпуска/renew
- после завершения удалять временное правило

Если у вас уже есть постоянное правило UFW на `80/tcp`, его лучше убрать, чтобы порт не был открыт всегда.

Проверка UFW:

```bash
sudo ufw status numbered
```

---

## Проверка после установки

### Проверка версии

```bash
xui-certctl version
```

### Проверка состояния

```bash
xui-certctl status
```

### Проверка сертификата

```bash
openssl x509 -in /root/cert/ip/<ID>/fullchain.pem -noout -enddate -subject
```

### Проверка cron

```bash
cat /etc/cron.d/3xuisslcert
```

### Проверка сервиса x-ui

```bash
sudo systemctl status x-ui --no-pager
```

---

## Ручные команды

### Запустить синхронизацию вручную

```bash
sudo xui-certctl sync
```

### Принудительно выполнить postdeploy

```bash
sudo /opt/3xuisslcert/xui-certctl postdeploy
```

### Переустановить сертификат через acme.sh и перепривязать reloadcmd

```bash
sudo /root/.acme.sh/acme.sh --install-cert -d <ID> --ecc \
  --fullchain-file /root/cert/ip/<ID>/fullchain.pem \
  --key-file       /root/cert/ip/<ID>/private.key \
  --reloadcmd      "/opt/3xuisslcert/xui-certctl postdeploy"
```

---

## Обновление проекта

### На локальном ПК

1. Обновляешь файлы проекта в локальном клоне
2. Коммитишь изменения через **GitHub Desktop**
3. Пушишь в GitHub

### На сервере

```bash
cd /opt/3xuisslcert-repo
sudo git pull
sudo bash install.sh
```

---

## Удаление

Полный деинсталл нужен только если вы действительно хотите убрать проект.

```bash
sudo bash uninstall.sh
```

Это удалит:

```bash
/etc/cron.d/3xuisslcert
/etc/cron.d/xui-certctl
/etc/3xuisslcert.conf
/usr/local/bin/xui-certctl
/usr/local/sbin/xui-certctl
/opt/3xuisslcert
```

---

## Рекомендуемый порядок работы

### На локальном ПК
1. Открываешь репозиторий в GitHub Desktop
2. Меняешь файлы
3. Commit
4. Push

### На сервере
1. Переходишь в папку репозитория:
   ```bash
   cd /opt/3xuisslcert-repo
   ```
2. Забираешь изменения:
   ```bash
   sudo git pull
   ```
3. Переустанавливаешь проект:
   ```bash
   sudo bash install.sh
   ```
4. Проверяешь:
   ```bash
   xui-certctl version
   xui-certctl status
   cat /etc/cron.d/3xuisslcert
   ```

---

## Примечание

Если после обновления сертификата панель **3x-ui / x-ui** не перезапускается автоматически, сначала проверь:

- какой `Le_ReloadCmd` записан в `/root/.acme.sh/<ID>_ecc/<ID>.conf`
- существует ли `/usr/local/sbin/xui-certctl`
- существует ли `/opt/3xuisslcert/xui-certctl`

Начиная с `v1.0.4`, установщик специально создаёт совместимый путь `/usr/local/sbin/xui-certctl`, чтобы старые привязки `reloadcmd` не ломали автоматическое применение сертификата.
