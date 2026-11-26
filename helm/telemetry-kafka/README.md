# Сбор телеметрии Kubernetes в Kafka

Чарт разворачивает Vector DaemonSet. Он собирает stdout/stderr всех подов с каждой ноды, журналы служб ноды, метрики хоста и kubelet/cAdvisor, затем отправляет данные во внешнюю Kafka. Kafka, Loki, Mimir, Alloy и Grafana чарт не устанавливает. Внешние Helm-зависимости и архивы субчартов ему не нужны.

Скопируйте `values-example.yaml` и задайте:

- `cluster` — имя кластера в событиях;
- `kafka.brokers` — адрес Kafka в формате `host:port` или список `host1:port1,host2:port2`;
- `kafka.topics.podLogs`, `nodeLogs`, `metrics` — существующие топики для логов подов, журналов нод и метрик;
- `nodeSelector` — метки нужных нод. По умолчанию `{}`: DaemonSet запускается на всех нодах, допускающих обычные pod. Для tainted-нод настройте `tolerations`.

```sh
helm upgrade --install telemetry ./helm/telemetry-kafka \
  --namespace monitoring --create-namespace \
  -f ./helm/telemetry-kafka/values-example.yaml
```

Логи подов содержат `cluster`, `namespace`, `pod`, `node`, `application`. `application` берётся из аннотации `applicationAnnotation`, затем из метки `app.kubernetes.io/name`, затем из имени контейнера. Журналы нод идут в отдельный топик. Метрики отправляются в формате OTLP protobuf; для pod сохраняются метки `namespace`, `pod`, `container`, когда их предоставляет cAdvisor.

Vector читает `/var/log/pods`, `/proc`, `/sys` и journald на каждой ноде. Позиции чтения и дисковые буферы сохраняются в `/var/lib/<release>-vector`. Если журнал доступен только в `/run/log/journal`, задайте `nodeLogs.journalDirectory: /run/log/journal`.

Для kubelet `/metrics/cadvisor` требуется доступ к `status.hostIP:10250` и доверенный TLS-сертификат. При необходимости задайте `podMetrics.caSecretName`. Для защищённой Kafka доступны `kafka.tls.caSecretName` и `kafka.sasl.passwordSecretName`; секреты должны существовать в namespace релиза.

Проверка без кластера:

```sh
helm lint ./helm/telemetry-kafka -f ./helm/telemetry-kafka/values-example.yaml
helm template telemetry ./helm/telemetry-kafka -n monitoring -f ./helm/telemetry-kafka/values-example.yaml
```
