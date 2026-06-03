module Openai
  class ChatClient
    def self.build(access_token: ENV["OPENAI_API_KEY"].presence)
      raise ArgumentError, "OPENAI_API_KEY is not configured" if access_token.blank?

      new(access_token: access_token)
    end

    def initialize(access_token:, client: nil)
      @access_token = access_token
      @client = client
    end

    def chat(parameters:)
      openai_client.chat(parameters: parameters)
    end

    private

    def openai_client
      @client ||= ::OpenAI::Client.new(access_token: @access_token)
    end
  end
end
