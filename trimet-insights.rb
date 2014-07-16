#!/usr/bin/env ruby

require 'pp'
require 'yajl'
require 'httparty'
require 'time'

TRIMET_APP_ID       = ENV['TRIMET_APP_ID']
INSIGHTS_INSERT_KEY = ENV['INSIGHTS_INSERT_KEY']
INSIGHTS_API_URL    = ENV['INSIGHTS_API_URL']
TRIMET_STOPS        = ENV['TRIMET_STOPS']

loop do
  response = HTTParty.get(
      "http://developer.trimet.org/ws/V1/arrivals/",
      :query => {:locIDs => TRIMET_STOPS, :appID => TRIMET_APP_ID, :json => true})

  locations = response['resultSet']['location'].inject({}) do |locations, loc|
    locations[loc['locid']] = loc['desc']
    locations
  end

  events = []
  response['resultSet']['arrival'].each do |arrival|

    next unless arrival['estimated']
    estimated_arrival = Time.parse(arrival['estimated'])
    scheduled_arrival = Time.parse(arrival['scheduled'])
    # puts arrival['estimated']
    delay = scheduled_arrival - estimated_arrival
    # Consider faking the timestamp as time of estimate recording
    # timestamp = Time.parse(arrival['blockPosition']['at'])

    events << {
      :eventType         => 'TriMet Status',
      :eventVersion      => 1,
      # :timestamp         => timestamp,
      :status            => arrival['status'],
      :estimated_arrival => estimated_arrival.xmlschema,
      :scheduled_arrival => scheduled_arrival.xmlschema,
      :delay             => delay.to_i,
      :shortsign         => arrival['shortSign'],
      :direction         => arrival['dir'],
      :route             => arrival['route'],
      :stop_id           => arrival['locid'],
      :stop_desc   => locations[arrival['locid']],
      :detoured          => arrival['detour'].to_s,
    }

  end

  puts HTTParty.post(INSIGHTS_API_URL,
              :body    => Yajl::Encoder.encode(events),
              :headers => {'Content-Type' => 'application/json',
                           'X-Insert-Key' => INSIGHTS_INSERT_KEY})

  sleep(60)
end
