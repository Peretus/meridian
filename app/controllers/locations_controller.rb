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
end 