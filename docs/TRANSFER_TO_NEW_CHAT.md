# Перенос проекта в новый чат

Проект: 3x-ui SSL certificates renew  
Репозиторий: https://github.com/messireL/3x-ui-SSL-certificates-renew  
Текущая версия: v1.0.5

## Назначение
Автоматическое получение, установка и продление SSL-сертификатов для 3x-ui / x-ui.

## Ключевые пути на сервере
- Рабочий проект: `/opt/3xuisslcert`
- Репозиторий на сервере: `/opt/3xuisslcert-repo`
- Конфиг: `/etc/3xuisslcert.conf`
- Cron: `/etc/cron.d/3xuisslcert`
- Основной бинарник: `/opt/3xuisslcert/xui-certctl`
- Совместимые ссылки:
  - `/usr/local/bin/xui-certctl`
  - `/usr/local/sbin/xui-certctl`

## Пути сертификатов
- `/root/cert/ip/<ID>/fullchain.pem`
- `/root/cert/ip/<ID>/private.key`

## Что важно помнить
- `install.sh` миграционный: ручной деинсталл старой версии обычно не нужен.
- Начиная с v1.0.4, установщик:
  - удаляет старый cron `/etc/cron.d/xui-certctl`
  - создаёт совместимый линк `/usr/local/sbin/xui-certctl`
  - перепривязывает текущий cert через `acme.sh --install-cert`, чтобы обновить `reloadcmd`
- Основная ранее найденная проблема:
  - `postdeploy` падал, если канонический путь совпадал с целевым
  - это исправлено в v1.0.3
- Дополнительная важная проблема:
  - на части серверов `Le_ReloadCmd` указывал на старый путь `/usr/local/sbin/xui-certctl`
  - для этого добавлен совместимый линк и миграция в v1.0.4

## Как обновлять
На локальном ПК:
1. Обновить файлы в локальном клоне
2. Commit через GitHub Desktop
3. Push в GitHub

На сервере:
1. `cd /opt/3xuisslcert-repo`
2. `sudo git pull`
3. `sudo bash install.sh`

## Что проверять после установки
- `xui-certctl version`
- `xui-certctl status`
- `cat /etc/cron.d/3xuisslcert`
- `ls -l /usr/local/bin/xui-certctl /usr/local/sbin/xui-certctl`
- `grep -E 'Le_ReloadCmd|Le_RealFullChainPath|Le_RealKeyPath' /root/.acme.sh/<ID>_ecc/<ID>.conf`

## Если сертификат обновился, но не применился
Проверить:
1. Какой `Le_ReloadCmd` сохранён в `.acme.sh/<ID>.conf`
2. Что существует:
   - `/opt/3xuisslcert/xui-certctl`
   - `/usr/local/sbin/xui-certctl`
3. Что `sudo /opt/3xuisslcert/xui-certctl postdeploy` реально перезапускает `x-ui`

## 24.11.2026 — подключение центрального AI-аудита (CI-only)

Версия v1.0.5 и все рабочие скрипты сохранены. Новый workflow `.github/workflows/mandatory-ai-audit.yml` использует доверенный `pull_request_target` для owner-controlled same-repository PR в main. До checkout проверяется имя выделенного self-hosted runner ssl-certificates-renew-01/02; выполняется только `bash -n` трёх файлов install.sh, uninstall.sh, files/xui-certctl на точном HEAD без исполнения скриптов. Затем центральные CODE/DOCS и независимый zero Critical/Substantial findings gate на едином принятом SHA `e38f3790cea0e0e1c1a0b8b5ab92445df3318fbd` ([PR #148](https://github.com/messireL/ai-ci-orchestrator/pull/148)). Модели выбираются в оркестраторе, рекомендации не блокируют. GitGuardian — обязательная проверка приёмки. Фактические runner names AI jobs проверяются по журналам; generic central selector не менялся. Не использовать GitHub-hosted runners.

Для первого подключения (до появления trusted caller в main) допускается одноразовая owner-controlled push-ветка с фиксированными PR/HEAD, той же syntax-проверкой и обоими pin; её не сливать и не использовать повторно. После merge проверить штатный автоматический аудит на отдельном CI handoff PR. PR не публикует релиз, не выполняет install/uninstall/sync/postdeploy, не вызывает ACME, UFW, cron или systemctl и не изменяет VPS/сертификаты. Проверка синтаксиса не подтверждает реальное получение/продление сертификата. Серверная приёмка остаётся отдельной задачей владельца.
