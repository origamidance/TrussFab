require_relative 'tool.rb'

# Tool that allows users to pull a line from a node to interact with the model / gemoetry.
class PullNodeInteractionTool < Tool
  def initialize(ui)
    super(ui)
    @mouse_input = MouseInput.new(snap_to_edges: true, snap_to_nodes: true)

    @start_node = nil
    @start_position = nil
    @end_position = nil
    @moving = false

  end

  def onLButtonDown(_flags, x, y, view)
    @mouse_input.update_positions(view, x, y)
    obj = @mouse_input.snapped_object
    return if obj.nil? || !obj.is_a?(Node)

    @moving = true
    @start_node = obj
    @start_position = @end_position = obj.position
  end

  def onMouseMove(_flags, x, y, view)
    update(view, x, y)
  end

  def onLButtonUp(_flags, x, y, view)
    update(view, x, y)
  end

  def update(view, x, y)
    @mouse_input.update_positions(view, x, y, point_on_plane_from_camera_normal: @start_position || nil)

    return unless @moving && @mouse_input.position != @end_position

    @end_position = @mouse_input.position
    view.invalidate
  end

  def reset
    @start_node = nil
    @start_position = nil
    @end_position = nil
    @moving = false
  end

  def draw(view)
    return unless @moving

    view.line_stipple = ''
    view.line_width = 7
    view.drawing_color = 'black'
    view.draw_lines(@start_position, @end_position)
  end
end
