require 'set'

# Used to handle mouse pointer related issue, can snap to objects, maps input points to useful ones.
class MouseInput
  attr_reader :position, :snapped_object

  def initialize(snap_to_nodes: false, snap_to_edges: false, snap_to_surfaces: false, snap_to_pods: false, snap_to_covers: false)
    @snap_to_nodes = snap_to_nodes
    @snap_to_edges = snap_to_edges
    @snap_to_surfaces = snap_to_surfaces
    @snap_to_pods = snap_to_pods
    @snap_to_covers = snap_to_covers
    @position = nil
    soft_reset
  end

  def soft_reset
    @position = nil
    unless @snapped_object.nil? || @snapped_object.deleted?
      @snapped_object.un_highlight
    end
    @snapped_object = nil
  end

  # NB: In the old version, there was given a reference point to the InputPoint
  # but it was not clear why.
  def update_positions(view, x, y, point_on_plane_from_camera_normal: nil)
    soft_reset

    input_point = Sketchup::InputPoint.new
    input_point.pick(view, x, y, Sketchup::InputPoint.new)
    @position = input_point.position

    snap_to_object
    @snapped_object.highlight unless @snapped_object.nil?
    @position = @snapped_object.position if @snapped_object

    # For some reason, we don't have go find the intersection on the plane if
    # it finds objects to snap on.
    if !point_on_plane_from_camera_normal.nil? && !@snapped_object
      # pick a point on the plance of the camera normale
      normal = view.camera.direction
      plane = [point_on_plane_from_camera_normal, normal]
      pickray = view.pickray(x, y)
      @position = Geom.intersect_line_plane(pickray, plane)
    end

    @position
  end

  def out_of_snap_tolerance?(object)
    object.distance(@position) > Configuration::SNAP_TOLERANCE
  end

  def snap_to_object
    objects = []
    if @snap_to_edges
      edge = Graph.instance.closest_edge(@position)
      objects.push(edge) unless edge.nil? || out_of_snap_tolerance?(edge)
    end
    if @snap_to_nodes
      node = Graph.instance.closest_node(@position)
      objects.push(node) unless node.nil? || out_of_snap_tolerance?(node)
    end
    if @snap_to_surfaces
      surface = Graph.instance.closest_surface(@position)
      unless surface.nil? || out_of_snap_tolerance?(surface)
        objects.push(surface)
      end
    end
    if @snap_to_pods
      pod = Graph.instance.closest_pod(@position)
      objects.push(pod) unless pod.nil? || out_of_snap_tolerance?(pod)
    end
    if @snap_to_covers
      surface = Graph.instance.closest_surface(@position)
      if !surface.nil? && surface.cover? && !out_of_snap_tolerance?(surface)
        objects.push(surface.cover)
      end
    end
    return if objects.empty?
    @snapped_object = objects.min_by do |object|
      object.distance(@position)
    end
  end
end