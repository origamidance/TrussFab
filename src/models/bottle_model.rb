require 'src/models/bottle.rb'

# BottleModel
class BottleModel
  attr_reader :name, :models, :material

  def initialize(name, specifications, material = 'bottle_material')
    @name = name
    @models = {}
    @material = Sketchup.active_model.materials[material]
    specifications.each do |specification|
      @models[specification[:NAME]] = create_model(specification)
    end
  end

  def longest_model_shorter_than(length)
    long_model = shortest_model
    @models.values.each do |model|
      next if model.length > length
      long_model = model if model.length > long_model.length
    end
    long_model
  end

  def shortest_model_longer_than(length)
    short_model = longest_model
    @models.values.each do |model|
      next if model.length < length
      short_model = model if model.length < short_model.length
    end
    short_model
  end

  def longest_model
    @models.values.max_by(&:length)
  end

  def shortest_model
    @models.values.min_by(&:length)
  end

  def valid?
    @models.each { |_, model| return false unless model.valid? }
    true
  end

  private

  def create_model(specification)
    # Sketchup Component Definitions
    components = Sketchup.active_model.definitions
    name = specification[:NAME]
    short_name = specification[:SHORT_NAME]
    if components[name]
      model = components[name]
    else
      definition = components.load specification[:PATH]
      model = Bottle.new(name, short_name, specification[:WEIGHT], definition, self)
    end
    model
  end
end
