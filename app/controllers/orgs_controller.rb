# Controller for admin pages
class OrgsController < ApplicationController
  before_action :verify_admin
  skip_before_filter :verify_authenticity_token

  # GET /admin/org_chart/
  def index
  end

  # PATCH /admin/org_chart/add
  def add
    error = ""
    if params[:name].present? || params[:name].strip == ""
      name = params[:name].strip
    else
      error += "Name of org cannot be empty. "
    end
    if params[:parent].present?
      parent = params[:parent].to_i
    else
      error += "Parent element can't be nothing. How did you even do this? "
    end
    if error == ""
      orgs = Org.where(name: name).pluck(:id)
      if orgs.length > 1
        error += "Problem with database. Two or more orgs exist with this same name already. "
      elsif orgs.length == 1
        error += "Can't have two orgs with the same name (ignores case). Please choose a different name. "
      end
    end
    if error == ""
      org = Org.create(name: name, parent_id: parent)
      org.save!
      flash[:success] = "Org added to org chart successfully."
    else
      flash[:error] = error;
    end
    redirect_to(:back)
  end

  # POST /admin/org_chart/generate_orgs_from_profiles
  def generate_from_profiles
    if Org.count == 0
      Org.create(name: "All")
      # orgs = User.where("org != ? AND org != ?", nil, "").uniq.pluck(:org).sort
      orgs = User.where("org != ''").uniq.pluck(:org).sort
      if (orgs.length < 1)
        flash[:success] = "Your users don't seem to have any orgs assigned to them. Generated org chart successful."
      elsif (orgs.length >= 1)
        orgs.each do |org|
          Org.create(name: org, parent_id: Org.first.id)
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
    puts ">"
    puts ">"
    puts ">"
    error = ""
    if params[:file].present?
      file = params[:file]
      name = params[:file].original_filename
      puts "file is present and file: #{file} has name #{name}."
      if file.size > 100000
        error += "Are you sure you uploaded a real .csv file? Your file was too large. Expected under or around 1KB size, but received one of size: #{file.size/100000} KBs. "
      end
      if File.extname(name) != ".csv"
        error += "Somehow you tricked the form and uploaded a non .csv file. Please upload a .csv file. Received file was \"#{name}\" with extension \"#{File.extname(name)}\"."
      end
    else
      error += "File was not found to have been uploaded. Try again. "
    end
    if error == ""
      puts "no error"
      path = params[:file].path
      new_file = ""
      CSV.foreach(path) do |ele|
        if ele.to_s[-1] == "]"
          new_file += ele.to_s + "\n"
        else
          new_file += ele.to_s
        end
      end
      puts new_file
      flash[:success] = "Org chart generation successful."
    else
      puts "error of #{error}"
      flash[:error] = error;
    end
    # params[:file].delete
    puts "<"
    puts "<"
    puts "<"
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
      name = params[:name].strip
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
      orgs = Org.where(name: name).pluck(:id)
      if orgs.length > 1
        error += "Problem with database. Two or more orgs exist with this same name already. "
      elsif orgs.length == 1 && orgs[0] != id
        error += "Can't have two orgs with the same name. Please choose a different name. "
      end
    end
    if error == ""
      org = Org.find(id)
      org.name = name
      org.parent_id = parent
      org.save!
      flash[:success] = "Org was modified successfully."
    else
      flash[:error] = error;
    end
    redirect_to(:back)
  end

  # POST /admin/org_chart/delete
  def delete
    error = ""
    if params[:id].present?
      id = params[:id].to_i
    else
      error += "Failed to forward to server what org was intended for deletion. "
    end
    if error == "" && id != 0
      if Org.exists?(id)
        parent = Org.find(id).parent_id
        displaced_orgs = Org.where(parent_id: id)
        displaced_orgs.each do |org|
          org.parent_id = parent
          org.save
        end
        Org.delete(id)
        flash[:success] = "Org deleted from org chart successful."
      else
        flash[:warning] = "Org has already been deleted from org chart."
      end
    else
      Org.delete_all
      flash[:success] = "Entire org chart and orgs deleted successful."
    end
    if error == ""
    else
      flash[:error] = error;
    end
    redirect_to(:back)
  end

end
