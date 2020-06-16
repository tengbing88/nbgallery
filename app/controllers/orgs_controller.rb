# Controller for admin pages
class OrgsController < ApplicationController
  before_action :verify_admin
  skip_before_filter :verify_authenticity_token

  # GET /admin/org_chart/
  def index
  end

  # PATCH /admin/org_chart/add
  def add_org
    flash[:success] = "Org added to org chart successfully."
    redirect_to(:back)
  end

  # POST /admin/org_chart/generate_orgs_from_profiles
  def generate_from_profiles
    if @orgs == nil
      orgs = User.where.not(org: nil).and(User.where(org: "")).uniq.pluck(:org).sort
      Org.create(name: "All")
      if (orgs.length < 1)
        flash[:success] = "Your users don't seem to have any orgs assigned to them. Generated org chart successful."
      elsif (orgs.length >= 1)
        orgs.each do |org|
          Org.create(name: org, parent_id: "1")
        end
        flash[:success] = "Org chart generation successful."
      end
    else
      flash[:error] = "Org Chart has aleady been generated. If you wish to generate from user profiles you must first delete the current org chart."
    end
    redirect_to(:back)
  end

  # POST /admin/org_chart/generate_orgs_from_file
  def generate_from_file
    # flash[:success] = "Org chart generation successful."
    redirect_to(:back)
  end

  # PATCH /admin/org_chart/edit
  def edit
    flash[:success] = "Org was modified successfully."
    redirect_to(:back)
  end
end
