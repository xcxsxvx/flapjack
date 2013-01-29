#!/usr/bin/env ruby

# NB: use of redis.keys probably indicates we should maintain a data
# structure to avoid the need for this type of query

require 'set'

require 'flapjack/data/entity'

module Flapjack

  module Data

    class Contact

      attr_accessor :first_name, :last_name, :email, :media, :pagerduty_credentials, :id

      def self.all(options = {})
        raise "Redis connection not set" unless redis = options[:redis]

        contact_keys = redis.keys('contact:*')

        contact_keys.inject([]) {|ret, k|
          k =~ /^contact:(\d+)$/
          id = $1
          contact = self.find_by_id(id, :redis => redis)
          ret << contact if contact
          ret
        }.sort_by {|c| [c.last_name, c.first_name]}
      end

      def self.delete_all(options = {})
        raise "Redis connection not set" unless redis = options[:redis]

        keys_to_delete = redis.keys("contact:*") +
                         redis.keys("contact_media:*") +
                         # FIXME: when we do source tagging we can properly
                         # clean up contacts_for: keys
                         # redis.keys('contacts_for:*') +
                         redis.keys("contact_pagerduty:*")

        redis.del(keys_to_delete) unless keys_to_delete.length == 0
      end

      def self.find_by_id(contact_id, options = {})
        raise "Redis connection not set" unless redis = options[:redis]
        raise "No id value passed" unless contact_id
        logger = options[:logger]

        return unless redis.hexists("contact:#{contact_id}", 'first_name')

        fn, ln, em = redis.hmget("contact:#{contact_id}", 'first_name', 'last_name', 'email')
        me = redis.hgetall("contact_media:#{contact_id}")

        # similar to code in instance method pagerduty_credentials
        pc = nil
        if service_key = redis.hget("contact_media:#{contact_id}", 'pagerduty')
          pc = redis.hgetall("contact_pagerduty:#{contact_id}").merge('service_key' => service_key)
        end

        self.new(:first_name => fn, :last_name => ln,
          :email => em, :id => contact_id, :media => me, :pagerduty_credentials => pc, :redis => redis )
      end


      # NB: should probably be called in the context of a Redis multi block; not doing so
      # here as calling classes may well be adding/updating multiple records in the one
      # operation
      # TODO maybe return the instantiated Contact record?
      def self.add(contact, options = {})
        raise "Redis connection not set" unless redis = options[:redis]

        redis.del("contact:#{contact['id']}",
                  "contact_media:#{contact['id']}",
                  "contact_pagerduty:#{contact['id']}")

        redis.hmset("contact:#{contact['id']}",
                    *['first_name', 'last_name', 'email'].collect {|f| [f, contact[f]]})

        unless contact['media'].nil?
          contact['media'].each_pair {|medium, address|
            case medium
            when 'pagerduty'
              redis.hset("contact_media:#{contact['id']}", medium, address['service_key'])
              redis.hmset("contact_pagerduty:#{contact['id']}",
                          *['subdomain', 'username', 'password'].collect {|f| [f, address[f]]})
            else
              redis.hset("contact_media:#{contact['id']}", medium, address)
            end
          }
        end
      end

      def pagerduty_credentials
        return unless service_key = @redis.hget("contact_media:#{self.id}", 'pagerduty')
        @redis.hgetall("contact_pagerduty:#{self.id}").
          merge('service_key' => service_key)
      end

      def entities_and_checks
        @redis.keys('contacts_for:*').inject({}) {|ret, k|
          if @redis.sismember(k, self.id)
            if k =~ /^contacts_for:([a-zA-Z0-9][a-zA-Z0-9\.\-]*[a-zA-Z0-9])(?::(\w+))?$/
              entity_id = $1
              check = $2

              unless ret.has_key?(entity_id)
                ret[entity_id] = {}
                if entity_name = @redis.hget("entity:#{entity_id}", 'name')
                  entity = Flapjack::Data::Entity.new(:name => entity_name,
                             :id => entity_id, :redis => @redis)
                  ret[entity_id][:entity] = entity
                end
                # using a set to ensure unique check values
                ret[entity_id][:checks] = Set.new
              end

              if check
                # just add this check for the entity
                ret[entity_id][:checks] |= check
              else
                # registered for the entity so add all checks
                ret[entity_id][:checks] |= entity.check_list
              end
            end
          end
          ret
        }.values
      end

      def name
        [(self.first_name || ''), (self.last_name || '')].join(" ").strip
      end

      # return an array of the notification rules of this contact
      def notification_rules
        # use Flapjack::Data::NotificationRule to construct each rule
        rules = []
        return rules unless rule_ids = @redis.smembers("contact_notification_rules:#{self.id}")
        rule_ids.each do |rule_id|
          rules << Flapjack::Data::NotificationRule.find_by_id(rule_id, :redis => @redis)
        end
        rules
      end

      # how often to notify this contact on the given media
      def interval_for_media(media)
        # FIXME: actually look this up from redis
        return 15 * 60
      end

      # has a given (media, entity:check, severity) been notified within a given period?
      def notified_within?(opts)
        # FIXME: must remember to nuke the keys used for this on recovery (and any state change?)
        media    = opts[:media]
        check    = opts[:check]
        state    = opts[:state]
        duration = opts[:duration]
        raise "unimplemented"
      end

      # drop notifications for
      def drop_notifications?(opts)
        media    = opts[:media]
        check    = opts[:check]
        state    = opts[:state]
        # build it and they will come
        return true if @redis.exists("drop_alerts_for_contact:#{self.id}")
        return true if media and
          @redis.exists("drop_alerts_for_contact:#{self.id}:#{media}")
        return true if media and check and
          @redis.exists("drop_alerts_for_contact:#{self.id}:#{media}:#{check}")
        return true if media and check and state and
          @redis.exists("drop_alerts_for_contact:#{self.id}:#{media}:#{check}:#{state}")
        return false
      end

    private

      def initialize(options = {})
        raise "Redis connection not set" unless @redis = options[:redis]
        [:first_name, :last_name, :email, :media, :id].each do |field|
          instance_variable_set(:"@#{field.to_s}", options[field])
        end
      end

    end

  end

end
