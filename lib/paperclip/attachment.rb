# frozen_string_literal: true

require 'paperclip/attachment'

module Paperclip
  class Attachment
    def save
      circuit_break! { flush_deletes } unless @options[:keep_old_files]

      process = only_process

      @queued_for_write.except!(:original) if process.any? && !process.include?(:original)

      circuit_break! { flush_writes }

      @dirty = false
      true
    end

    private

    def circuit_break!(&block)
      Stoplight('object-storage', &block).with_threshold(10).with_cool_off_time(30).with_error_handler do |error, handle|
        if error.is_a?(Seahorse::Client::NetworkingError)
          handle.call(error)
        else
          raise error
        end
      end.run
    end
  end
end
