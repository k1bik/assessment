# typed: false

module Telegram
  class WebhooksController < BaseWebhooksController
    include Pagy::Backend

    def start!(*)
      return unless authenticated?

      respond_with :message, text: t("telegram.start")
    end

    def search!(*search_string)
      return unless authenticated?

      if search_string.any?
        scope = winery_context
          .winery
          .tanks
          .includes(:batch)
          .kept
          .search(search_string.join(" "))
          .order(:name)

        pagy_object, tanks = pagy(scope, items: PER_PAGE, page: DEFAULT_PAGE)

        if tanks.present?
          tanks.one? ? display_tank_info(tank: tanks.first) : render_tanks_list(tanks:, pagy_object:)
        else
          respond_with :message, text: t("telegram.search_not_found")
          save_context :search!
        end
      else
        respond_with :message, text: t("telegram.search")
        save_context :search!
      end
    end

    def switch_winery!(*)
      return unless authenticated?

      telegram_account = Account.includes(user: :wineries).kept.find_by!(chat_id: chat["id"])
      wineries = telegram_account.user.wineries.kept

      if wineries.one?
        respond_with :message, text: t("telegram.one_available_winery", winery: wineries.first.name)
      else
        respond_with :message,
          text: t("telegram.available_wineries_list"),
          reply_markup: {
            inline_keyboard: wineries.map do |winery|
              [{text: winery.name, callback_data: "#{SWITCH_WINERY_CALLBACK_KEY}:#{winery.id}"}]
            end
          }
      end
    end

    def list!(*)
      return unless authenticated?

      scope = winery_context.winery.tanks.includes(:batch).order(:name)
      pagy_object, tanks = pagy(scope, items: PER_PAGE, page: DEFAULT_PAGE)

      render_tanks_list(tanks:, pagy_object:)
    end

    def switch_page_callback_query(direction)
      return unless authenticated?

      current_page = session.delete(:current_page)
      return if current_page.nil?

      scope = winery_context.winery.tanks.order(name: :asc)
      page = (direction == NEXT_PAGE_EMOJI) ? (current_page.next) : (current_page.pred)
      pagy_obj, tanks = pagy(scope, page:, items: PER_PAGE)
      tank_data = tanks_page(tanks, pagy_obj)

      session[:tanks_page] = tank_data
      session[:current_page] = pagy_obj.page

      respond_with :message,
        text: formatted_tank_list(tank_data),
        reply_markup: {
          inline_keyboard: tank_number_buttons(tank_data, pagy_obj)
        }
    end

    def callback_query(tank_id)
      return unless authenticated?

      tank = winery_context.winery.tanks.includes(:batch).find(tank_id)
      display_tank_info(tank:)
    end

    def switch_winery_callback_query(id)
      return unless authenticated?

      account = Account.find_by!(chat_id: chat["id"])
      account.update!(winery_id: id)
      winery = Winery.find id

      respond_with :message, text: t("telegram.authorization_success", winery: winery.name)
    end

    def winery_selection_callback_query(id)
      user_id = session.delete(:user_id)

      if user_id
        winery = Winery.kept.find(id)
        user = winery.users.kept.find(user_id)
        Account.create!(chat_id: chat["id"], user:, winery:)

        respond_with :message,
          text: t("telegram.authorization_success", winery: winery.name),
          reply_markup: {remove_keyboard: true}
      end
    end

    private

    def render_tanks_list(tanks:, pagy_object:)
      if tanks.empty?
        respond_with :message, text: t("telegram.no_tanks")
        return
      end

      tank_data = tanks_page(tanks, pagy_object)

      session[:tanks_page] = tank_data
      session[:current_page] = pagy_object.page

      respond_with :message,
        text: formatted_tank_list(tank_data),
        reply_markup: {
          inline_keyboard: tank_number_buttons(tank_data, pagy_object)
        }
    end

    def display_tank_info(tank:, prefix: nil)
      respond_with :message, text: tank_info_message(tank:, prefix:)
    end
  end
end
