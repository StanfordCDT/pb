class Category < ApplicationRecord
  belongs_to :election
  has_many :projects, dependent: :nullify
  translates :name
  globalize_accessors
  mount_uploader :image, ImageUploader
  validates :name, presence: true
  validates :category_group, numericality: {only_integer: true, greater_than_or_equal_to: 1}

  attr_accessor :ordered_projects  # To support shuffle. Kind of hacky.
end
