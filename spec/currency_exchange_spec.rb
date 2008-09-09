

require File.dirname(__FILE__) + '/spec_helper'
require RAILS_ROOT + '/vendor/plugins/currency_exchange/lib/rails_connection/currency_exchange.rb'
include RailsConnection::CurrencyExchange::ActMethods

require 'rubygems'
require 'active_record'
require 'open-uri'

ActiveRecord::Base.establish_connection({
    :adapter => 'sqlite3',
    :dbfile => 'db/test.sqlite3'
  })

ActiveRecord::Schema.drop_table(:exchange_rates)

ActiveRecord::Schema.define do
    create_table :exchange_rates do |t|
      t.string :base_currency      
      t.string :currency
      t.float :rate
      t.date :issued_on
      t.timestamps
    end
  end

##################################
#
##################################

describe "ExchangeRate.save_rate_and_time" do
  
  before do
    @exchange_rate=ExchangeRate.new
  end

  it "should should recieve the rate as integer and save it as a float" do
    @exchange_rate.save_rate_and_time(1,Time.at(0))
    @exchange_rate.rate.class.should eql(Float)
    @exchange_rate.rate.should eql(1.0)       
  end

  it "should should recieve the rate as string and save it as a float" do
    @exchange_rate.save_rate_and_time("1",Time.at(0))
    @exchange_rate.rate.class.should eql(Float)
    @exchange_rate.rate.should eql(1.0)       
  end

end

describe "ExchangeRateParser" do

  before do
    @these_currencies=["EUR", "USD", "JPY" ,"BGN", "CZK", "DKK", "EEK", "GBP", "HUF", "LTL", "LVL", "PLN", "RON", "SEK", "SKK", "CHF", "ISK", "NOK", "HRK", "RUB", "TRY", "AUD", "BRL", "CAD", "CNY", "HKD", "IDR", "KRW", "MXN", "MYR", "NZD", "PHP", "SGD", "THB", "ZAR"]
    @url = ExchangeRateParser::XML_CURRENCY_URL
    mockfilename=RAILS_ROOT+'/vendor/plugins/currency_exchange/spec/fixtures/feeds/exchange_rate_feed.xml'    
    @xml=REXML::Document.new(open(mockfilename) { |f| f.readlines.join("\n") } )
    ExchangeRateParser.parse_rates_for_currency(@xml)
  end

  it "should populate currency with USD" do
    a=ExchangeRate.find_by_currency("USD")
    a.currency.should == "USD"
  end
  
  it "should have these_currencies" do
    @these_currencies.each do |item|
       a=ExchangeRate.find_by_currency(item)
       a.currency.should == item
     end
  end

  it "should only have any given currency once" do
    @these_currencies.each do |item|
       ExchangeRateParser.parse_rates_for_currency(@xml)
       a=ExchangeRate.find_all_by_currency(item)
       a.length.should == 1
     end
  end
  
  it "should not have this currency" do
      a=ExchangeRate.find_by_currency("WWW")
      a.should be_nil
  end

  it "should have eur as currency and base currency only once and the rate should be 1.0" do
    a=ExchangeRate.find_all_by_currency_and_base_currency("EUR","EUR")
    a.length.should == 1
    a[0].rate.should == 1.0
  end  
    
end

describe "CurrencyExchange.newest_reates?" do
  
  before do
    @url = ExchangeRateParser::XML_CURRENCY_URL
    mockfilename=RAILS_ROOT+'/vendor/plugins/currency_exchange/spec/fixtures/feeds/exchange_rate_feed.xml'    
    @xml=REXML::Document.new(open(mockfilename) { |f| f.readlines.join("\n") } )
  end

  it "should not get any new rates if it is saturday or sunday" do
    ExchangeRateParser.should_not_receive(:read_url_io)
    rates_issue_date = ExchangeRateParser.xml_date("2008-09-05") #friday
    todays_date = ExchangeRateParser.xml_date("2008-09-07") #sunday
    base_currency=currency=ExchangeRate.new(:base_currency => "EUR", :currency => "USD", :issued_on => rates_issue_date)
    CurrencyExchange.newest_currency_rates?(currency,base_currency, todays_date)
  end

 it "should get new rates if it is not saturday or sunday and the rates are from yesterday" do
    ExchangeRateParser.should_receive(:read_url_io).with(@url).and_return(@xml)
    rates_issue_date = ExchangeRateParser.xml_date("2008-09-08") #monday
    todays_date = ExchangeRateParser.xml_date("2008-09-09") #tuesday
    base_currency=currency=ExchangeRate.create(:base_currency => "EUR", :currency => "USD", :issued_on => rates_issue_date)
    CurrencyExchange.newest_currency_rates?(currency,base_currency, todays_date)
  end
  
end


describe "CurrencyExchange.convert" do

  it "should convert EUR to EUR with no change" do
     a=ExchangeRate.create(:base_currency => "EUR",:currency => "EUR", :rate => 1.0)
     CurrencyExchange.convert(a, a, 100).should == 100.0
  end

  it "should convert accross currrencies other than EUR" do
     a=ExchangeRate.create(:base_currency => "EUR",:currency => "USD", :rate => 1.123456)
     b=ExchangeRate.create(:base_currency => "EUR",:currency => "YEN", :rate => 8.765432)
     CurrencyExchange.convert(a, b, 100).should == 780
  end

#  it "should still convert using existing rates if it cannot get in the newest rates" do
#     ExchangeRateParser.should_receive(:request_url_name).and_return('RUBBISH')
#     a=ExchangeRate.create(:base_currency => "EUR",:currency => "USD", :rate => 1.123456)
#     b=ExchangeRate.create(:base_currency => "EUR",:currency => "YEN", :rate => 8.765432)
#     CurrencyExchange.currency_exchange(100,a, b).should == 780
#  end

end

describe "CurrencyExchange.currency_rate_exists?" do

  before do
    @url = ExchangeRateParser.request_url_name
    mockfilename=RAILS_ROOT+'/vendor/plugins/currency_exchange/spec/fixtures/feeds/exchange_rate_feed.xml'    
    @xml=REXML::Document.new(open(mockfilename) { |f| f.readlines.join("\n") } )
    ExchangeRateParser.parse_rates_for_currency(@xml)
  end

  it "should return with nil and not try to read in the rate if it a currency does not already exist in the database and the database is populated" do
    ExchangeRateParser.should_not_receive(:read_url_io)
    CurrencyExchange.currency_rate_exists?("XXX").should be_nil
  end

  it "should return with true and not attempt to read in rates from the bank" do
    ExchangeRateParser.should_not_receive(:read_url_io)
    CurrencyExchange.currency_rate_exists?("EUR").class.should == ExchangeRate
  end

end

describe "CurencyExchange.currency_rate_exists? even without a DB connection" do

  it "should read in the xml plugin file if the bank xml is not availiable and the database is empty" do
    ExchangeRate.find(:all).should == []
    ExchangeRateParser.should_receive(:request_url_name).and_return('RUBBISH')
    ExchangeRateParser.should_receive(:request_file_name).and_return(ExchangeRateParser::XML_CURRENCY_FILE)
    CurrencyExchange.currency_rate_exists?("EUR").class.should == ExchangeRate
  end

  it "should use the data in the database if the bank cannot be reached" do
    ExchangeRateParser.parse_rates_for_currency(REXML::Document.new(open(RAILS_ROOT+'/vendor/plugins/currency_exchange/spec/fixtures/feeds/exchange_rate_feed.xml') { |f| f.readlines.join("\n") } )) #populate the database
    ExchangeRateParser.should_receive(:request_url_name).and_return('RUBBISH')
    a=ExchangeRate.find_by_currency("EUR")
    CurrencyExchange.newest_currency_rates?(a,a, Time.now.utc + 1.day).should be_nil
    b=ExchangeRate.find_by_currency("EUR")
    b.issued_on.should == b.issued_on
  end
  
end



