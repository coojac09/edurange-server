class Answer < ActiveRecord::Base
  belongs_to :user
  belongs_to :question
  has_one    :scenario, through: :question

  after_initialize do
    self.class.validates :text, uniqueness: {
      scope:          [:user, :question],
      message:        "duplicate answer",
      case_sensitive: !question.ignore_case?
    }
  end

  validates :text, presence: true, allow_blank: false, if: :number_or_string?

  # sanity check, don't save nils to the database
  validates :correct, inclusion: { in: [true, false] }

  validate :validate_text
  validate :validate_comment
  validate :validate_essay_points_earned

  validate def number_valid
    if question.number?
      unless question.accept_integer? & text.is_integer? | question.accept_decimal? & text.is_decimal? | question.accept_hex? & text.is_hex?
        acceptable = []
        acceptable << 'integer' if question.accept_integer?
        acceptable << 'decimal' if question.accept_decimal?
        acceptable << 'hex'     if question.accept_hex?
        msg = 'must be ' + acceptable.to_sentence(two_words_connector: ' or ', last_word_connector: ', or ')
        errors.add(:text, msg)
      end
    end
  end

  after_initialize do
    self.text = self.text.strip unless text.nil?
    self.correct ||= false # if nil set to false
  end

  def number_or_string?
    question.number? || question.string?
  end

  # Hacky polymorphism
  def grade
    if valid?
      if question.number?
        grade_number
      elsif question.essay?

      elsif question.string?
        grade_string
      else
        raise StandardError.new("unknown question type #{question.type_of}")
      end
    end
  end

  validate def check_duplicate_number
    if question.number? && !self.text.nil? && self.text.is_numeric?
      duplicate = question.answers_from(user).any? do |other|
        other.id != self.id && Float(self.text) == Float(other.text)
      end
      if duplicate
        errors.add(:text, 'duplicate answer')
      end
    end
  end

  def grade_number
    # go through each value looking for answer
    question.values.each_with_index do |value, index|
      if Float(self.text) == Float(value[:value])
        self.correct     = true
        self.value_index = index
        break
      end
    end
  end

  def grade_string
    context = QueryContext.new(player: player, scenario: scenario)
    question.values.each_with_index do |value, index|
      x = context.evaluate(value[:value])

      correct = if question.ignore_case?
         x.casecmp(text) == 0
      else
         x == text
      end

      if correct
        self.correct = correct
        self.value_index = index
        break
      end
    end
  end

  def player
    scenario.players.find_by!(user: user)
  end

  # ensure that text is not blank in an answer
  def validate_text
    if self.question.essay? and self.text_essay == "" #problem here, question isn't linking correctly to answer. do a SQL query...
      errors.add(:text_essay, 'must not be blank')
      return false
    else
      if self.text == ""
        errors.add(:text, 'must not be blank')
        return false
      end
    end
    true
  end

  # if comment is nil return true else return true if comment is not blank
  def validate_comment
    return true if self.comment == nil
    self.comment = self.comment.strip
    if self.comment == ""
      errors.add(:comment, 'must not be blank')
      return false
    end
    true
  end

  # return true if essay points earned is nil else ensure that points earned is an integer type greater than 0 and question points
  def validate_essay_points_earned
    return true if self.essay_points_earned == nil
    self.essay_points_earned = self.essay_points_earned.strip
    if self.essay_points_earned == ""
      errors.add(:essay_points_earned, 'must not be blank')
      return false
    end
    if not self.essay_points_earned.is_integer?
      errors.add(:essay_points_earned, 'must be zero or a positive integer')
      return false
    end
    if (self.essay_points_earned.to_i < 0) or (self.essay_points_earned.to_i > self.question.points)
      errors.add(:essay_points_earned, "must be between 0 and #{self.question.points}")
      return false
    end
    true
  end
end
