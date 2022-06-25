# frozen_string_literal: true

ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    columns do
      column do
        panel "Recent Models" do
          table do
            tbody do
              Model.all.order(:created_at).limit(20).map do |model|
                tr do
                  td { link_to(model.name, admin_model_path(model)) }
                end
              end
            end
          end
        end
      end
      column do
        panel "Task Queue" do
          table do
            tbody do
              Delayed::Job.all.order(:created_at).limit(20).map do |job|
                tr do
                  td { link_to(job.id, admin_task_path(job)) }
                end
              end
            end
          end
        end
      end
    end
  end
end