# Creates visualizations of a data sample (= plotting a circle at the position) and relevant parameters like
# acceleration and velocity.
class DataSampleVisualization
  attr_reader :position

  TRACE_DOT_ALPHA = 0.6

  def initialize(data_sample, node_id, definition, ratio, is_max_acceleration , circle_definition)
    @data_sample = data_sample
    @node_id = node_id
    @definition = definition
    @ratio = ratio
    @is_max_acceleration = is_max_acceleration
    @circle_definition = circle_definition

    @position = @data_sample.position_data[@node_id]
    @circle_layer = Sketchup.active_model.layers[Configuration::MOTION_TRACE_VIEW]
    @debugging_layer = Sketchup.active_model.layers.at(Configuration::SPRING_DEBUGGING)
    @circle_instance = nil

    @velocity_line = nil
    @acceleration_line = nil

    @acceleration_label = nil
    @velocity_label = nil
  end

  # Adds a circle visualization representing the data sample to the passed sketchup group.
  def add_dot_to_group(group)
    # Transform circle definition to match current data sample
    # dots shouldn't be scaled down below half the original size
    scale_factor = Geometry.clamp(@ratio, 0.5, 1.0)
    scaling = Geom::Transformation.scaling(scale_factor, 1.0, scale_factor)
    translation = Geom::Transformation.translation(@position)
    transformation = translation * scaling

    color_min_value = 50.0
    color_max_value = 100.0
    color_hue = 117
    color_weight = @ratio * color_min_value

    @circle_instance = group.entities.add_instance(@circle_definition, transformation)
    @circle_instance.layer = @circle_layer

    if @is_max_acceleration
      @circle_instance.material = "red"
    else
      @original_material = material_from_hsv(color_hue, color_min_value + color_weight,
                                             color_max_value - color_weight)
      @circle_instance.material = @original_material
    end
  end

  def add_velocity_to_group(group, velocity)
    scale = 100

    @velocity_label = add_label_for_parameter_to_group(group, velocity, scale, 'm/s')
    @velocity_label.hidden = true

    @velocity_line = add_vector_to_group(group, velocity, 100, '_')
    @velocity_line.hidden = true
  end

  def add_acceleration_to_group(group, acceleration)
    scale = 10

    @acceleration_label = add_label_for_parameter_to_group(group, acceleration, scale, 'm/s^2')
    @acceleration_label.hidden = true

    @acceleration_line = add_vector_to_group(group, acceleration, 10, '.')
    @acceleration_line.hidden = true
  end

  def highlight
    @circle_instance.material = "gray"
    @circle_instance.material.alpha = TRACE_DOT_ALPHA
    @acceleration_line.hidden = false
    @velocity_line.hidden = false
    @acceleration_label.hidden = false
    @velocity_label.hidden = false
  end

  def un_highlight
    @circle_instance.material = @original_material
    @acceleration_line.hidden = true
    @velocity_line.hidden = true
    @acceleration_label.hidden = true
    @velocity_label.hidden = true
  end

  private

  def add_vector_to_group(group, vector, scale, stipple)
    scaled_vector = Geometry.scale(vector, scale)
    vector_line = group.entities.add_cline(@position, @position + scaled_vector, stipple)
    vector_line.layer = Sketchup.active_model.layers[Configuration::MOTION_TRACE_VIEW]
    vector_line
  end

  def add_label_for_parameter_to_group(group, vector, scale, unit)
    label = group.entities.add_text("#{vector.length.round(2).to_s}#{unit}", @position + Geometry.scale(vector, scale))
    label.layer = Sketchup.active_model.layers[Configuration::MOTION_TRACE_VIEW]
    label
  end

  def material_from_hsv(h,s,v)
    material = Sketchup.active_model.materials.add("VisualizationColor #{v}")
    material.color = hsv_to_rgb(h, s, v)
    material.alpha = TRACE_DOT_ALPHA
    material
  end

  # http://martin.ankerl.com/2009/12/09/how-to-create-random-colors-programmatically
  def hsv_to_rgb(h, s, v)
    h, s, v = h.to_f / 360, s.to_f / 100, v.to_f / 100
    h_i = (h * 6).to_i
    f = h * 6 - h_i
    p = v * (1 - s)
    q = v * (1 - f * s)
    t = v * (1 - (1 - f) * s)
    r, g, b = v, t, p if h_i == 0
    r, g, b = q, v, p if h_i == 1
    r, g, b = p, v, t if h_i == 2
    r, g, b = p, q, v if h_i == 3
    r, g, b = t, p, v if h_i == 4
    r, g, b = v, p, q if h_i == 5
    # [(r*255).to_i, (g*255).to_i, (b*255).to_i]
    Sketchup::Color.new((r * 255).to_i, (g * 255).to_i, (b * 255).to_i)
  end

end