class VoterRegistrationRecord < ApplicationRecord
  belongs_to :election
  belongs_to :user, optional: true  # In case of in-person voter
  belongs_to :voter, optional: true  # In case of online voter
  serialize :data, JSON

  validate :validate_name, if: Proc.new { should_validate?('name') }
  validates :first_name, presence: true, if: Proc.new { should_validate?('first_name') }
  validates :last_name, presence: true, if: Proc.new { should_validate?('last_name') }
  validates :address, presence: true, if: Proc.new { should_validate?('address') }
  validates :zip_code, presence: true, if: Proc.new { should_validate?('zip_code') }
  validates :city, presence: true, if: Proc.new { should_validate?('city') }
  validates :birth_year, presence: true, if: Proc.new { should_validate?('birth_year') }
  validate :validate_date_of_birth, if: Proc.new { should_validate?('date_of_birth') }
  validates :ward, presence: true, if: Proc.new { should_validate?('ward') }

  # Define these methods, so that we can access the attributes in 'data' as if they are normal attributes, i.e., voter.name instead of voter.data[:name]
  [
    :phone_number,
    :name, :first_name, :middle_initial, :last_name, :suffix,
    :email,
    :address, :zip_code, :city,
    :birth_year, :date_of_birth,
    :ward
  ].each do |method_name|
    define_method(method_name) do
      (self.data || {})[method_name]
    end
    define_method(method_name.to_s + '=') do |value|
      self.data ||= {}
      self.data[method_name] = value.strip
    end
  end

  private

  def should_validate?(attribute)
    election.config[:voter_registration_questions].include?(attribute)
  end

  def validate_name
    if name.blank?
      errors.add(:name, :blank)
    elsif !name.include?(' ')
      errors.add(:name, 'must include the first name and last name')  # FIXME: i18n
    end
  end

  def validate_date_of_birth
    begin
      dob = Date.strptime(date_of_birth, '%m/%d/%Y')
    rescue ArgumentError => exception
      errors.add(:date_of_birth)
      return
    end
    # TODO: Validate against unusual dates of birth like 1/1/1000.
    minimum_voting_age = election.config[:minimum_voting_age]
    maximum_voting_age = election.config[:maximum_voting_age]
    if minimum_voting_age != 0 || maximum_voting_age != 0
      as_of_date = election.config[:age_as_of_date]
      if as_of_date.blank?
        as_of_date = Date.today
      elsif !as_of_date.is_a?(Date)
        as_of_date = Date.strptime(as_of_date, '%Y-%m-%d')
      end
      age = as_of_date.year - dob.year - ((as_of_date.month > dob.month || (as_of_date.month == dob.month && as_of_date.day >= dob.day)) ? 0 : 1)
      if (minimum_voting_age != 0 && age < minimum_voting_age) || (maximum_voting_age != 0 && age > maximum_voting_age)
        errors.add(:base, I18n.t('registration.not_voting_age_error'))
      end
    end
  end
end
