require "net/http"
require "json"

module ForexFactory
  class CalendarClient
    class FetchError < StandardError; end

    DEFAULT_URL = "https://nfs.faireconomy.media/ff_calendar_thisweek.json"

    def initialize(url: ENV.fetch("FOREXFACTORY_CALENDAR_URL", DEFAULT_URL))
      @url = url
    end

    def fetch
      response = request_calendar
      raise FetchError, "ForexFactory calendar returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      payload = JSON.parse(response.body)
      raise FetchError, "ForexFactory calendar payload was not an array" unless payload.is_a?(Array)

      payload
    end

    private

    def request_calendar
      uri = URI(@url)
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: 5,
        read_timeout: 10
      ) do |http|
        http.get(uri.request_uri)
      end
    end
  end
end
