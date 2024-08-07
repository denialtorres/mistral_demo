require 'net/http'

class AiChatService
  URL = URI("http://localhost:11434/api/chat")

  def initialize(session_id, prompt)
    @session_id = session_id
    @prompt = prompt
    @rand = SecureRandom.hex(10)
  end

  def call
    request = Net::HTTP::Post.new(URL, "Content-Type" => "application/json")
    request.body = {
      model: "mistral:latest",
      messages: messages,
      temperature: 1,
      stream: true
    }.to_json

    broadcast_message("messages", my_prompt_div)

    Net::HTTP.start(URL.hostname, URL.port) do |http|
      # 1. broadcast initial frame
      # 2. request to ollama
      #  - receive chunks
      #  - broadcast the chunks to the browser

      broadcast_message("messages", message_div)

      http.request(request) do |response|
        response.read_body do |chunk|
          process_chunk(chunk)
        end
      end
    end
  end

  private

  def messages
    array = []
    History.where(session_id: @session_id).last(50).each do |history|
      array << { role: "user", content: history.prompt }
      array << { role: "assistant", content: history.response }
    end

    array <<  { role: "user", content: @prompt }
    array
  end

  def my_prompt_div
    <<~HTML
      <div data-controller='markdown-text'
        data-markdown-text-update-value=''
        class='bg-success-subtle ms-5 p-2 rounded-lg mb-2 rounded'>#{@prompt}</div>
    HTML
  end

  def message_div
    <<~HTML
      <div id='#{@rand}'
        data-controller='markdown-text'
        data-markdown-text-update-value=''
        class='bg-primary-subtle me-5 p-2 rounded-lg mb-2 rounded'></div>
    HTML
  end

  def broadcast_message(target, message)
    Turbo::StreamsChannel.broadcast_append_to @session_id, target: target, html: message
  end

  def process_chunk(chunk)
    @chunk_array ||= []
    json = JSON.parse(chunk)
    done = json["done"]
    message = json.dig("message", "content").to_s.strip.size.zero? ? "<br>" : json.dig("message", "content")
    if done
      History.create(session_id: @session_id, prompt: @prompt, response: @chunk_array.join())
      message = "<script>document.getElementById('#{@rand}').dataset.markdownTextUpdatedValue = '#{Time.current.to_f}';</script>"
      broadcast_message(@rand, message)
    else
      @chunk_array << message
      broadcast_message(@rand, message)
    end
  end
end
