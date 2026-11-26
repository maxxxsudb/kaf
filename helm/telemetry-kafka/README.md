# Telemetry → Kafka для Kubernetes

Chart ставит один Vector DaemonSet на ноды, выбранные `nodeSelector`. Внешние Loki, Mimir и Grafana здесь не разворачиваются.

Перед установкой заполните `values.yaml` или сделайте копию `values-example.yaml`:

- `cluster`, `targetNamespace`, `applicationAnnotation` — метаданные событий;
- `nodeSelector` — метка только выделенных нод;
- `kafka.brokers` и `kafka.topics.*` — адрес брокеров и заранее созданные топики;
- `nodeLogs.units` — нужные systemd-службы;
- `podMetrics.caSecretName` — CA сертификат kubelet, если он не подписан CA service account.

```sh
helm upgrade --install telemetry ./helm/telemetry-kafka \
  --namespace monitoring --create-namespace \
  -f ./helm/telemetry-kafka/values-example.yaml
```

Vector читает stdout/stderr подов только из `targetNamespace`, обогащает записи `cluster`, `namespace`, `pod`, `node`, `application` и пишет JSON в `podLogs`. `application` берётся из аннотации `applicationAnnotation`, затем из pod label `app.kubernetes.io/name`, затем из имени контейнера. Логи служб ноды идут отдельно в `nodeLogs` с `cluster` и `node`; namespace у ноды нет.

Метрики ноды и kubelet `/metrics/cadvisor` отправляются в `metrics` в формате OTLP protobuf. Для метрик pod остаются `namespace`, `pod`, `container` из cAdvisor; chart отбрасывает метрики других namespace. `cluster` и `node` добавляются как теги. Аннотации pod в cAdvisor не поступают, поэтому `application` для метрик можно добавить только отдельным сопоставлением по данным Kubernetes API. Alloy за пределами кластера должен читать топик метрик через `otelcol.receiver.kafka` с `otlp_proto`, а топики логов — через `loki.source.kafka`.

DaemonSet имеет права `get/list/watch` на pod, namespace и node для обогащения логов, а также `get nodes/metrics` для kubelet. Ему нужны локальные чтения `/var/log/pods`, `/proc`, `/sys` и journald. Debian-вариант Vector используется потому, что в нём есть `journalctl`. Позиции чтения и дисковые буферы сохраняются в `/var/lib/<release>-vector` на каждой ноде.

Если на ноде журнал находится только в `/run/log/journal`, установите `nodeLogs.journalDirectory: /run/log/journal`. Kubelet должен быть доступен на `status.hostIP:10250`, а его сертификат должен проходить проверку TLS. Токен service account перечитывается Vector каждый час. При защищённой Kafka укажите `kafka.tls.caSecretName` и/или `kafka.sasl.passwordSecretName`; секреты должны существовать в namespace релиза.

Проверка шаблонов без кластера:

```sh
helm lint ./helm/telemetry-kafka -f ./helm/telemetry-kafka/values-example.yaml
helm template telemetry ./helm/telemetry-kafka -n monitoring -f ./helm/telemetry-kafka/values-example.yaml
```
