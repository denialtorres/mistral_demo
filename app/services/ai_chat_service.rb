class AiChatService
  URL = URI("http://localhost:11434/api/generate")

  def initialize(session_id, prompt)
    @session_id = session_id
    @prompt = prompt
    @rand = SecureRandom.hex(10)
  end

  def call
    request = Net::HTTP::Post.new(URL, "Content-Type" => "application/json")
    request.body = {
      model: "mistral:latest",
      prompt: context,
      temperature: 1,
      stream: true
    }.to_json

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

  def context
    "[INST]#{@prompt}[/INST]"
  end

  def message_div
    <<~HTML
      <div id='#{@rand}'
        data-controller='markdown-text'
        data-markdown-text-update-value=''
        class='bg-primary-subtle p-2 rounded-lg mb-2 rounded'></div>
    HTML
  end

  def broadcast_message(target, message)
    Turbo::StreamsChannel.broadcast_append_to @session_id, target: target, html: message
  end

  def process_chunk(chunk)
    json = JSON.parse(chunk)
    done = json["done"]
    message = json["response"].to_s.strip.size.zero? ? "<br>" : json["response"]
    if done
      message = "<script>document.getElementById('#{@rand}').dataset.markdownTextUpdatedValue = '#{Time.current.to_f}';</script>"
      broadcast_message(@rand, message)
    else
      broadcast_message(@rand, message)
    end
  end
end
