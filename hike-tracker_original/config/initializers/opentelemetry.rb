# Exporting to New Relic
ENV['NEW_RELIC_LICENSE_KEY'] = 'eu01x03...'

ENV['OTEL_SERVICE_NAME'] = 'test-rails-app'
ENV['OTEL_RESOURCE_ATTRIBUTES'] = 'service.instance.id=123'
ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'https://otlp.eu01.nr-data.net'
ENV['OTEL_EXPORTER_OTLP_HEADERS'] = "api-key=#{ENV['NEW_RELIC_LICENSE_KEY']}"
ENV['OTEL_EXPORTER_OTLP_COMPRESSION'] = 'gzip'
ENV['OTEL_EXPORTER_OTLP_PROTOCOL'] = 'http/protobuf'
ENV['OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT'] = '4095'

# Metrics
ENV["OTEL_METRIC_EXPORT_INTERVAL"] = "3000" # 3 sec * 100 ms

# Add console exporter
ENV['OTEL_TRACES_EXPORTER'] = 'console,otlp'

# Logs
ENV["OTEL_LOGS_EXPORTER"] = "otlp"

# Configure the SDK
OpenTelemetry::SDK.configure do |config|
  config.service_name = "hike-tracker"
  config.service_version = "1.0.0"

  # Installs instrumentation for all available libraries
  config.use_all({
    "OpenTelemetry::Instrumentation::Rack" => {
      allowed_response_headers: [ "Content-Type" ]
    }
  })

  # Can also install instrumentation this library by library, for example:
  # config.use 'OpenTelemetry::Instrumentation::Rack', { allowed_request_hedaers: ['Host', 'Referer']}
  # config.use 'OpenTelemetry::Instrumentation::Rails'
end

# Create a tracer specific to this application to create spans/traces
APP_TRACER = OpenTelemetry.tracer_provider.tracer("hike-tracker")

# Create a meter for this application to record metrics
meter = OpenTelemetry.meter_provider.meter("hike-tracker")

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
end
