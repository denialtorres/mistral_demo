class ChatsController < ApplicationController
  def create
    ChatJob.perform_later(request.session.id.to_s, params[:message])

    render turbo_stream: turbo_stream.replace("chat_form", partial: "welcome/form")
  end
end
