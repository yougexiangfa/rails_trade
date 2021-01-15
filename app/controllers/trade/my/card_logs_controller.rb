module Trade
  class My::CardLogsController < My::BaseController

    def index
      @card_logs = @card.card_logs.page(params[:page])
    end

    def set_card
      @card = Card.find params[:card_id]
    end

  end
end
