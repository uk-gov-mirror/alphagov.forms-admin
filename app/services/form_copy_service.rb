class FormCopyService
  TO_INCLUDE = %i[creator_id created_at updated_at creator_id].freeze
  TO_EXCLUDE = Form::ATTRIBUTES_NOT_IN_FORM_DOCUMENT + TO_INCLUDE

  def initialize(form)
    @form = form
    @copied_form = Form.new
  end

  def copy(tag: "draft")
    form_doc = FormDocument.find_by(form_id: @form.id, tag:, language: @form.language)
    return false if form_doc.blank?

    content = form_doc.content

    ActiveRecord::Base.transaction do
      copy_attributes(content)
      prepend_name
      # copy_pages_and_conditions(content["steps"])

      @copied_form.save!
      @copied_form
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to copy form #{@form.id}: #{e.message}")
    end
  end

private

  def attributes_to_copy
    Form.attribute_names - TO_EXCLUDE.map(&:to_s)
  end

  def copy_attributes(content)
    @copied_form.assign_attributes(content.slice(*attributes_to_copy))
  end

  def prepend_name
    @copied_form.name = "Copy of #{@form.name}"
  end
end
