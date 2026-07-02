# Rails Observability

## OpenTelemetry & NewRelic

* [2025-railsconf-opentelemetry-workshop](https://github.com/kaylareopelle/2025-railsconf-opentelemetry-workshop)
* [Video](https://www.youtube.com/watch?v=E_rKGBN_caQ&ab_channel=Confreaks)

### Setup

Generate license key for free account from [NewRelic](https://one.eu.newrelic.com) :
```sh
# https://one.eu.newrelic.com => User Profile => API Keys => Create key (based on Ingest License Key)
```

and set it here:
```sh
# config/initializers/opentelemetry.rb
ENV['NEW_RELIC_LICENSE_KEY'] = 'eu01x03...'
```

Run app:
```sh

cd hike-tracker_original

# Tab 1
rvm use 3.4.2
bundle
rails db:create
rails db:migrate
rails db:seed
rails s

# Tab 2
script/traffic.sh
```

Check New Relic Dashboard: `APM` / `Traces` / `Log` or run `NRQL`:
```sql
-- Overall traffic (is system alive?)
FROM Span SELECT rate(count(*), 1 minute) SINCE 30 minutes ago TIMESERIES

-- Latency (average response time): P95 latency (real user experience)
FROM Span SELECT percentile(duration.ms, 95) SINCE 30 minutes ago TIMESERIES

-- Slowest operations: “Where is time going?” (breakdown of latency): middleware cost, DB cost, external calls, controller cost
FROM Span SELECT average(duration.ms) FACET name SINCE 30 minutes ago LIMIT 10

-- Error rate: Top errors
FROM Span SELECT count(*) WHERE error.message IS NOT NULL FACET error.message SINCE 30 days ago LIMIT 10

-- Host-level & service-level breakdown: Service breakdown (web vs worker vs cron)
FROM Span SELECT rate(count(*), 1 minute) FACET process.command SINCE 30 minutes ago

-- DB performance (if ActiveRecord is instrumented): Slow database queries
FROM Span SELECT average(duration.ms) WHERE db.statement IS NOT NULL FACET db.statement SINCE 30 minutes ago LIMIT 10
```
