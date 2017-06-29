require 'src/thingies/thingy.rb'
require 'src/models/model_storage.rb'

class Hub < Thingy
  def initialize(position, id: nil, color: nil)
    super(id)
    @position = position
    @model = ModelStorage.instance.models['ball_hub']
    @color = color unless color.nil?
    @entity = create_entity
    @id_label = nil
    update_id_label
  end

  def pods
    @sub_thingies.select { |sub_thingy| sub_thingy.is_a?(Pod) }
  end

  def highlight(highlight_color = @highlight_color)
    change_color(highlight_color)
  end

  def un_highlight
    change_color(@color)
  end

  def update_position(position)
    @position = position
    @entity.move!(Geom::Transformation.new(position))
    @sub_thingies.each { |sub_thingy| sub_thingy.update_position(position) }
  end

  def add_pod(direction, id: nil)
    pod = Pod.new(@position, direction, id: id)
    id = pod.id
    pod.parent = self
    add(pod)
    pod
  end

  def delete_sub_thingy(id)
    @sub_thingies.each do |sub_thingy|
      next unless sub_thingy.id == id
      sub_thingy.delete
      remove(sub_thingy)
    end
  end

  private

  def create_entity
    return @entity if @entity
    position = Geom::Transformation.translation(@position)
    transformation = position * @model.scaling
    entity = Sketchup.active_model.entities.add_instance(@model.definition,
                                                         transformation)
    entity.layer = Configuration::HUB_VIEW
    entity.material = @color
    entity
  end

  def update_id_label
    label_position = @position
    if @id_label.nil?
      @id_label = Sketchup.active_model.entities.add_text("    #{@id} ", label_position)
      @id_label.layer = Sketchup.active_model.layers[Configuration::HUB_ID_VIEW]
    else
      @id_label.point = label_position
    end
  end
end
