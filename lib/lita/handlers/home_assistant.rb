# frozen_string_literal: true
require 'fuzzy_match'

module Lita
  module Handlers
    # Home Assistant Handler
    class HomeAssistant < Handler
      on :loaded, :boot
      on :unhandled_message, :chat

      config :url, type: String, default: 'https://127.0.0.1:8123' do
        validate do |value|
          'must be a valid URL' unless URI.parse(value)
        end
      end
      # You can disable SSL certify verification by passing '{ ssl: { verify: false } }'
      config :http_options, required: false, type: Hash, default: { ssl: { verify: false } }
      config :api_password, type: String, default: ''
      config :exclude_domains, type: Array, default: %w(automation sun zone persistent_notification)
      config :update_interval, type: Integer, default: 60

      route(/ha info/i, :get_info,
            command: true,
            help: { 'ha info' => 'show information about home-assistant' })
      route(/ha clearcache/i, :clear_cache,
            help: { 'ha clearcache' => 'clear the local redis cache of entities' },
            command: true)

      route(/list.?(\w+)?/i, :list,
            help: { 'ha list [SEARCH_TERM]' => 'list all entities of the given type' },
            command: true)
      route(/set (.*) to (.*)/i, :set,
            help: { 'set <friendly name of entity> to <new state>' => 'set the entity state to the given value' },
            command: true)
      route(/state of (.*)/i, :state,
            help: { 'state of <friendly name of entity>' => 'returns the current state of the entity' },
            command: true)
      route(/turn (.*) (.*)/i, :toggle,
            help: { 'turn <friendly name of entity> <on|off>' => 'turn the entity on/off' },
            command: true)

      def boot(_payload)
        get_state
        start_periodic_update
      end

      def list(msg)
        search = "*#{msg.matches.first.first}*" || '*.*'
        out = []
        redis.scan_each(match: search) { |x| out << x }
        msg.reply out.sort.join("\n")
      end

      def get_info(msg)
        x = get('/discovery_info')
        x.each { |k, v| msg.reply "#{k}: #{v}" }
        msg.reply "keywords in cache: #{redis.keys.size}"
      end

      def chat(payload)
        message = payload[:message]
        return unless should_reply?(message)
        log.debug "HASS: chat route kicked in for #{payload.body}"
      end

      def toggle(msg)
        args = msg.matches.flatten[1] =~ /on|off/i ? msg.matches.flatten : msg.matches.flatten.reverse
        state = args[1]
        entity = find_by_name(args[0])
        return msg.reply "Sorry. I cannot set #{entity['entity_id']} to #{state}. Please use 'on' or 'off'." unless state =~ /on|off/
        payload = {
          'entity_id' => entity['entity_id']
        }.to_json
        post("/services/homeassistant/turn_#{state.downcase}", payload)
        msg.reply "Ok. #{friendly_name(entity)} has been turned #{state}."
      end

      # set (.*) to (.*)
      def set(msg)
        entity = find_by_name(msg.matches.flatten[0])
        value = msg.matches.flatten[1]
#        binding.pry
      end

      # state of *
      def state(msg)
        msg.matches.first.each do |item|
          entity = find_by_name(item)
          last_changed = time_ago_in_words(Time.now, DateTime.parse(entity['last_changed']).to_time)

          msg.reply "#{entity['attributes']['friendly_name']} is #{entity['state']} (since #{last_changed})"
        end
      end

      def clear_cache(msg, keys = redis.keys)
        redis.del(keys) unless keys.empty?
        msg.reply 'Home Assistant cache has been cleared' unless msg.nil?
      end

      private

      def friendly_name(entity)
        entity['attributes']['friendly_name'] || entity['entity_id']
      end

      def should_reply?(message)
        message.command? || message.body =~ /#{aliases.join('|')}/i
      end

      def aliases
        [robot.mention_name, robot.alias].map { |a| a unless a == '' }.compact
      end

      def http_options
        config.http_options.merge(headers: { 'x-ha-access' => config.api_password })
      end

      # Returns a parsed json array
      def get(path = '/discovery_info')
        uri = URI.parse(config.url)
        uri.path += uri.path + '/api' + path
        response = http(http_options).get(uri)
        case response.status
        when 200
          return MultiJson.load(response.body)
        when 201
          return MultiJson.load(response.body)
        when 400
          log.error "HASS: response code 400: #{response.body}"
          return response
        when 401
          log.error 'HASS: Home Assistant says we are unauthorized'
          return response
        when 404
          log.error 'HASS: 404 Not found'
          return response
        when 405
          log.error 'HASS: 405 Method not allowed'
          return response
        end
      end

      def post(path = '/states', payload)
        #response = http.post("http://#{config.host}:#{config.port}/api#{path}", payload)
        uri = URI.parse(config.url)
        uri.path += uri.path + '/api' + path
        response = http(http_options).post(uri, payload)
        case response.status
        when 200
          return MultiJson.load(response.body)
        when 201
          return MultiJson.load(response.body)
        when 400
          log.error "HASS: response code 400: #{response.body}"
          return response
        when 401
          log.error 'HASS: Home Assistant says we are unauthorized'
          return response
        when 404
          log.error 'HASS: 404 Not found'
          return response
        when 405
          log.error 'HASS: 405 Method not allowed'
          return response
        end
      end

      def find_by_name(name)
        data = redis.get(name.downcase)
        data = FuzzyMatch.new(redis.keys).find(name) unless data
        begin
          ret = MultiJson.load(data)
        rescue MultiJson::ParseError
          log.debug "HASS: #{name} is not an entity. debug: #{data}"
          ret = find_by_name(data) if data.is_a? String
          return nil unless ret
        end
        get_state(ret['entity_id'])
      end

      def get_state(id = nil)
        if id
          entity = get("/states/#{id}")
          update_cache(entity)
          entity
        else
          get('/states').map { |item| update_cache item }
        end
      end

      def update_cache(entity)
        return if config.exclude_domains.include?(entity['entity_id'].split('.').first)
        redis.pipelined do
          redis.set(entity['entity_id'].downcase, entity.to_json)
          redis.set(entity['attributes']['friendly_name'].downcase, entity['entity_id'].downcase) unless entity['attributes']['friendly_name'].nil?
        end
      end

      def start_periodic_update
        every(config.update_interval) do
          log.info 'HASS: Update states'
          get_state
        end
      end

      # time_ago_in_words(Time.now, 1.day.ago) # => 1 day
      # time_ago_in_words(Time.now, 1.hour.ago) # => 1 hour
      def time_ago_in_words(t1, t2)
        s = t1.to_i - t2.to_i # distance between t1 and t2 in seconds

        resolution = if s > 29_030_400 # seconds in a year
                       [(s / 29_030_400), 'years']
                     elsif s > 2_419_200
                       [(s / 2_419_200), 'months']
                     elsif s > 604_800
                       [(s / 604_800), 'weeks']
                     elsif s > 86_400
                       [(s / 86_400), 'days']
                     elsif s > 3600 # seconds in an hour
                       [(s / 3600), 'hours']
                     elsif s > 60
                       [(s / 60), 'minutes']
                     else
                       [s, 'seconds']
                     end

        # singular v. plural resolution
        if resolution[0] == 1
          resolution.join(' ')[0...-1]
        else
          resolution.join(' ')
        end
      end

      Lita.register_handler(self)
    end
  end
end
