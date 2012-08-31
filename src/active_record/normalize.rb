# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'active_support/concern'

module TwitterCldr
  module ActiveRecord

    module Normalize

      extend ActiveSupport::Concern

      included do
        before_validation :normalize_unicode_attributes
      end

      module ClassMethods

        def normalize_unicode(*args)
          options = args.extract_options!.dup
          args.each { |attr| self_unicode_normalization_options[attr] = options }
        end

        def unicode_normalization_options
          parent_unicode_normalization_options.merge(self_unicode_normalization_options)
        end

        private

        def self_unicode_normalization_options
          @self_normalize_unicode_options ||= {}
        end

        def parent_unicode_normalization_options
          superclass.respond_to?(:unicode_normalization_options) ? superclass.unicode_normalization_options : {}
        end

      end

      private

      def normalize_unicode_attributes
        self.class.unicode_normalization_options.each do |attr, options|
          self[attr] = TwitterCldr::Normalization.normalize(self[attr], options) if self[attr].present?
        end
      end

    end

  end
end