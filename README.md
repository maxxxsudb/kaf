# Docker stdout → Kafka → Loki

`demo` пишет строку каждые пять секунд. Vector читает только его Docker stdout и отправляет JSON-события в Kafka. Alloy читает топик `demo-logs` и передаёт записи в Loki. Тот же Vector автоматически собирает метрики ноды и cgroups и отправляет их в `demo-metrics-otlp` в формате OTLP protobuf. Alloy читает этот топик и пишет в Mimir через remote write. Из изолированной среды наружу нужен только доступ к Kafka; в Kubernetes вместо `docker_logs` используется источник логов подов.

Используется обнаруженная на этом компьютере версия Grafana `13.2.2`. Запуск:

```sh
docker compose -p kafka-log-demo -f compose.yaml -f compose.grafana.yaml up -d
```

Если Grafana уже работает и видит Loki, второй Compose-файл не нужен: добавьте источник Loki с URL `http://loki:3100` в общей Docker-сети либо с адресом опубликованного порта на хосте.

Проверка логов: откройте `http://127.0.0.1:3000` (первый вход `admin` / `admin`), в Grafana Explore выберите Loki и запрос `{job="demo",pipeline="kafka"} |= "log-emitter-demo"`. Тело записи — JSON от Vector с полем `message`, содержащим `demo event=...`.

Проверка метрик: в Grafana Explore выберите Mimir и запрос `demo_load1` или `demo_cgroup_memory_current_bytes`. Можно проверить напрямую: `http://127.0.0.1:9009/prometheus/api/v1/query?query=demo_load1`. Метрики приложения без его участия доступны на уровне контейнера/cgroup; бизнес-метрик, которых приложение не публикует, здесь нет.

Для проверки топиков: `docker compose -p kafka-log-demo -f compose.yaml -f compose.grafana.yaml exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --list`.


В Kubernetes чарт `helm/telemetry-kafka` разворачивает только Vector. По умолчанию DaemonSet работает на всех разрешённых обычных нодах, собирает логи всех подов и метрики нод и контейнеров, затем отправляет их во внешнюю Kafka. Адрес брокера с портом и топики задаются в `values.yaml`. Loki, Mimir, Alloy и Grafana в Kubernetes этим чартом не устанавливаются. Формат и разрешения доступа к kubelet/cAdvisor для метрик подов надо проверить в конкретном кластере.

