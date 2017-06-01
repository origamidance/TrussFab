require 'src/thingies/link_entities/connector.rb'
require 'src/thingies/link_entities/elongation.rb'
require 'src/thingies/link_entities/line.rb'
require 'src/thingies/link_entities/bottle_link.rb'

class Link < Thingy
  def initialize(first_position, second_position, model_name, id: nil)
    super(id)

    @first_position = first_position
    @second_position = second_position
    @model = ModelStorage.instance.models[model_name]

    create_sub_thingies
  end

  def update_positions(first_position, second_position)
    @first_position = first_position
    @second_position = second_position
    delete_sub_thingies
    create_sub_thingies
  end

  def length
    @first_position.distance(@second_position)
  end

  def create_sub_thingies

    first_elong_length = second_elong_length = Configuration::MINIMUM_ELONGATION

    model_length = length - first_elong_length - second_elong_length
    shortest_model = @model.longest_model_shorter_than(model_length)

    first_elong_length = second_elong_length = (length - shortest_model.length) / 2


    direction = @first_position.vector_to(@second_position)
    first_elongation = Elongation.new(@first_position,
                                      direction,
                                      first_elong_length)
    link_position = @first_position.offset(first_elongation.direction)

    add(Connector.new(@first_position, direction, first_elong_length),
        first_elongation,
        BottleLink.new(link_position, direction, shortest_model.definition),
        Elongation.new(@second_position,
                       direction.reverse,
                       second_elong_length),
        Connector.new(@second_position,
                      direction.reverse,
                      second_elong_length))
  end
end
