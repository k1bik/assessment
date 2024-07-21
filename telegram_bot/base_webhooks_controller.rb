# typed: false

module Telegram
  class BaseWebhooksController < Telegram::Bot::UpdatesController
    include Telegram::Bot::UpdatesController::MessageContext
    include Telegram::Bot::UpdatesController::CallbackQueryContext
    include WebhooksHelper

    class IncorrectFormat < StandardError; end

    rescue_from IncorrectFormat, ActiveRecord::RecordInvalid do |exception|
      respond_with :message, text: "#{t("telegram.error_prefix")} \n\n#{exception.message}"
    end

    def authenticate(*)
      phone_number = payload.dig("contact", "phone_number")
      text = payload.dig("reply_to_message", "text")

      if phone_number && text == t("telegram.authentication_prompt")
        verify_user_phone(phone_number)
      else
        save_context :authenticate

        respond_with :message,
          text: t("telegram.authentication_prompt"),
          reply_markup: {
            keyboard: [[{text: t("telegram.send_phone_number_button"), request_contact: true}]],
            resize_keyboard: true,
            one_time_keyboard: true
          }
      end
    end

    def authenticated?
      account = Account.kept.find_by(chat_id: chat["id"])

      if account
        true
      else
        authenticate
        false
      end
    end

    def winery_context
      account = Account.kept.find_by!(chat_id: chat["id"])
      Iam::WineryContext.build(winery: account.winery, user: account.user)
    end

    private

    def verify_user_phone(phone_number)
      phone_number = PhoneFormatter.new.call(phone_number)
      user = ::User.kept.find_by("REGEXP_REPLACE(REGEXP_REPLACE(phone_number, '^\\+7', ''), '^8', '') = ?", phone_number)

      unless user
        respond_with :message, text: t("telegram.no_user")
        save_context :authenticate
        return
      end

      if user.wineries.one?
        winery = user.wineries.first
        Account.create!(chat_id: chat["id"], user:, winery:)

        respond_with :message,
          text: t("telegram.authorization_success", winery: winery.name),
          reply_markup: {remove_keyboard: true}
      else
        session[:user_id] = user.id

        respond_with :message,
          text: t("telegram.available_wineries_list"),
          reply_markup: {
            inline_keyboard: user.wineries.map do |winery|
              [{text: winery.name, callback_data: "#{WINERY_SELECTION_CALLBACK_KEY}:#{winery.id}"}]
            end
          }
      end
    end
  end
end
