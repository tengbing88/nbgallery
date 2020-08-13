# Controller for admin pages
class OrgsController < ApplicationController
  before_action :verify_admin
  skip_before_filter :verify_authenticity_token

  # GET /orgs
  def index
    # @orgs = Org.where.not(parent_id: nil)
  end

  # GET /orgs/:name
  def show
    @org = Org.find_by(id: params[:id])
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
    if request.xhr?
      render :js => "window.location = '#{admin_org_chart_path}'"
    else
      redirect_to(:back)
    end
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
    if request.xhr?
      render :js => "window.location = '#{admin_org_chart_path}'"
    else
      redirect_to(:back)
    end
  end

  # POST /admin/org_chart/generate_orgs_from_file
  def generate_from_file
    error = ""
    if params[:file].present?
      file = params[:file]
      name = params[:file].original_filename
      puts "file is present and file: #{file} has name #{name}."
      if file.size > 100000
        error += "Are you sure you uploaded a real .csv file? Your file was too large. Expected under or around 1KB-10KB size, but received one of size: #{file.size/1000} KBs. "
      elsif File.extname(name) != ".csv"
        error += "Somehow you tricked the form and uploaded a non .csv file. Please upload a .csv file. Received file was #{name} with extension #{File.extname(name)}."
      end
    else
      error += "File was not uploaded. Try again. "
    end
    if error == ""
      file = params[:file].path
      csv = CSV.parse(File.read(file))
      problem = false
      if Org.count == 0
        last_element = Org.create(name: "All")
        last_element.save!
        last_element_col = -1
        csv.each_with_index do |row,row_index|
          csv[row_index].each_with_index do |col,col_index|
            if (col != nil && col.to_s.strip != "")

              # Check if there are duplicated orgs
              elements = csv.flatten
              duplicated = false
              elements.each do |ele|
                if ele.to_s.downcase == col.to_s.downcase
                  if duplicated == true
                    error = "CSV file has an org included more than once. Duplicated org is '#{ele}'."
                    problem = true
                    break
                  else
                    duplicated = true
                  end
                end
              end

              # Check if CSV is improperly formatted
              csv[row_index].each_with_index do |ele,index|
                if (ele != nil && ele.to_s.strip != "" && index != col_index)
                  if col_index < index
                    error = "CSV file was improperly formatted. Includes multiple values on the same row. Only one element can exist per row. Problem found at row #{row_index + 1} column #{col_index + 1} and #{index + 1}."
                  else
                    error = "CSV file was improperly formatted. Includes multiple values on the same row. Only one element can exist per row. Problem found on row #{row_index + 1} column #{index + 1} and #{col_index + 1}."
                  end
                  problem = true
                  break
                end
              end

              # Creating Orgs
              if !problem && col != nil && col.to_s.strip != ""
                if last_element_col < col_index
                  last_element = Org.create(name: col.to_s, parent_id: last_element.id)
                  last_element.save!
                  last_element_col = col_index
                elsif last_element_col >= col_index
                  while (last_element_col >= col_index)
                    last_element = Org.find(last_element.parent_id)
                    last_element_col = last_element_col - 1
                  end
                  last_element = Org.create(name: col.to_s, parent_id: last_element.id)
                  last_element.save!
                  last_element_col = col_index
                else
                  error = "Unknown problem encountered while populating database with org from CSV file. Issue occured at row #{row_index + 1} column #{col_index + 1}."
                  problem = true
                end
              end
            end
            if problem
              break
            end
          end
          if problem
            break
          end
        end
      else
        error = "Org table is already populated. CSV file was rejected. Refresh the page."
      end
      if error != ""
        Org.delete_all
        render json: { Error: error }, status: :internal_server_error
      else
        flash[:success] = "Org chart generation successful."
        render json: {forward: org_chart_index_path}
      end
    else
      render json: { Error: error }, status: :internal_server_error
    end
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
    if request.xhr?
      render :js => "window.location = '#{admin_org_chart_path}'"
    else
      redirect_to(:back)
    end
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
    if request.xhr?
      render :js => "window.location = '#{admin_org_chart_path}'"
    else
      redirect_to(:back)
    end
  end

end
