# Controller for admin pages
class OrgsController < ApplicationController
  before_action :verify_admin
  skip_before_filter :verify_authenticity_token
  @@less_noise = TRUE

  # GET /orgs
  def index
    @less_noise = @@less_noise
    # The org you are viewing (unsummed and summed)
    @org = Org.find_by(parent_id: nil)
    @summed_org = @org
    # The direct sub-orgs of the org you are viewing (unsummed and summed)
    @direct_suborgs = Org.where(parent_id: @org.id)
    @direct_summed_suborgs = SumsForOrg.where(entity_type: "Org", type_id: JSON.parse((Org.where(parent_id: @org.id).pluck(:id)).to_s)).where.not(type_id: @org.id)
    # All sub-orgs of the org you are viewing (unsummed and summed)
    @all_suborgs = Org.where(id: JSON.parse((Org.where.not(parent_id: nil).pluck(:id)).to_s)).where.not(id: @org.id)
    @all_summed_suborgs = SumsForOrg.where(entity_type: "Org", type_id: JSON.parse((Org.where.not(parent_id: nil).pluck(:id)).to_s)).where.not(type_id: @org.id)
    get_notebooks()
  end

  # GET /orgs/:name
  def show
    @less_noise = @@less_noise
    # The org you are viewing (unsummed and summed)
    @org = Org.find_by(id: params[:id])
    @summed_org = SumsForOrg.find_by(type_id: params[:id])
    # Helper for calculating sub-orgs
    @children = Array.new
    grab_children([params[:id].to_i])
    ids = @children.flatten.reject(&:blank?).uniq
    # The direct sub-orgs of the org you are viewing (unsummed and summed)
    @direct_suborgs = Org.where(parent_id: @org.id)
    @direct_summed_suborgs = SumsForOrg.where(entity_type: "Org", type_id: JSON.parse((Org.where(parent_id: @org.id).pluck(:id)).to_s)).where.not(type_id: @org.id)
    # All sub-orgs of the org you are viewing (unsummed and summed)
    @all_suborgs = Org.where(id: JSON.parse((Org.where(id: JSON.parse(ids.to_s)).pluck(:id)).to_s))
    @all_summed_suborgs = SumsForOrg.where(entity_type: "Org", type_id: JSON.parse((Org.where(id: JSON.parse(ids.to_s)).pluck(:id)).to_s)).where.not(type_id: @org.id)
    get_notebooks()
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

  def calculate_org_sums
    Org.where.not(parent_id: nil).each do |org|
      org_id_array = [org.id]
      @children = []
      grab_children(org_id_array)
      ids = @children.flatten.reject(&:blank?).uniq
      ids.each do |id|
        SumsForOrg.find_or_create_by(entity_type: "Org", type_id: id)
      end
      all_org_children = Org.where(id: JSON.parse(ids.to_s))
      # With the children, caclulate for each
      summed_org = SumsForOrg.where(entity_type: "Org", type_id: org.id).first
      summed_org.score = all_org_children.sum(:notebook_runs) * 10 + all_org_children.sum(:notebook_views)
      summed_org.users = all_org_children.sum(:users)
      summed_org.notebooks = all_org_children.sum(:notebooks)
      summed_org.groups = all_org_children.sum(:groups)
      summed_org.notebook_views = all_org_children.sum(:notebook_views)
      summed_org.notebook_runs = all_org_children.sum(:notebook_runs)
      summed_org.notebook_stars = all_org_children.sum(:notebook_stars)
      summed_org.notebook_shares = all_org_children.sum(:notebook_shares)
      summed_org.notebook_downloads = all_org_children.sum(:notebook_downloads)
      summed_org.save!
    end
  end
  helper_method :calculate_org_sums

  def grab_children(org_id_array)
    org_id_array.each do |child_id|
      if !Org.where(parent_id: child_id).exists?
        @children.push(child_id)
        org_id_array.delete(child_id)
        return @children.flatten.to_s
      else
        @children.push(child_id)
        org_id_array.delete(child_id)
        org_id_array.push(Org.where(parent_id: child_id).pluck(:id))
        grab_children(org_id_array)
      end
    end
  end

  def calculate_user_sums
    User.where(org: JSON.parse(@all_suborgs.pluck(:name).to_s)).each do |user|
      user_stats = SumsForOrg.find_or_create_by(entity_type: "User", type_id: user.id)
      user_stats.groups = GroupMembership.where(user_id: user.id, owner: 1).count
      notebooks_count = 0; views = 0; runs = 0; stars = 0; share_count = 0; downloads = 0;
      notebooks = Notebook.where(owner_type: "User", owner_id: user.id)
      notebooks_count += notebooks.count
      notebooks.each do |notebook|
        views += NotebookSummary.find(notebook.id).unique_views
        runs += NotebookSummary.find(notebook.id).unique_runs
        stars += NotebookSummary.find(notebook.id).stars
        downloads += NotebookSummary.find(notebook.id).unique_downloads
        #share_count += Share.where(notebook_id: notebook.id).count
      end
      notebooks = Notebook.where(creator_id: user.id).where.not(owner_type: "User", owner_id: user.id)
      notebooks_count += notebooks.count
      notebooks.each do |notebook|
        views += NotebookSummary.find(notebook.id).unique_views
        runs += NotebookSummary.find(notebook.id).unique_runs
        stars += NotebookSummary.find(notebook.id).stars
        downloads += NotebookSummary.find(notebook.id).unique_downloads
        #share_count += Share.where(notebook_id: notebook.id).count
      end
      user_stats.notebooks = notebooks_count
      user_stats.score = runs * 10 + views
      user_stats.notebook_views = views
      user_stats.notebook_runs = runs
      user_stats.notebook_stars = stars
      user_stats.notebook_downloads = downloads
      #user_stats.notebook_shares = share_count
      user_stats.save!
    end
  end
  helper_method :calculate_user_sums

  def get_notebooks
    if TRUE
      notebook_ids = Array.new
      @all_suborgs.each do |org|
        User.where(org: org.name).each do |user|
          notebook_ids.push(Notebook.where(owner_type: "User", owner_id: user.id).pluck(:id))
          GroupMembership.where(user_id: user.id, owner: 1).each do |group|
            notebook_ids.push(Notebook.where(owner_type: "Group", owner_id: group.id).pluck(:id))
          end
        end
      end
      notebook_ids = notebook_ids.flatten.reject(&:blank?).uniq
      @notebooks = query_notebooks.where(id: JSON.parse((notebook_ids).to_s))
      respond_to do |format|
        format.html
        format.json {render 'notebooks/index'}
        format.rss {render 'notebooks/index'}
      end
    else
      @notebooks = query_notebooks.where(public: TRUE)
      respond_to do |format|
        format.html
        format.json {render 'notebooks/index'}
        format.rss {render 'notebooks/index'}
      end
    end
  end

  #groups = GroupMembership.where(user_id: user.id, owner: 1)
  #groups.each do |group|
  #  notebooks = Notebook.where(owner_type: "Group", owner_id: group.group_id)
  #  notebooks_count += notebooks.count
  #  notebooks.each do |notebook|
  #    views += NotebookSummary.find(notebook.id).unique_views
  #    runs += NotebookSummary.find(notebook.id).unique_runs
  #    stars += NotebookSummary.find(notebook.id).stars
  #    downloads += NotebookSummary.find(notebook.id).unique_downloads
  #    #share_count += Share.where(notebook_id: notebook.id).count
  #  end
  #end

end
