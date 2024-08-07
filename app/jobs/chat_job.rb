class ChatJob < ApplicationJob
  queue_as :default

  def perform(session_id, prompt)
    AiChatService.new(session_id, prompt).call
  end
end
