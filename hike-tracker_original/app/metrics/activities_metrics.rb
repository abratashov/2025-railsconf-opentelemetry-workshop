module ActivitiesMetrics
  METER = OpenTelemetry.meter_provider.meter("activities")

  RECORDS_TOTAL = METER.create_counter(
    "activities_total"
  )

  SAVED = METER.create_counter(
    "activities_saved_total",
    description: "Successfully completed activities"
  )

  WATCHED = METER.create_counter(
    "activities_watched_total",
    description: "Watched activities"
  )

  def self.records_total
    RECORDS_TOTAL
  end

  def self.saved
    SAVED
  end

  def self.watched
    WATCHED
  end
end
