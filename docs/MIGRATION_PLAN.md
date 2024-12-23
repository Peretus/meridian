# Location Classification System Migration Plan for Meridian

## Development Approach
We are following a Test-Driven Development (TDD) approach, building the system feature by feature:

1. Write failing tests first using minitest
2. Implement minimal code to make tests pass
3. Refactor while keeping tests green
4. Only add features and complexity as needed

All methods will be documented with clear comments explaining their purpose and usage.

### Clarifying Questions & Requirements

#### Data Volume & Performance
- **Dataset Size**: ~30k waterway points
- **Image Specifications**: 
  - Size: 224x224 pixels (optimized for TensorFlow)
  - Format: Single resolution needed initially
- **Data Loading**: 
  - Chunks of ~100 points at a time
  - Includes waypoints, images, and classifications
  - Operations should be idempotent (safe to re-run)

#### Classification Process
- **Classification Types**:
  - Human classifications (via web interface)
  - Machine classifications (one-by-one processing)
- **Processing Flow**:
  1. Find waypoints
  2. Load images
  3. Classify images by machine
  4. Queue for optional human classification
- **Storage Requirements**:
  - Preserve all classifications (both human and machine)
  - Historical classifications must be maintained

#### Image Management
- **Initial Requirements**:
  - Single size: 224x224 square images
  - Matches TensorFlow/teachable machine model requirements
- **Future Considerations**:
  - May add additional resolutions later
  - Gallery view for reviewing classifications

#### Processing Requirements
- **Real-time Processing**: Not required
- **Batch Processing**: 
  - Process in chunks
  - Support incremental building of records
- **Gallery View**:
  - Purpose: Viewing images with their classifications
  - Performance: Not time-critical

### Development Principles
- **Progressive Enhancement**: Start with core functionality, add complexity only when needed
- **We are building a generic application for classifying images of locations**: We should be adding features or names that specifically apply to this use case of marine anchorages.
- **SOLID Principles**: Following single responsibility, open/closed, etc.
- **Maintainable Tests**: Each test should:
  - Have a clear arrange/act/assert structure
  - Test one thing only
  - Use descriptive naming
  - Include context/description of what's being tested
  - Avoid brittle tests that depend on implementation details

### Testing Strategy
- **Unit Tests**: For isolated model behavior and business logic
- **Integration Tests**: For model interactions and complex workflows
- **System Tests**: For critical user paths
- **Test Data Strategy**:
  - Use fixtures with clear, descriptive names
  - Each fixture should represent a specific test scenario
  - Fixtures should be minimal and focused on the attributes being tested

### Code Organization
- Models contain business logic only
- Service objects for complex operations
- Concerns for shared behavior
- Clear separation between data access and business logic

## Technology Stack
// This is a full-stack Rails application. 
- **Backend**: Ruby on Rails 7.2.1
- **Database**: PostgreSQL with PostGIS
- **Styling**: Tailwind CSS
- **Frontend**: Import maps with Hotwire/Turbo
# - **Image Processing**: Active Storage with built-in image processing (will add when needed)
- **Testing**: Minitest

## Key Decisions
1. **Database Storage**
   # - Store images using Active Storage with built-in image processing (will add when needed)
   - Use PostGIS for spatial queries via `activerecord-postgis-adapter`
   - Simple sequential IDs for better performance and simplicity

2. **Schema Structure**
```ruby
# db/migrate/YYYYMMDDHHMMSS_create_initial_schema.rb
class CreateInitialSchema < ActiveRecord::Migration[7.2]
  def change
    enable_extension 'postgis'
    
    create_table :locations do |t|
      t.st_point :coordinates, null: false
      t.string :source, null: false
      t.datetime :fetched_at
      t.timestamps
      
      t.index :coordinates, using: :gist
    end
    
    ## Future additions when needed:
    # - Classifications
    # - Valid Results
    # - Image attachments
  end
end
```

3. **Rails Models**
```ruby
# app/models/location.rb
class Location < ApplicationRecord
  # Core validations
  validates :coordinates, :source, presence: true
  
  # Future additions when needed:
  # - Image attachments and processing
  # - Classifications
  # - Scopes for filtering
end
```

4. **API Routes**
```ruby
# config/routes.rb
Rails.application.routes.draw do
  resources :locations
  
  # Future API endpoints when needed:
  # namespace :api do
  #   resources :locations do
  #     resources :classifications, shallow: true
  #     member do
  #       get :image
  #     end
  #   end
  # end
end
```

5. **Testing Strategy Implementation**
```ruby
# test/models/location_test.rb
class LocationTest < ActiveSupport::TestCase
  test "should not save location without coordinates" do
    location = Location.new(source: "test")
    assert_not location.save
  end

  test "should not save location without source" do
    location = Location.new(coordinates: "POINT(0 0)")
    assert_not location.save
  end

  # Future spatial tests:
  # - Validate coordinate format
  # - Test spatial queries
  # - Test distance calculations
end

# test/fixtures/locations.yml
location_one:
  coordinates: "POINT(-122.47 37.80)"
  source: "test_source"
  fetched_at: <%= Time.current %>
```

Key Benefits of Simple IDs:
- Better performance for joins and lookups
- Simpler database maintenance
- More intuitive for development
- Better compatibility with Rails conventions