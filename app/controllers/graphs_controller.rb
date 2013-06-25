class GraphsController < ApplicationController
  before_action :set_root
  before_action :set_graph, only: [:show, :edit, :update, :destroy, :view_graph, :edit_graph]
  before_action :set_graphs, only: [:list_graph, :tag_graph]
  before_action :set_view_graph_params, only: [:view_graph, :list_graph, :tag_graph]
  before_action :path_redirect, only: [:tree_graph]
  before_action :tag_redirect, only: [:tag_graph]
  before_action :autocomplete_search, only: [:autocomplete_graph]
  before_action :tagselect_search, only: [:tagselect_graph]

  # GET /tree_graph
  def tree_graph
  end

  # GET /list_graph
  def list_graph
  end

  # GET /view_graph
  def view_graph
  end

  # GET /edit_graph
  def edit_graph
  end

  # GET /tag_graph
  def tag_graph
    @tab = 'tag'
    render action: 'list_graph'
  end

  # GET /autocomplete_graph?term=xxx for ajax autocomplete
  def autocomplete_graph
    render :json => @autocomplete.map {|node|
      description = node.description ? " (#{node.description})" : ""
      {label: "#{node.path}#{description}", value: node.path}
    }
  end

  # GET /tagselect_graph?term=xxx for ajax tag autocomplete
  def tagselect_graph
    render :json => @tagselect.map(&:name)
  end

  # GET /graphs
  # GET /graphs.json
  def index
    @graphs = Graph.all.order('path ASC')
  end

  # GET /graphs/1
  # GET /graphs/1.json
  def show
  end

  # GET /graphs/new
  def new
    @graph = Graph.new
  end

  # GET /graphs/1/edit
  def edit
  end

  # POST /graphs
  # POST /graphs.json
  def create
    success = ActiveRecord::Base.transaction do
      @graph = Graph.find_or_create(graph_params)
      $mfclient.post_graph(@graph.path, post_params)
    end

    respond_to do |format|
      if success
        format.html { redirect_to @graph, notice: 'Graph was successfully created.' }
        format.json { render action: 'show', status: :created, location: @graph }
      else
        format.html { render action: 'new' }
        format.json { render json: @graph.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /graphs/1
  # PATCH/PUT /graphs/1.json
  def update
    success = ActiveRecord::Base.transaction do
      @graph.update(graph_params)
      $mfclient.edit_graph(@graph.path, update_params)
    end

    respond_to do |format|
      if success
        format.html { redirect_to view_path(@graph.path), notice: 'Graph was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @graph.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /graphs/1
  # DELETE /graphs/1.json
  def destroy
    success = ActiveRecord::Base.transaction do
      @graph.destroy
      @graph = $mfclient.delete_graph(@graph.path) rescue nil
    end
    respond_to do |format|
      format.html { redirect_to graphs_url }
      format.json { head :no_content }
    end
  end

  private

  def post_params
    # ToDo
    {:number => 0}
  end

  def update_params
    # ToDo
    {}
  end

  def set_view_graph_params
    @view_graph_params = params.slice(:t, :from, :to, :size, :width, :height)
    term = params[:t] || 'd'
    from = params[:from].present? ? Time.parse(params[:from]) : nil
    to   = params[:to].present?   ? Time.parse(params[:to])   : nil
    size = params[:size].presence || 'M'
    width  = Settings.graph.sizes[size]['width']
    height = Settings.graph.sizes[size]['height']
    @graph_uri_params = {
      't'      => term,
      'from'   => from,
      'to'     => to,
      'width'  => width,
      'height' => height
    }

    if graph = @graph || @graphs.first
      graph = graph.decorate
      graph.term   = term
      graph.from   = from
      graph.to     = to
      graph.size   = size
      graph.width  = width
      graph.height = height
      graph.validate
      flash[:alert] = graph.view_errors
    end
  end

  def tag_redirect
    return unless (tag_list = request.query_parameters[:tag_list])
    redirect_to "#{tag_graph_root_path}/#{URI.escape(tag_list)}"
  end

  def path_redirect
    return unless (path = request.query_parameters[:path])
    not_found unless (node = Node.find_by(path: path))
    if node.root?
      redirect_to tree_path
    elsif node.has_children?
      redirect_to list_path(path)
    else
      redirect_to view_path(path)
    end
  end

  def set_tags
    @tags = Graph.tag_counts_on(:tags).order('count DESC')
  end

  def set_root
    if params[:path].present?
      @root = Node.where(path: params[:path]).first
    else
      @root = Node.roots.first
    end
  end

  def tagselect_search
    case
    when params[:term]
      term = params[:term].gsub(/ /, '%')
      @tagselect = Tag.select(:name).where("name LIKE ?", "#{term}%") # "%#{term}%")  
    else
      @tagselect = Tag.select(:name).all
    end
    @tagselect = @tagselect.order('name ASC').limit(Settings.try(:autocomplete).try(:limit))
  end

  def autocomplete_search
    case
    when params[:term]
      term = params[:term].gsub(/ /, '%')
      @autocomplete = Node.select(:path, :description).where("path LIKE ?", "%#{term}%")
    else
      @autocomplete = Node.select(:path, :description).all
    end
    @autocomplete = @autocomplete.without_roots.order('path ASC').limit(Settings.try(:autocomplete).try(:limit))
  end

  def set_graphs
    case
    when params[:tag_list].present?
      @graphs = Graph.tagged_with(params[:tag_list].split(',')).order('path ASC')
    when params[:path].present?
      @graphs = Graph.where("path LIKE ?", "#{params[:path]}/%").order('path ASC')
    else
      @graphs = []
    end
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_graph
    @graph = params[:id] ? Graph.find(params[:id]) : Graph.find_by(path: params[:path])
    not_found unless @graph
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def graph_params
    params.require(:graph).permit(:path, :description, :tag_list)
  end
end
