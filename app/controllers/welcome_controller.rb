class WelcomeController < ApplicationController
  def index
    @history = History.where(session_id: request.session.id.to_s).last(50)
  end
end
