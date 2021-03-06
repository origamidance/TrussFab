# This module handles all aspects of visualizing the result of an export, i.e.
# - visualizing hinges placements
# - coloring static substructures
# - shortening elongations of edges, that are not part of a main hub
module NodeExportVisualization
  def self.visualize(export_interface)
    visualizer = Visualizer.new
    visualizer.perform(export_interface)
  end

  # hide implementation details
  class Visualizer
    def perform(export_interface)
      export_interface.hinges.each do |hinge|
        visualize_hinge(hinge)
      end

      export_interface.subhubs.each do |subhub|
        edges = subhub.edges
        edges.zip(edges.rotate(1)).each do |edge1, edge2|
          temp_hinge = HingeExportInterface.new(edge1, edge2, false)
          visualize_hinge(temp_hinge)
        end
      end

      hinge_layer = Sketchup.active_model.layers.at(Configuration::HINGE_VIEW)
      hinge_layer.visible = true

      # shorten elongations for all edges that are not part of the main hub
      nodes = Graph.instance.nodes.values
      nodes.each do |node|
        non_mainhub_edges = export_interface.non_mainhub_edges_at_node(node)
        non_mainhub_edges.each do |edge|
          disconnect_edge_from_hub(edge, node)
        end
      end

      # color static groups differently
      color_static_groups export_interface.static_groups
    end

    def color_static_groups(static_groups)
      group_nr = 0
      static_groups.reverse.each do |group|
        color_group(group, group_nr)
        group_nr += 1
      end
    end

    private

    ELONGATION_PUSH_DISTANCE = 2.5
    LINE_VISUALIZATION_DISTANCE = 3

    def color_group(group, group_nr)
      group_color = if group_nr >= Configuration::INTENSE_COLORS.length
        format('%06x', rand * 0xffffff)
                    else
        Configuration::INTENSE_COLORS[group_nr]
                    end
      group.each do |triangle|
        triangle.edges.each do |edge|
          edge.link.material = group_color
        end
      end
    end

    def disconnect_edge_from_hub(rotating_edge, node)
      direction = rotating_edge.mid_point - node.position
      direction.length = ELONGATION_PUSH_DISTANCE

      if rotating_edge.first_node?(node)
        rotating_edge.link.disconnect_from_hub(true, direction)
      else
        rotating_edge.link.disconnect_from_hub(false, direction)
      end
    end

    def visualize_hinge(hinge)
      rotation_axis = hinge.edge1
      rotating_edge = hinge.edge2
      node = rotating_edge.shared_node(rotation_axis)

      direction1 = (rotation_axis.mid_point - node.position).normalize
      direction2 = (rotating_edge.mid_point - node.position).normalize

      direction1.length = LINE_VISUALIZATION_DISTANCE
      direction2.length = LINE_VISUALIZATION_DISTANCE

      point1 = node.position.offset(direction1)
      point2 = node.position.offset(direction2)

      mid_point = Geom::Point3d.linear_combination(0.5, point1, 0.5, point2)

      if hinge.is_double_hinge
        mid_point = Geom::Point3d.linear_combination(0.75, mid_point,
                                                     0.25, node.position)
      end

      line1 = Line.new(mid_point, point1, HINGE_LINE)
      line2 = Line.new(mid_point, point2, HINGE_LINE)

      rotating_edge.link.add(line1, line2)
    end
  end
end
