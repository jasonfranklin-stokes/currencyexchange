# CurrencyExchangeJfsRc
require 'open-uri'

  module RailsConnection
    module CurrencyExchange

####################### ACTMETHODS

       module ActMethods

          def save_rate_and_time(a_rate,a_date)
              self.rate = a_rate.to_f
              self.issued_on=a_date
              self.save
          end
        
       end
    end
  end
           
 ####################################
 #
 ####################################
    
class CurrencyExchange 

     NOT_POSSIBLE ="CURRENCY CONVERSION NOT POSSIBLE"

     def self.currency_exchange(amount, currency, with_base_currency="EUR")
          if ( (@currency=currency_rate_exists?(currency)).nil? || (@base_currency=currency_rate_exists?(with_base_currency)).nil? )  then
             raise(NOT_POSSIBLE+" #{currency[0..2]} AND #{with_base_currency[0..2]}")
          else
             newest_currency_rates?(@currency,@base_currency,Time.now.utc)
             convert(@currency,@base_currency,amount)
          end
     end

     def self.currency_rate_exists?(currency)
       if (rate=ExchangeRate.find_by_currency(currency[0..2])).nil? then
         if ExchangeRate.find(:all).size == 0 then
           if ExchangeRateParser.request_rates(ExchangeRateParser.request_url_name).nil? then ExchangeRateParser.request_rates(ExchangeRateParser.request_file_name) end
         end
         rate=ExchangeRate.find_by_currency(currency[0..2])
       end
       rate
     end

     #private

     def self.newest_currency_rates?(currency,base_currency, time_now)
       if (time_now.wday != 6 && time_now.wday != 0) && (time_now.wday > currency.issued_on.wday || time_now.wday > base_currency.issued_on.wday) then ExchangeRateParser.request_rates(ExchangeRateParser.request_url_name) end
     end

     def self.convert(from_currency,to_currency,amount)
         ((amount / from_currency.rate) * to_currency.rate).to_i
     end

 end
     
 ####################################
 #
 ####################################

  class ExchangeRateParser

      XML_CURRENCY_URL = 'http://www.ecb.int/stats/eurofxref/eurofxref-daily.xml'
      XML_CURRENCY_FILE = File.dirname(__FILE__) + '/offline_exchange_rates.xml'
      
      def self.request_rates(path)
         (xml = self.read_url_io(path) ) ? self.parse_rates_for_currency(xml) : nil
      end

      #private

      def self.request_url_name
        XML_CURRENCY_URL
      end

      def self.request_file_name
        XML_CURRENCY_FILE
      end
      
      def self.parse_rates_for_currency(xml)
          xml.elements.each("//Cube") do |item|
              if item.attributes["time"]
                 @a_date=xml_date(item.attributes["time"].to_s)
                  ptr=ExchangeRate.find_or_create_by_base_currency_and_currency(:base_currency=>"EUR",:currency=>"EUR")
                  ptr.save_rate_and_time(1.0,@a_date)
              end
              if item.attributes["currency"]
                  ptr=ExchangeRate.find_or_create_by_base_currency_and_currency("EUR",item.attributes["currency"])
                  ptr.save_rate_and_time((item.attributes["rate"]).to_s.to_f,@a_date)
              end
         end
      end
      
      def self.xml_date(a_date)
        res=ParseDate.parsedate(a_date)
        Time.local(*res)
      end

      def self.read_url_io(url)
         begin REXML::Document.new(open(url) { |f| f.readlines.join("\n") }) rescue nil end
       end
      
  end
