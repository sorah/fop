require 'json'
require 'nokogiri'
require 'uri'
require 'open-uri'
require 'net/http'
require 'net/https'

module Fop
  module StringIntoCode
    def to_s
      code
    end
  end

  Airport = Struct.new(:code, :area, :name)
  Status = Struct.new(:code, :name)
  CardType = Struct.new(:code, :name)
  Fare = Struct.new(:code, :name, :remark)
  SeatClass = Struct.new(:code, :name)

  [Airport, Status, CardType, Fare, SeatClass].each do |k|
    k.class_eval do
      include StringIntoCode
    end
  end

  Result = Struct.new(:miles, :fop, :flight_miles, :flight_miles_remark, :standard_flight_miles, :bonus_miles, :bonus_miles_remark, :fop_rate, :fop_bonus, :fop_bonus_remark)

  class Error < StandardError; end
  class DataParseError < Error; end
  class InvalidAirport < Error; end

  ENDPOINT_URI = URI("https://www.jal.co.jp/cgi-bin/jal/milesearch/save/flt_mile_save.cgi")
  DATA_JS_URI = URI("https://www.jal.co.jp/jmb/milesearch/js/mile_search_jp.js")

  class Client
    def initialize()
    end

    def dom_search(from:, to:, class:, fare:, card: '-', status: '-')
      klass = binding.local_variable_get(:class)

      unless valid_dom_airports.any?{ |_| _.code == from.to_s }
        raise InvalidAirport, "#{from.inspect} is invalid airport"
      end
      unless valid_dom_airports.any?{ |_| _.code == to.to_s }
        raise InvalidAirport, "#{to.inspect} is invalid airport"
      end

      page = post_form(
        cmd: 'do_search',
        TYPE: 'D',
        external: '',
        CityFrom: from.to_s,
        CityTo: to.to_s,
        F_CLASS: klass.to_s,
        F_JAL_CARD: card.to_s,
        F_JAL_CARD_STATUS: status.to_s,
        F_FARE: fare.to_s,
      )
      parse_result(page.at('#contentDom'))
    end

    def intl_search(from:, to:, fare:, card: '-', status: '-')
      from_airport = valid_intl_airports_for_earning.find{ |_| _.code == from.to_s }
      to_airport = valid_intl_airports_for_earning.find{ |_| _.code == to.to_s }
      unless from_airport
        raise InvalidAirport, "#{from.inspect} is invalid airport"
      end
      unless to_airport
        raise InvalidAirport, "#{to.inspect} is invalid airport"
      end

      page = post_form(
        cmd: 'do_search',
        TYPE: 'I',
        external: '',
        AreaFrom: from_airport.area,
        AreaTo: to_airport.area,
        CityFrom: from_airport.code,
        CityTo: to_airport.code,
        F_JAL_CARD: card.to_s,
        F_JAL_CARD_STATUS: status.to_s,
        F_FARE: fare.to_s,
      )
      parse_result(page.at('#contentInt'))
    end

    def parse_result(page)
      miles, fop = page.search('.milecount').map{ |_| _.inner_text.strip.gsub(/,/, '').to_i }
      standard_flight_miles = page.search('.milecount')[0].parent.children[1].inner_text.gsub(/[^\d]+/,'').to_i

      miles_breakdown, fop_breakdown = page.search('.Flightmilebns').map do |elem|
        elem.search('.FlightmilebnsItem').reject{ |_| _['class'].include?('Mark') }
      end

      flight_miles_elem = miles_breakdown[0]
      flight_miles = flight_miles_elem.at('.FlightmilebnsNum').inner_text.strip.gsub(/,/, '').to_i
      flight_miles_remark = flight_miles_elem.at('.FlightmilebnsTitle').inner_text.gsub(/\s+|\r?\n/, ' ')

      bonus_miles_elem = miles_breakdown[1]
      if bonus_miles_elem
        bonus_miles = bonus_miles_elem.at('.FlightmilebnsNum').inner_text.strip.gsub(/,/, '').to_i
        bonus_miles_remark = bonus_miles_elem.at('.FlightmilebnsTitle').inner_text.gsub(/\s+|\r?\n/, ' ')
      end

      fop_rate_elem = fop_breakdown[1]
      fop_rate = fop_rate_elem.at('.FlightmilebnsNum').inner_text.strip.gsub(/,/, '').to_f

      fop_bonus_elem = fop_breakdown[2]
      if fop_bonus_elem
        fop_bonus = fop_bonus_elem.at('.FlightmilebnsNum').inner_text.strip.gsub(/,/, '').to_i
        fop_bonus_remark = fop_bonus_elem.at('.FlightmilebnsTitle').inner_text.gsub(/\s+|\r?\n/, ' ')
      end

      Result.new(miles, fop, flight_miles, flight_miles_remark, standard_flight_miles, bonus_miles, bonus_miles_remark, fop_rate, fop_bonus, fop_bonus_remark)
    end

    def valid_cards
      @valid_card_types ||= form_page.search('#intCardtype option').map do |option|
        CardType.new(option['value'], option.inner_text.strip)
      end
    end

    def valid_statuses
      @valid_statuses ||= parse_data_js("status_hash").fetch('g_club').map do |(name, code)|
        Status.new(code.to_s, name)
      end
    end

    def valid_intl_airports_for_earning
      @valid_airports_for_earning ||= parse_data_js("save_city_hash").flat_map do |area, airports|
        airports.map do |(name, code)|
          Airport.new(code, area, name)
        end
      end
    end

    def valid_dom_airports
      @valid_dom_airports ||= parse_data_js("dom_city").map do |(name, code)|
        Airport.new(code, nil, name)
      end
    end

    def valid_dom_classes
      @valid_dom_classes ||+ form_page.search('#domClass option').map do |option|
        SeatClass.new(option['value'], option.inner_text.strip)
      end
    end

    def valid_dom_fares
      @valid_dom_fares ||= begin
         feelist = form_page.search('.feelist')[0].search('tr').map do |tr|
           tr.search('td').map(&:inner_text).map(&:strip)
         end.reject(&:empty?).to_h

         form_page.search('#domFare option').map do |option|
           name = option.inner_text.strip
           remark = feelist[name]
           Fare.new(option['value'], name, remark)
         end
       end
    end

    def valid_intl_fares
      @valid_intl_fares ||= begin
         feelist = form_page.search('.feelist')[1].search('tr').map do |tr|
           tr.search('td').map(&:inner_text).map(&:strip)
         end.reject(&:empty?).to_h

         form_page.search('#intFare option').map do |option|
           name = option.inner_text.strip
           remark = feelist[name]
           Fare.new(option['value'], name, remark)
         end
       end
    end


    def parse_data_js(variable)
      m = data_js.match(/^var #{Regexp.escape(variable)} = (.+?\r?\n[\]}]);$/m)
      raise DataParseError, "Failed to extract #{variable.inspect} from data_js" unless m
      js = m[1]
      json_like = js.
        gsub(/^\s*"(.+?)"\s*:|^\s*([^"].+?[^"])\s*:/,'"\1" :')
      JSON.parse json_like
    rescue JSON::ParserError
      raise DataParseError, "Failed to parse #{variable.inspect} from data_js"
    end

    def post_form(data)
      Nokogiri::HTML(Net::HTTP.post_form(ENDPOINT_URI, data).tap(&:value).body.encode("UTF-8", "Shift_JIS"))
    end

    def form_page
      @form_page ||= Nokogiri::HTML(open(ENDPOINT_URI, 'r', &:read).encode("UTF-8", "Shift_JIS"))
    end

    def data_js
      @data_js ||= open(DATA_JS_URI, 'r', &:read).encode("UTF-8", "Shift_JIS")
    end
  end
end
