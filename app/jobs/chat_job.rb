require "net/http"

class ChatJob < ApplicationJob
  queue_as :default

  def perform(prompt)
    uri = URI("http://localhost:11434/api/generate")

    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request.body = {
      model: "mistral:latest",
      prompt: context(prompt),
      temperature: 1,
      stream: true
    }.to_json

    Net::HTTP.start(uri.hostname, uri.port) do |http|
      # 1. broadcast initial frame
      # 2. request to ollama
      #  - receive chunks
      #  - broadcast the chunks to the browser

      rand = SecureRandom.hex(10)

      broadcast_message("messages", message_div(rand))

      http.request(request) do |response|
        response.read_body do |chunk|
          process_chunk(chunk, rand)
        end
      end
    end
  end

  private

  def context(prompt)
    "[INST]#{prompt}[/INST]"
  end

  def message_div(rand)
    "<div id='#{rand}' class='bg-primary-subtle p2 rounded-lg mb-2 rounded'></div>"
  end

  def broadcast_message(target, message)
    Turbo::StreamsChannel.broadcast_append_to "welcome", target: target, html: message
  end

  def process_chunk(chunk, rand)
    json = JSON.parse(chunk)
    done = json["done"]
    message = json["response"].to_s.strip.size.zero? ? "<br>" : json["response"]

    if done
      message = "<script>document.getElementById('#{rand}').dataset.markdownTextUpdatedValue = '#{Time.current.to_f}';</script>"
      broadcast_message(rand, message)
    else
      broadcast_message(rand, message)
    end
  end
end
