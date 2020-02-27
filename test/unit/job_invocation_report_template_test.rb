require 'test_plugin_helper'

class JobReportTemplateTest < ActiveSupport::TestCase
  class FakeTask < OpenStruct
    class Jail < Safemode::Jail
      allow :action_output, :ended_at
    end
  end

  context 'job invocation report template' do

    describe 'correct template is available' do
      it 'settings select includes only report templates with name job_id' do
        FactoryBot.create(:report_template, name: 'Template 1')
        correct_template = FactoryBot.create(:report_template, name: 'Job Invocation Report Template')
        FactoryBot.create(:template_input, template: correct_template, input_type: 'user', name: 'job_id')
        templates = Setting::RemoteExecution.job_invocation_report_templates_select

        templates.must_include 'Job Invocation Report Template'
      end

      it 'should found correct template from setting' do
        Setting::RemoteExecution.load_defaults
        template_name = 'Job Invocation Report Template'
        setting_key = :remote_execution_job_invocation_report_template
        template = FactoryBot.create(:report_template, name: template_name)
        Setting[setting_key] = template_name
        found_template = ReportTemplate.where(name: Setting[setting_key]).first

        template.id.must_equal found_template.id
      end
    end

    describe 'test correct result for report template' do
      let(:fake_json_outputs) do
        (1..5).map do |i|
          { type: 'sometype', value: "message#{i}\n" }
        end
      end
      let(:fake_task) { FakeTask.new(action_output: { outputs: fake_json_outputs }, ended_at: (Time.now - 1.hour)) }

      it 'should process the result of task to template' do
        job_invocation = FactoryBot.create(:job_invocation, :with_task)
        JobInvocation.any_instance.expects(:sub_task_for_host).returns(fake_task)

        template_source = File.read(File.expand_path(File.dirname(__FILE__) + "/../../app/views/report_templates/jobs_invocations.erb"))
        template = ReportTemplate.import_without_save("Job Invocation Report Template", template_source)
        template.save!
        input = template.template_inputs.first
        params = {template_id: template.id, input_values: {input.id.to_s => {value: job_invocation.id.to_s} } }
        composer = ReportComposer.new(params)
        time = Time.now
        data = composer.render
        #todo assertion
      end
    end
  end
end
