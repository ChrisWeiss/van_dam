class ModelsController < ApplicationController
  before_action :get_library, except: [:index, :bulk_edit, :bulk_update]
  before_action :get_model, except: [:bulk_edit, :bulk_update, :index]
  before_action :get_filters, only: [:bulk_edit, :bulk_update, :index]

  def index
    @models = Model.all.includes(:tags, :preview_file, :creator)

    if current_user.pagination_settings["models"]
      page = params[:page] || 1
      @models = @models.page(page).per(current_user.pagination_settings["per_page"])
    end

    # Ordering
    @models = case session["order"]
    when "recent"
      @models.order(created_at: :desc)
    else
      @models.order(name: :asc)
    end

    @tags = Model.includes(:tags).map(&:tags).flatten.uniq.sort_by(&:name).select { |x| x.taggings_count > 1 }

    # filter by library?
    @models = @models.where(library: @filters[:library]) if @filters[:library]

    # Filter by tag?
    if @filters[:tag]
      @tag = ActsAsTaggableOn::Tag.named_any(@filters[:tag])
      @models = @models.tagged_with(@filters[:tag])
    end

    # Filter by collection?
    if @filters[:collection]
      @collection = ActsAsTaggableOn::Tag.for_context(:collections).find(@filters[:collection])
      @models = @models.tagged_with(@collection, context: :collection) if @collection
    end

    # Filter by creator
    case @filters[:creator]
    when nil
      nil # No creator specified, nothing to do
    when "nil"
      @models = @models.where(creator_id: nil)
    else
      @creator = Creator.find(@filters[:creator])
      @models = @models.where(creator: @creator)
    end

    # keyword search filter
    if @filters[:q]
      field = Model.arel_table[:name]
      creatorsearch = Creator.where("name LIKE ?", "%#{@filters[:q]}%")
      @models = @models.where("tags.name LIKE ?", "%#{@filters[:q]}%").or(@models.where(field.matches("%#{@filters[:q]}%"))).or(@models.where(creator_id: creatorsearch))
        .joins("INNER JOIN taggings ON taggings.taggable_id=models.id AND taggings.taggable_type = 'Model' INNER JOIN tags ON tags.id = taggings.tag_id").distinct
    end

    @commontags = ActsAsTaggableOn::Tag.joins(:taggings).where(taggings: {taggable: @models.except(:limit, :offset, :distinct)})
  end

  def show
    @groups = helpers.group(@model.model_files)
  end

  def edit
    @creators = Creator.all
    @model.links.build if @model.links.empty? # populate empty link
  end

  def update
    @model.update(model_params)
    redirect_to [@model.library, @model]
  end

  def merge
    if (target = (@model.parents.find { |x| x.id == params[:target].to_i }))
      @model.merge_into! target
      redirect_to [@library, target]
    else
      render status: :bad_request
    end
  end

  def bulk_edit
    @creators = Creator.all
    @models = Model.all
    if @filters[:library]
      @models = @models.where(library: params[:library])
      @addtags = @models.includes(:tags).map(&:tags).flatten.uniq.sort_by(&:name)
    else
      @addtags = Model.includes(:tags).map(&:tags).flatten.uniq.sort_by(&:name)
    end
    if params[:tag]
      @models = @models.tagged_with(params[:tag])
    end
    if params[:collection]
      @collection = ActsAsTaggableOn::Tag.for_context(:collections).find(params[:collection])
      @models = @models.tagged_with(@collection, context: :collection) if @collection
    end
    @models = @models.where(creator_id: params[:creator]) if params[:creator]
    if params[:q]
      field = Model.arel_table[:name]
      @models = @models.where("tags.name LIKE ?", "%#{params[:q]}%").or(@models.where(field.matches("%#{params[:q]}%")))
        .joins("INNER JOIN taggings ON taggings.taggable_id=models.id AND taggings.taggable_type = 'Model' INNER JOIN tags ON tags.id = taggings.tag_id").distinct
    end
  end

  def bulk_update
    hash = bulk_update_params
    hash[:library_id] = hash.delete(:new_library_id) if hash[:new_library_id]

    add_tags = Set.new(hash.delete(:add_tags))
    remove_tags = Set.new(hash.delete(:remove_tags))
    collection_list = Set.new(hash.delete(:collection_list)).compact_blank

    params[:models].each_pair do |id, selected|
      if selected == "1"
        model = Model.find(id)
        if model.update(hash)
          existing_tags = Set.new(model.tag_list)
          model.tag_list = existing_tags + add_tags - remove_tags
          model.collection_list = collection_list unless collection_list.empty?
          model.save
        end
      end
    end
    redirect_to edit_models_path(@filters)
  end

  def destroy
    @model.destroy
    redirect_to library_path(@library)
  end

  private

  def bulk_update_params
    params.permit(
      :creator_id,
      :new_library_id,
      :organize,
      add_tags: [],
      remove_tags: [],
      collection_list: []
    ).compact_blank
  end

  def model_params
    params.require(:model).permit(
      :preview_file_id,
      :creator_id,
      :library_id,
      :name,
      :caption,
      :notes,
      :collection,
      :q,
      :library,
      :creator,
      :tag,
      :organize,
      collection_list: [],
      tag_list: [],
      links_attributes: [:id, :url, :_destroy]
    )
  end

  def get_library
    @library = Model.find(params[:id]).library
  end

  def get_model
    @model = Model.includes(:model_files, :creator).find(params[:id])
    @title = @model.name
  end

  def get_filters
    # Get list filters from URL
    @filters = params.permit(:library, :collection, :q, :creator, tag: [])
  end
end
