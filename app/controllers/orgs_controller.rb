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
    error = ""
    if params[:id].present?
      id = params[:id].to_i
    else
      error += "Failed to forward to server what org was recieving these edits. "
    end
    if params[:name].present? || params[:name].strip == ""
      name = params[:name]
    else
      error += "Name of org cannot be empty. "
    end
    if params[:parent].present?
      parent = params[:parent].to_i
    else
      error += "Parent element can't be nothing. How did you even do this? "
    end
    if error == "" && id == parent
      error += "Org can't be it's own parent. "
    end
    if error == ""
      orgs = Org.where(name: name).pluck(id)
      if orgs.length > 1
        error += "Problem with database. Two or more orgs exist with this same name already. "
      elsif orgs.length == 1 && orgs[0] != id
        error += "Can't have two orgs with the same name #{orgs[0]} cannot equal #{id}. "
      end
    end
    if error == ""
      org = Org.find(id)
      org.name = name
      org.parent_id = parent
      org.save!
      flash[:success] = "Org was modified successfully."
      redirect_to(:back)
    else
      flash[:error] = error;
      redirect_to(:back)
    end
  end
end
