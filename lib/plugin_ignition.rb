# To change this template, choose Tools | Templates
# and open the template in the editor.

ActiveRecord::Base.send(:include, RailsConnection::CurrencyExchange::ActMethods)
ActiveRecord::Base.send(:extend, RailsConnection::CurrencyExchange::ActMethods)