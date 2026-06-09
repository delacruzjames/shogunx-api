module OpenaiTestHelpers
  def openai_chat_client(content:)
    response = {
      "choices" => [
        { "message" => { "content" => content } }
      ]
    }

    instance_double(Openai::ChatClient, chat: response)
  end

  def openai_json_response(action:, confidence:, timeframe: "H1", reason: "Mocked OpenAI analysis")
    openai_chat_client(
      content: {
        action: action,
        confidence: confidence,
        timeframe: timeframe,
        reason: reason
      }.to_json
    )
  end

  def stub_default_openai_buy(confidence: 80)
    allow(Openai::ChatClient).to receive(:build).and_return(
      openai_json_response(
        action: "BUY",
        confidence: confidence,
        reason: "Bullish trend with supportive momentum"
      )
    )
  end

  def stub_openai_wait(reason: "No clear setup")
    allow(Openai::ChatClient).to receive(:build).and_return(
      openai_json_response(action: "WAIT", confidence: 0, reason: reason)
    )
  end
end
