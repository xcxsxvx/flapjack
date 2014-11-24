#!/usr/bin/env ruby

# NB: use of redis.keys probably indicates we should maintain a data
# structure to avoid the need for this type of query

require 'set'
require 'ice_cube'

require 'sandstorm/records/redis_record'

require 'flapjack/data/validators/id_validator'

require 'flapjack/data/medium'
require 'flapjack/data/rule'
require 'flapjack/data/tag'

require 'securerandom'

module Flapjack

  module Data

    class Contact

      include Sandstorm::Records::RedisRecord
      include ActiveModel::Serializers::JSON
      self.include_root_in_json = false

      define_attributes :name     => :string,
                        :timezone => :string

      index_by :name

      has_many :media, :class_name => 'Flapjack::Data::Medium',
        :inverse_of => :contact

      has_many :rules, :class_name => 'Flapjack::Data::Rule',
        :inverse_of => :contact

      validates_with Flapjack::Data::Validators::IdValidator

      before_destroy :remove_child_records
      def remove_child_records
        self.media.each  {|medium| medium.destroy }
        self.rules.each  {|rule|   rule.destroy }
      end

      # return the timezone of the contact, or the system default if none is set
      # TODO cache?
      def time_zone(opts = {})
        tz_string = self.timezone
        tz = opts[:default] if (tz_string.nil? || tz_string.empty?)

        if tz.nil?
          begin
            tz = ActiveSupport::TimeZone.new(tz_string)
          rescue ArgumentError
            if logger
              logger.warn("Invalid timezone string set for contact #{self.id} or TZ (#{tz_string}), using 'UTC'!")
            end
            tz = ActiveSupport::TimeZone.new('UTC')
          end
        end
        tz
      end

      # sets or removes the time zone for the contact
      # nil should delete TODO test
      def time_zone=(tz)
        self.timezone = tz.respond_to?(:name) ? tz.name : tz
      end

      def self.as_jsonapi(options = {})
        contacts = options[:resources]
        return [] if contacts.nil? || contacts.empty?

        fields = options[:fields]
        unwrap = options[:unwrap]
        # incl   = options[:include]

        fields_list = [:id, :name, :timezone]
        jsonapi_fields = if fields.nil?
          fields_list
        else
          Set.new(fields).add(:id).keep_if {|f| fields_list.include?(f) }.to_a
        end

        contact_ids = contacts.map(&:id)
        medium_ids = Flapjack::Data::Contact.intersect(:id => contact_ids).
          associated_ids_for(:media)
        rule_ids = Flapjack::Data::Contact.intersect(:id => contact_ids).
          associated_ids_for(:rules)

        data = contacts.collect do |contact|
          contact.as_json(:only => jsonapi_fields).merge(:links => {
            :media => medium_ids[contact.id],
            :rules => rule_ids[contact.id]
          })
        end
        return data unless (data.size == 1) && unwrap
        data.first
      end

    end
  end
end
