require "rails_helper"

RSpec.describe FormCopyService do
  let(:source_form) { create(:form, :live_with_draft) }
  let(:source_form_document) { FormDocument.find_by(form_id: source_form.id) }
  let(:copier) { described_class.new(source_form) }
  let(:copied_form) { copier.copy(tag: "live") }

  describe "#copy" do
    it "creates a new form" do
      expect(copied_form).to be_a(Form)
      expect(copied_form.id).not_to eq(source_form.id)
    end

    it "creates a new draft form document" do
      expect(copied_form.draft_form_document).to be_present
      expect(copied_form.draft_form_document.tag).to eq("draft")
    end

    it "copies and updates the name of the copy" do
      expect(copied_form.name).to eq("Copy of #{source_form.name}")
    end

    it "copies the language from the source form document" do
      expect(copied_form.draft_form_document.language).to eq("en")
    end

    it "returns the new form" do
      expect(copied_form).to be_a(Form)
      expect(copied_form).to be_persisted
      expect(copied_form.id).not_to eq(source_form.id)
    end

    it "associates the draft form document with the new form" do
      expect(copied_form.draft_form_document.form).to eq(copied_form)
    end

    it "has different created_at and updated_at timestamps from the source form" do
      expect(copied_form.created_at).not_to eq(source_form.created_at)
      expect(copied_form.updated_at).not_to eq(source_form.updated_at)
    end

    context "when copying from a draft form document" do
      let(:source_form_document) { create(:form_document, :draft, form: source_form) }

      it "creates a draft form document for the new form" do
        expect(copied_form.draft_form_document.tag).to eq("draft")
      end
    end

    context "when copying from an live form document" do
      let(:source_form_document) { create(:form_document, :live, form: source_form) }

      it "creates a draft form document for the new form" do
        expect(copied_form.state).to eq("draft")
      end
    end

    context "when copying from an archived form document" do
      let(:source_form_document) { create(:form_document, :archived, form: source_form) }

      it "creates a draft form document for the new form" do
        expect(copied_form.state).to eq("draft")
      end
    end
  end
end
