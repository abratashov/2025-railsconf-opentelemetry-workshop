require "digest"
require "json"
require "securerandom"

class HeavyReportService
  ITERATIONS = 3_000
  ITEMS = 500

  def self.call
    new.call
  end

  def call
    result = []

    ITERATIONS.times do |i|
      data = generate_dataset(i)

      json = JSON.generate(data)
      parsed = JSON.parse(json)

      parsed.each do |row|
        row["name"] = normalize(row["name"])
        row["checksum"] = checksum(row)
      end

      parsed.sort_by! do |row|
        [
          row["checksum"],
          row["score"],
          row["name"]
        ]
      end

      result << parsed.first
    end

    result
  end

  private

  def generate_dataset(seed)
    ITEMS.times.map do |i|
      {
        id: i,
        name: "User #{seed}-#{i} Example Name #{rand(10000)}",
        score: rand(1_000_000),
        description: "Lorem ipsum dolor sit amet " * 10,
        tags: Array.new(20) { SecureRandom.hex(16) }
      }
    end
  end

  def normalize(text)
    text
      .downcase
      .gsub(/[aeiou]/, "*")
      .gsub(/\s+/, " ")
      .strip
      .reverse
  end

  def checksum(row)
    Digest::SHA256.hexdigest(
      "#{row["id"]}-#{row["name"]}-#{row["description"]}-#{row["score"]}"
    )
  end
end

HeavyReportService.call
