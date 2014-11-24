#!/usr/bin/env ruby

require 'sandstorm/records/redis_record'

module Flapjack
  module Data
    class UnscheduledMaintenance

      include Sandstorm::Records::RedisRecord

      define_attributes :start_time => :timestamp,
                        :end_time   => :timestamp,
                        :summary    => :string,
                        :notified   => :boolean,
                        :last_notification_count => :integer

      index_by :notified

      validates :start_time, :presence => true
      validates :end_time, :presence => true

      belongs_to :check_by_start, :class_name => 'Flapjack::Data::Check',
        :inverse_of => :unscheduled_maintenances_by_start

      belongs_to :check_by_end, :class_name => 'Flapjack::Data::Check',
        :inverse_of => :unscheduled_maintenances_by_end

      def duration
        self.end_time - self.start_time
      end

      def check
        self.check_by_start
      end

      def check=(c)
        self.check_by_start = c
        self.check_by_end   = c
      end

      def self.as_jsonapi(options = {})
        unscheduled_maintenances = options[:resources]
        return [] if unscheduled_maintenances.nil? || unscheduled_maintenances.empty?

        fields = options[:fields]
        unwrap = options[:unwrap]
        # incl   = options[:include]

        whitelist = [:id, :start_time, :end_time, :summary]

        jsonapi_fields = if fields.nil?
          whitelist
        else
          Set.new(fields).add(:id).keep_if {|f| whitelist.include?(f) }.to_a
        end

        usm_ids = unscheduled_maintenances.map(&:id)
        check_ids = Flapjack::Data::Check.intersect(:id => usm_ids).
                      associated_ids_for(:check_by_start)

        data = unscheduled_maintenances.collect do |usm|
          usm.as_json(:only => jsonapi_fields).merge(:links => {
            :check => check_ids[usm.id]
          })
        end
        return data unless (data.size == 1) && unwrap
        data.first
      end

    end
  end
end