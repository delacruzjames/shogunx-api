# Be sure to restart your server when you modify this file.

# Allow the Next.js dashboard (different port) to call API endpoints from the browser.
# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins lambda { |source, _env|
      allowed = ENV.fetch("CORS_ORIGINS", "").split(",").map(&:strip).reject(&:blank?)
      if allowed.any?
        allowed.include?(source)
      elsif Rails.env.production?
        false
      else
        source.present? && source.match?(/\Ahttp:\/\/(localhost|127\.0\.0\.1)(:\d+)?\z/)
      end
    }

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head]
  end
end
