class Election < ApplicationRecord
  has_many :projects, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :voters, dependent: :destroy
  has_many :valid_voters, -> { where("void = 0 AND stage IS NOT NULL") }, class_name: 'Voter' 
  has_many :voter_registration_records, dependent: :destroy
  has_many :code_batches, dependent: :destroy
  has_many :codes, through: :code_batches
  has_many :locations, dependent: :destroy
  has_many :election_users, dependent: :destroy
  has_many :users, through: :election_users
  #has_many :admin_users, -> { where election_users: { status: ElectionUser.statuses[:admin] } },
  #                       through: :election_users, class_name: 'User', source: :user
  #has_many :volunteer_users, -> { where election_users: { status: ElectionUser.statuses[:volunteer] } },
  #                       through: :election_users, class_name: 'User', source: :user
  after_destroy :delete_files
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
                   format: {with: /\A[a-z0-9\-_]+\z/, message: "must consist only of lowercase letters, numbers, hyphens, or underscores without any whitespace"},
                   exclusion: {in: ['admin', 'about', 'contact', 'done_survey', 'twilio_sms'], message: "'%{value}' is reserved." }
  validates :budget, numericality: {only_integer: true, greater_than: 0}, allow_blank: true
  validate :validate_config_yaml
  after_update :clear_config_cache
  after_destroy :clear_config_cache
  attribute :duplicate_projects, :boolean, default: true

  @@config_cache = {}

  def config
    if !@@config_cache.key?(id)
      self_config = (YAML.load(config_yaml,permitted_classes: [Date]) || {}).deep_symbolize_keys
      @@config_cache[id] = deep_freeze(Election.default_config.deep_merge(self_config))
    else
      @@config_cache[id]
    end
  end

  def clear_config_cache
    @@config_cache.delete(id)
  end

  def categorized?
    if @categorized.nil?
      @categorized = categories.exists?
    end
    @categorized
  end

  def ordered_categories(category_group, shuffled)
    if categorized?
      cs = (category_group.nil? ? categories : categories.where(category_group: category_group)).to_a
      uncategorized_projects = projects.where(category_id: nil)
      if uncategorized_projects.exists?
        # If there are uncategorized projects, create a fake category that
        # contains them and use a red text to let the election's owners
        # know that this shoudn't happen.
        category = Category.new
        category.name = "<span style='color: red;'>UNCATEGORIZED</span>"
        category.projects = uncategorized_projects
        cs << category
      end
    else
      # For elections that don't use categories, create a fake category
      # that contains all the projects to make our code simpler.
      category = Category.new
      category.projects = projects
      cs = [category]
    end
    cs.each { |c| c.ordered_projects = c.projects.to_a }

    if shuffled
      cs = cs.select { |c| c.pinned } + cs.select { |c| !c.pinned }.shuffle
      cs.each { |c| c.ordered_projects.shuffle! }
    else
      cs.sort_by! { |c| c.sort_order.to_i }
      cs.each { |c| c.ordered_projects.sort_by! { |project| project.sort_order.to_i } }
    end
    cs
  end

  def utc_offset_in_seconds
    # Can't use "return ActiveSupport::TimeZone.new(self.time_zone).utc_offset"
    # because it always returns the offset for XST. We need to know the time
    # to know whether it's XST or XDT. So, we randomly pick a voter and use their
    # created_at time. It is hacky.
    any_voter = valid_voters.take
    any_voter ? any_voter.created_at.in_time_zone(self.time_zone).utc_offset : 0
  end

  def store_dir
    Rails.root.join('public', 'uploads', 'election', 'file', id.to_s)
  end

  def workflow_summary
    workflow_summary_helper(config[:workflow]) || ""
  end

  private

  def self.default_config
    config_description = YAML.load_file(Rails.root.join('app', 'models', 'election_config_description.yml'))
    default_config_helper(config_description)
  end

  def self.default_config_helper(options)
    c = {}
    options.each do |option|
      if option.key?('children')
        value = default_config_helper(option['children'])
      else
        value = option['default']
      end
      c[option['name'].to_sym] = value
    end
    c
  end

  def validate_config_yaml
    begin
      YAML.load(config_yaml,permitted_classes: [Date])
    rescue => exception
      errors.add(:config, "must be in the correct YAML format. Error message from the parser: \"#{exception.message}\"")
    end
  end

  # Recursively freeze the object for the highest performance.
  # Also make it read-only.
  def deep_freeze(o)
    if o.is_a?(Hash)
      o.each { |_, v| deep_freeze(v) }
    elsif o.is_a?(Array)
      o.each { |v| deep_freeze(v) }
    end
    o.freeze
  end

  def delete_files
    FileUtils.rm_rf(store_dir)
  end

  def workflow_summary_helper(workflow)
    workflow.map do |page|
      tmp =
      case page
      when "approval"
        "Approval"
      when "knapsack"
        "Knapsack"
      when "ranking"
        "Ranking"
      when "comparison"
        "Comparison"
      when "plusminus"
        "Plus/minus"
      when "token"
        "Token"
      else
        page.is_a?(Array) ? "[" + workflow_summary_helper(page) + "]" : nil
      end
      if !page.is_a?(Array) && !tmp.nil? && config[page.to_sym][:show_disclaimer]
        tmp = "<span class='text-success'>" + tmp + "</span>"
      end
      tmp
    end.reject(&:nil?).join(", ")
  end
end
