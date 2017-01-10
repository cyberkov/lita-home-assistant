# frozen_string_literal: true
require 'sinatra/base'

# This class simulates the home-assistant API
class FakeHomeAssistant < Sinatra::Base
  get '/api/discovery_info' do
    json_response 200, 'discovery_info.json'
  end

  get '/api/states' do
    content_type :json
    status 200
    return multi_json_response 200, ['switch.json', 'automation.json', 'climate.json', 'binary_sensor.json', 'light.json.erb', 'sensor.json.erb']
  end

  get '/api/states/:entity' do
    content_type :json
    status 200
    return case params[:entity].split('.', 2).first
           when 'switch'
             json_response 200, 'switch.json'
           when 'automation'
             json_response 200, 'automation.json'
           when 'climate'
             json_response 200, 'climate.json'
           when 'sensor'
             json_response 200, 'sensor.json.erb'
           when 'binary_sensor'
             json_response 200, 'binary_sensor.json'
           else
             {
               'attributes' => {
                 'friendly_name' => params[:entity].split('.', 2).last.capitalize
               },
               'entity_id' => params[:entity],
               'last_changed' => Time.now - 120,
               'last_updated' => Time.now - 60,
               'state' => 'ON'
             }.to_json
           end
  end

  post '/api/services/:domain/:service' do
    data = MultiJson.load(request.body)
    if params[:domain] == 'homeassistant'
      if data['entity_id'] == 'light.lamp'
        return json_response 200, 'turn_on.json' if params[:service] == 'turn_on'
        return json_response 200, 'turn_off.json' if params[:service] == 'turn_off'
      end
    end

    content_type :json
    status 200
    return [].to_json
  end

  private

  def json_response(response_code, file_name)
    content_type :json
    status response_code
    erb(File.open(File.dirname(__FILE__) + '/fixtures/' + file_name, 'rb').read)
  end

  def multi_json_response(response_code, files)
    content_type :json
    status response_code
    out = []
    files.each do |file_name|
      out << MultiJson.load(erb(File.open((File.dirname(__FILE__) + '/fixtures/' + file_name)).read))
    end
    out.to_json
  end
end
