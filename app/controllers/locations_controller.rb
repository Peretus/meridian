class LocationsController < ApplicationController
  def index
    respond_to do |format|
      format.html
      format.json { render json: Location.to_geojson }
    end
  end
end 