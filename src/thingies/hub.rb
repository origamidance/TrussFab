require 'src/thingies/thingy.rb'
require 'src/models/model_storage.rb'

class Hub < Thingy
  def initialize(position, id: nil, color: nil)
    super(id)
    @position = position
    @model = ModelStorage.instance.models['ball_hub']
    @color = color unless color.nil?
    @entity = create_entity
    @pods = {}
    @id_label = nil
    update_id_label
  end

  def pods
    @pods.values
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
    @sub_thingies.each { |entity| entity.update_position(position) }
    @pods.each_value { |pod| pod.update_position(position)}
  end

  def add_pod(direction, id: nil)
    pod = Pod.new(@position, direction, id: id)
    id = pod.id
    pod.parent = self
    @pods[id] = pod
  end

  def delete_pod(id)
    pod = @pods[id]
    pods.delete(id)
    pod.delete
  end

  def delete
    delete_pods
    super
  end

  def delete_pods
    @pods.each do |id, pod|
      @pods.delete(id)
      pod.delete
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
