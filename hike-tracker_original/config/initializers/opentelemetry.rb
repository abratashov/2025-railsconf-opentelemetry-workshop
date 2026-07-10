require 'pyroscope'

APP_NAME = "hike-tracker"
# PYROSCOPE_ENDPOINT = "http://pyroscope:4040" # Docker env
PYROSCOPE_ENDPOINT = "http://localhost:4040" # Dev env

# Exporting to New Relic
ENV['NEW_RELIC_LICENSE_KEY'] = 'eu01x03...'

ENV['OTEL_SERVICE_NAME'] = 'test-rails-app'
ENV['OTEL_RESOURCE_ATTRIBUTES'] = 'service.instance.id=123'
ENV["OTEL_EXPORTER_OTLP_ENDPOINT"] = "http://localhost:4318" # to export to collector & plain file
# ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'https://otlp.eu01.nr-data.net'
# ENV['OTEL_EXPORTER_OTLP_HEADERS'] = "api-key=#{ENV['NEW_RELIC_LICENSE_KEY']}"
ENV['OTEL_EXPORTER_OTLP_COMPRESSION'] = 'gzip'
ENV['OTEL_EXPORTER_OTLP_PROTOCOL'] = 'http/protobuf'
ENV['OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT'] = '4095'

# Metrics
ENV["OTEL_METRIC_EXPORT_INTERVAL"] = "3000" # 3 sec * 100 ms

# Add console exporter
ENV['OTEL_TRACES_EXPORTER'] = 'console,otlp'

# Logs
ENV["OTEL_LOGS_EXPORTER"] = "otlp"

Pyroscope.configure do |config|
  config.application_name = APP_NAME
  config.server_address = PYROSCOPE_ENDPOINT
  config.autoinstrument_rails = true
end

# Configure the SDK
OpenTelemetry::SDK.configure do |config|
  config.service_name = APP_NAME
  config.service_version = "1.0.0"

  # ---------------- BUG: this line breaks Open Telemetry logic (https://github.com/grafana/otel-profiling-ruby/issues/44)
  # config.add_span_processor(Pyroscope::Otel::SpanProcessor.new("#{APP_NAME}.cpu", PYROSCOPE_ENDPOINT))
  # ---------------

  # Installs instrumentation for all available libraries
  config.use_all({
    "OpenTelemetry::Instrumentation::Rack" => {
      allowed_response_headers: [ "Content-Type" ]
    }
  })

  # Can also install instrumentation this library by library, for example:
  # config.use 'OpenTelemetry::Instrumentation::Rack', { allowed_request_headers: ['Host', 'Referer']}
  # config.use 'OpenTelemetry::Instrumentation::Rails'
end

# Create a tracer specific to this application to create spans/traces
APP_TRACER = OpenTelemetry.tracer_provider.tracer(APP_NAME)

# Create a meter for this application to record metrics
meter = OpenTelemetry.meter_provider.meter(APP_NAME)

# Save the counter as a constant to access it outside the initializer
HIKE_COUNTER = meter.create_counter("activities.completed", unit: "activity", description: "Number of activities completed")

# Create a histogram with a view
explicit_boundaries = [ 0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1, 2.5, 5, 7.5, 10 ]

OpenTelemetry.meter_provider.add_view("http.server.request.duration",
  type: :histogram,
  aggregation: OpenTelemetry::SDK::Metrics::Aggregation::ExplicitBucketHistogram.new(
    boundaries: explicit_boundaries
  )
)

duration_histogram = meter.create_histogram("http.server.request.duration", unit: "ms", description: "Duration of HTTP server requests.")

exception_counter = meter.create_counter("application_exceptions_total", description: "Application exceptions")

# Subscribe to an ActiveSupport notification to add a metric defined by Semantic Conventions that's not recorded by instrumentation yet
ActiveSupport::Notifications.subscribe "process_action.action_controller" do |event|
  payload = event.payload
  server_protocol = payload[:headers]["SERVER_PROTOCOL"].split("/")
  attributes = {
    "controller.action" => "#{payload[:controller]}##{payload[:action]}",
    "http.request.method" => payload[:method],
    # 'url.scheme' => ,
    # 'error.type' => ,
    "http.response.status.code" => payload[:status],
    "http.route" => payload[:path],
    "network.protocol.name" => server_protocol[0],
    "network.protocol.version" => server_protocol[1],
    "server.address" => payload[:headers]["Host"],
    "server.port" => payload[:headers]["SERVER_PORT"]
  }

  duration_histogram.record(event.duration, attributes: attributes)

  # attributes["error.type"] = payload[:exception_object].class.name if payload[:exception_object]
  # attributes["error.type"] = payload[:exception].first if attributes["error.type"].blank? && payload[:exception]

  next unless payload[:exception_object]

  exception_counter.add(
    1,
    attributes: {
      "exception.type" => payload[:exception_object].class.name,
      "controller.action" => "#{payload[:controller]}##{payload[:action]}"
    }
  )
end

# Other Notifications

# Action Controller
#   process_action.action_controller
#   redirect_to.action_controller
#   send_data.action_controller
#   send_file.action_controller
#   start_processing.action_controller

# Active Record
#   instantiation.active_record
#   sql.active_record
#   transaction.active_record

# Cache
#   cache_delete.active_support
#   cache_exist?.active_support
#   cache_fetch_hit.active_support
#   cache_read.active_support
#   cache_write.active_support

# Action View
#   render_collection.action_view
#   render_partial.action_view
#   render_template.action_view

# Action Mailer
#   deliver.action_mailer
#   process.action_mailer

# Active Job
#   discard.active_job
#   enqueue.active_job
#   enqueue_at.active_job
#   perform.active_job
#   retry_stopped.active_job

# Action Cable
#   perform_action.action_cable
#   transmit.action_cable

# Action Dispatch
#   request.action_dispatch

# Action Storage
#   service_delete.active_storage
#   service_download.active_storage
#   service_upload.active_storage
#   service_url.active_storage

# ActiveSupport::Notifications.subscribe(/action_controller|active_record/) do |*args|
#   event = ActiveSupport::Notifications::Event.new(*args)
#   Rails.logger.info(event.name)
# end

