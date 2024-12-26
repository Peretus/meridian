class LocationsController < ApplicationController
  def index
    respond_to do |format|
      format.html
      format.json { render json: Location.to_geojson }
    end
  end

  def florida
    respond_to do |format|
      format.html
      format.json { render json: Location.in_florida.to_geojson }
    end
  end

  def gallery
    @locations = Location.where.not(fetched_at: nil)
                        .order(fetched_at: :desc)
                        .page(params[:page])
                        .per(200)
  end

  def classify
    @location = Location.where(human_classification: nil)
                       .where.not(fetched_at: nil)
                       .order(created_at: :asc)
                       .first

    if @location.nil?
      redirect_to locations_path, notice: 'No more locations to classify!'
    end
  end

  def update_classification
    @location = Location.find(params[:id])
    classification = params[:classification].to_i
    
    if @location.update(human_classification: classification)
      next_location = Location.where(human_classification: nil)
                             .where.not(fetched_at: nil)
                             .order(created_at: :asc)
                             .first

      if next_location
        render json: { redirect_url: classify_locations_path }
      else
        render json: { redirect_url: locations_path, message: 'No more locations to classify!' }
      end
    else
      render json: { error: 'Failed to update classification' }, status: :unprocessable_entity
    end
  end
end 