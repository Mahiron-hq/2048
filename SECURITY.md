# Security Policy

## Supported versions

Only the latest release receives fixes. Please update to it before reporting.

| Version | Supported |
| --- | --- |
| Latest release | ✅ |
| Older releases | ❌ |

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub: open the repository's **Security** tab and choose **[Report a vulnerability](https://github.com/Mahiron-hq/2048/security/advisories/new)**. Do not open a public issue for security problems.

A useful report includes the affected version and platform, the steps to reproduce, and what an attacker could achieve.

You can expect an acknowledgement within 7 days. Once the issue is confirmed, a fix is released as soon as practical and the advisory is published with credit to the reporter, unless you prefer to stay anonymous.

## Scope

2048 Merge is an offline game: it has no accounts, no network code and no analytics, and it asks for no permissions except vibration (see [PRIVACY.md](PRIVACY.md)). Relevant reports include, for example:

- a crafted save file that crashes the game or corrupts other data on the device;
- a problem in the release pipeline (`.github/workflows`) or in how APKs are signed;
- a published APK whose signature does not match the release certificate below.

## Verifying a download

Release APKs are built by GitHub Actions from the tagged source; every action in the workflows is pinned to a commit SHA and the Godot binaries are checked against their published SHA-512 sums. Each release carries:

- `SHA256SUMS.txt` — checksums of the APKs: `sha256sum --check SHA256SUMS.txt`;
- a signed build provenance attestation: `gh attestation verify <file>.apk --repo Mahiron-hq/2048`;
- the release signing certificate, SHA-256 fingerprint
  `eb4210095c9919745312b83e94a3755767b764427c447b986c85e63479542fe0`:
  `apksigner verify --print-certs <file>.apk`.

---

# Политика безопасности

## Поддерживаемые версии

Исправления выходят только для последнего релиза. Перед сообщением о проблеме обновитесь до него.

| Версия | Поддержка |
| --- | --- |
| Последний релиз | ✅ |
| Более старые | ❌ |

## Как сообщить об уязвимости

Сообщайте об уязвимостях приватно через GitHub: вкладка **Security** репозитория → **[Report a vulnerability](https://github.com/Mahiron-hq/2048/security/advisories/new)**. Пожалуйста, не открывайте публичный issue по вопросам безопасности.

Полезный отчёт содержит затронутую версию и платформу, шаги воспроизведения и описание того, чего может добиться атакующий.

Ответ придёт в течение 7 дней. После подтверждения исправление выйдет как можно скорее, а advisory будет опубликован с благодарностью автору отчёта, если он не пожелает остаться анонимным.

## Область действия

2048 Merge — офлайн-игра: в ней нет аккаунтов, сетевого кода и аналитики, а из разрешений она запрашивает только вибрацию (см. [PRIVACY.md](PRIVACY.md)). Например, актуальны сообщения о том, что:

- специально созданный файл сохранения роняет игру или портит другие данные на устройстве;
- есть проблема в конвейере релизов (`.github/workflows`) или в подписи APK;
- подпись опубликованного APK не совпадает с сертификатом релизов ниже.

## Проверка загрузки

APK релизов собирает GitHub Actions из исходников тега; все actions в workflow закреплены на SHA коммитов, а бинарники Godot сверяются с опубликованными суммами SHA-512. К каждому релизу приложены:

- `SHA256SUMS.txt` — контрольные суммы APK: `sha256sum --check SHA256SUMS.txt`;
- подписанная аттестация происхождения сборки: `gh attestation verify <файл>.apk --repo Mahiron-hq/2048`;
- сертификат подписи релизов с отпечатком SHA-256
  `eb4210095c9919745312b83e94a3755767b764427c447b986c85e63479542fe0`:
  `apksigner verify --print-certs <файл>.apk`.
