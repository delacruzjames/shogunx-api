require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"
require "support/openai_helpers"

RSpec.configure do |config|
  config.include OpenaiTestHelpers

  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before do |example|
    next if example.metadata[:openai_live]

    ENV["OPENAI_API_KEY"] ||= "test-openai-key"
    stub_default_openai_buy
  end
end
