class Project < ActiveRecord::Base
  belongs_to :election
  belongs_to :category
  has_many :vote_approvals
  has_many :vote_knapsacks
  has_many :vote_plusminuses
  translates :title, :short_title, :description, :details, :address, :partner, :committee, :video_url, :partner
  globalize_accessors
  mount_uploader :image, ImageUploader
  validates :title, presence: true
  validates :description, presence: true
  validates :cost, numericality: {only_integer: true, greater_than_or_equal_to: 0}
  validates :cost_min, numericality: {only_integer: true, greater_than_or_equal_to: 0}, allow_blank: true
  validates :cost_step, numericality: {only_integer: true, greater_than: 0}, allow_blank: true
  validates :external_vote_count, numericality: {only_integer: true, greater_than_or_equal_to: 0}, allow_blank: true
  validate :validate_category_id
  validate :validate_map_geometry
  validate :validate_adjustable_cost
  validate :validate_data

  def parsed_data
    if @parsed_data.nil?
      @parsed_data = (!data.nil? && !data.empty?) ? JSON.parse(data) : nil
    end
    @parsed_data
  end

  def mandatory?
    # FIXME: Hacky.
    adjustable_cost? && !uses_slider?
  end

  private

  def validate_category_id
    if category_id && Category.find(category_id).election_id != election_id
      errors.add(:category_id, "must belong to the same election")
    end
  end

  def validate_map_geometry
    return if map_geometry.blank?
    begin
      points = JSON.parse(map_geometry)
      if !points.is_a?(Array) || !points.all? { |p| (p.is_a?(Array) && p.length == 2) || p.is_a?(::Hash) }
        errors.add(:map_geometry, 'is in the wrong format. An example: [[37.43, -122.17]]')
      end
    rescue => exception
      errors.add(:map_geometry, "must be in the JSON format. Error message from the parser: \"#{exception.message}\"")
    end
  end

  def validate_adjustable_cost
    return unless adjustable_cost
    if !cost.blank? and cost.to_i <= 0
      errors.add(:cost, :greater_than, count: 0)
    end
    if cost_min.blank?
      errors.add(:cost_min, :blank)
    end
    if cost_step.blank?
      errors.add(:cost_step, :blank)
    end
    if !cost_min.blank? and !cost.blank? and cost_min.to_i >= cost.to_i
      errors.add(:cost_min, 'must be less than cost max')
    end
    if !cost_step.blank? and !cost.blank? and !cost_min.blank? and !uses_slider and cost_step.to_i > 0 and (cost.to_i - cost_min.to_i) / cost_step.to_i > 20
      errors.add(:cost_step, "is too small for radio buttons. There can be at most 20 radio buttons.")
    end
  end

  def validate_data
    return unless data && data != ''
    begin
      JSON.parse(data)
    rescue JSON::ParserError => exception
      errors.add(:data, "must be in the correct JSON format. Error message from the parser: \"#{exception.message}\"")
    end
  end
end
