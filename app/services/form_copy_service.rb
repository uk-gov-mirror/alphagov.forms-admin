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

      @copied_form.save!
      copy_pages(content["steps"])
      copy_routing_conditions(content["steps"])

      @copied_form
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to copy form #{@form.id}: #{e.message}")
      raise
    end
  end

private

  def attributes_to_copy
    Form.attribute_names - TO_EXCLUDE.map(&:to_s)
  end

  def copy_attributes(content)
    @copied_form.assign_attributes(content.slice(*attributes_to_copy))
  end

  def copy_pages(steps)
    return if steps.blank?

    steps.each do |step|
      page = @copied_form.pages.build
      copy_page_attributes(page, step)
      page.save!
    end
  end

  def copy_page_attributes(page, step)
    data = step["data"]
    page.assign_attributes(
      position: step["position"],
      question_text: data["question_text"],
      hint_text: data["hint_text"],
      answer_type: data["answer_type"],
      is_optional: data["is_optional"],
      answer_settings: data["answer_settings"],
      page_heading: data["page_heading"],
      guidance_markdown: data["guidance_markdown"],
      is_repeatable: data["is_repeatable"],
    )
  end

  def prepend_name
    @copied_form.name = "Copy of #{@form.name}"
  end

  def copy_routing_conditions(steps)
    return if steps.blank?

    # Build a mapping from old page IDs to new page objects
    page_id_mapping = {}
    steps.each_with_index do |step, index|
      old_page_id = step["id"]
      new_page = @copied_form.pages[index]
      page_id_mapping[old_page_id] = new_page

      routing_conditions = step["routing_conditions"]
      next if routing_conditions.blank?

      new_page = @copied_form.pages[index]

      routing_conditions.each do |condition_data|
        copy_condition(condition_data, new_page, page_id_mapping)
      end
    end
  end

  def copy_condition(condition_data, routing_page, page_id_mapping)
    check_page_id = condition_data["check_page_id"]
    goto_page_id = condition_data["goto_page_id"]

    condition = Condition.new(
      routing_page:,
      check_page: page_id_mapping[check_page_id],
      goto_page: goto_page_id.present? ? page_id_mapping[goto_page_id] : nil,
      answer_value: condition_data["answer_value"],
      skip_to_end: condition_data["skip_to_end"] || false,
      exit_page_heading: condition_data["exit_page_heading"],
      exit_page_markdown: condition_data["exit_page_markdown"],
    )

    condition.save!
  end
end
