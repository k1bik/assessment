# typed: false

module Telegram
  module WebhooksHelper
    MAX_BUTTON_IN_ROW = 5
    PER_PAGE = 10
    DEFAULT_PAGE = 1
    NEXT_PAGE_EMOJI = "➡️"
    PREV_PAGE_EMOJI = "⬅️"

    SWITCH_PAGE_CALLBACK_KEY = "switch_page"
    WINERY_SELECTION_CALLBACK_KEY = "winery_selection"
    SWITCH_WINERY_CALLBACK_KEY = "switch_winery"

    TANK_ID_PATTERN = /^\d+$/

    def tank_info_message(tank:, prefix:)
      current_temp = tank.temperature_control_plugin&.temperature_sensor_value
      current_temp = sign_prefix(current_temp.to_f) if current_temp

      <<~TEXT
        #{prefix}

        🛢️ #{I18n.t("telegram.tank")}: #{tank.name}
        🍷 #{I18n.t("telegram.batch")}: #{tank&.batch&.batch_number}
        🌡️ #{I18n.t("telegram.temperature")}: #{current_temp}
      TEXT
    end

    def tank_number_buttons(tank_data, pagy_object)
      result = tank_data.map { |tank| {text: tank[:number].to_s, callback_data: tank[:id].to_s} }

      result = if tank_data.size > MAX_BUTTON_IN_ROW
        result.each_slice(MAX_BUTTON_IN_ROW).to_a
      else
        [result]
      end

      if pagy_object.prev && pagy_object.next
        result.push(
          [
            {text: PREV_PAGE_EMOJI, callback_data: "#{SWITCH_PAGE_CALLBACK_KEY}:#{PREV_PAGE_EMOJI}"},
            {text: NEXT_PAGE_EMOJI, callback_data: "#{SWITCH_PAGE_CALLBACK_KEY}:#{NEXT_PAGE_EMOJI}"}
          ]
        )

        return result
      end

      if pagy_object.prev
        result.push(
          [
            {
              text: PREV_PAGE_EMOJI,
              callback_data: "#{SWITCH_PAGE_CALLBACK_KEY}:#{PREV_PAGE_EMOJI}"
            }
          ]
        )
      end

      if pagy_object.next
        result.push(
          [
            {
              text: NEXT_PAGE_EMOJI,
              callback_data: "#{SWITCH_PAGE_CALLBACK_KEY}:#{NEXT_PAGE_EMOJI}"
            }
          ]
        )
      end

      result
    end

    def tanks_page(tanks, pagy_object)
      tanks.map.with_index(1) do |tank, index|
        {
          id: tank.id,
          number: index,
          name: tank.name,
          current_temp: tank.temperature_control_plugin&.temperature_sensor_value
        }
      end
    end

    def formatted_tank_list(tanks)
      result = tanks.map do |tank|
        current_temp = sign_prefix(tank[:current_temp]) if tank[:current_temp]

        "#{tank[:number]}. #{tank[:name]} #{current_temp}"
      end

      result.join("\n")
    end

    private

    def sign_prefix(temp)
      return unless temp

      "#{temp.to_i.positive? ? "+" : ""}#{temp}°С"
    end
  end
end
