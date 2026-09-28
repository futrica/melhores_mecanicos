class TrackMetricJob < ApplicationJob
  queue_as :default

  def perform(model_name, record_ids, counter_name = :searches_count)
    klass = model_name.safe_constantize
    return unless klass

    ids = Array(record_ids).reject(&:blank?)
    return if ids.empty?

    ids.each do |id|
      klass.increment_counter(counter_name, id)
    rescue ActiveRecord::RecordNotFound
      # Ignore if record was deleted
    end
  end
end
