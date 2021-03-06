# Find all substructures in the whole structure, that
# are static, i.e. there is no rotation happening inside
# them, when actuators are moving.
# This is done by running a physics simulation once per
# actuator and measuring which triangles rotated in regards
# to each other. Afterwards, a recursive walk through the
# structure determines all static groups.
module StaticGroupAnalysis
  # return an array of groups of triangles that do not change their angle in
  # regards to each other
  # we call these groups static substructures
  def self.find_static_groups
    analysis = Analysis.new
    analysis.perform
  end

  # returns sets for all static groups the node is part of
  def self.get_static_groups_for_node(node)
    static_groups = find_static_groups
    nodes = map_to_set_of_nodes static_groups
    nodes.select! do |static_group|
      static_group.include? node
    end
  end

  # Takes an array of triangles in static groups, and maps them to an array
  # of sets, which contain the nodes in the static groups
  def self.map_to_set_of_nodes(static_groups)
    static_groups.map do |triangles|
      nodes = Set.new
      triangles.each do |triangle|
        nodes << triangle.first_node
        nodes << triangle.second_node
        nodes << triangle.third_node
      end
      nodes
    end
  end

  # hide implementation details
  class Analysis
    def perform
      edges = Graph.instance.edges.values
      actuators = edges.select do |edge|
        edge.link_type == 'actuator' || edge.link_type == 'spring'
      end

      # Maps from a triangle to all triangles rotating with it around a common
      # axis
      rotation_partners = Hash.new { |h, k| h[k] = Set.new }

      triangle_pairs = edges.flat_map do |e|
        valid_triangle_pairs(e)
      end

      original_angles = triangle_pair_angles(triangle_pairs)

      actuators.each do |actuator|

        # Make all other actuators really weak
        actuators.each do |a|
          a.link.power = if a == actuator
                           0.0 # This actually means maxiumum power
                         else
                           0.000001
                         end
          a.link.update_link_properties
        end

        start_simulation([actuator])

        simulation_angles = triangle_pair_angles(triangle_pairs, true)

        process_triangle_pairs(triangle_pairs, original_angles,
                               simulation_angles,
                               rotation_partners)
        @simulation.show_triangle_surfaces
      end

      actuators.each do |actuator|
        actuator.link.power = 0.0
        actuator.link.update_link_properties
      end

      start_static_group_search(edges.reject(&:dynamic?),
                                rotation_partners)
    end

    private

    MIN_ANGLE_DEVIATION = 0.0001

    def start_static_group_search(edges, rotation_partners)
      visited_triangles = Set.new
      groups = []

      triangles = Set.new(edges.flat_map(&:adjacent_triangles))
      triangles.reject!(&:dynamic?)

      loop do
        unvisited_tris = triangles - visited_triangles

        break if unvisited_tris.empty?

        triangle = unvisited_tris.to_a.sample
        new_group = Set.new

        recursive_static_group_search(triangle,
                                      new_group,
                                      visited_triangles,
                                      rotation_partners)

        groups.push(new_group)
      end

      groups
    end

    def recursive_static_group_search(triangle,
                                      group,
                                      visited_triangles,
                                      rotation_partners)
      visited_triangles.add(triangle)
      group.add(triangle)

      triangle.adjacent_triangles.reject(&:dynamic?).each do |other_triangle|
        is_visited = visited_triangles.include?(other_triangle)
        is_rotating = rotation_partners[triangle].include?(other_triangle)
        next if is_visited || is_rotating
        recursive_static_group_search(other_triangle,
                                      group,
                                      visited_triangles,
                                      rotation_partners)
      end
    end

    def valid_triangle_pairs(edge)
      edge.sorted_adjacent_triangle_pairs.select do |pair|
        pair.all?(&:complete?)
      end
    end

    def simulation_triangle_normal(triangle)
      pos1 = triangle.first_node.hub.body.get_position(1)
      pos2 = triangle.second_node.hub.body.get_position(1)
      pos3 = triangle.third_node.hub.body.get_position(1)
      vector1 = pos1.vector_to(pos2)
      vector2 = pos1.vector_to(pos3)
      vector1.cross(vector2)
    end

    def triangle_pair_angles(triangle_pairs, simulation = false)
      triangle_pairs.map do |t1, t2|
        if simulation
          n1 = simulation_triangle_normal(t1)
          n2 = simulation_triangle_normal(t2)
          n1.angle_between(n2)
        else
          t1.angle_between(t2)
        end
      end
    end

    def angle_changed?(angle, other_angle)
      (angle - other_angle).abs > MIN_ANGLE_DEVIATION
    end

    def process_triangle_pairs(triangle_pairs,
                               original_angles,
                               simulation_angles,
                               partners)
      triangle_pairs.zip(original_angles, simulation_angles).each do |pair, oa, sa|
        if angle_changed?(oa, sa)
          partners[pair[0]].add(pair[1])
          partners[pair[1]].add(pair[0])
        end
      end
    end

    def start_simulation(edges)
      @simulation = Simulation.new
      @simulation.disable_coloring
      @simulation.setup true # Ignore mass to make structure not fail
      @simulation.disable_gravity

      edges.each do |edge|
        piston = edge.link.joint
        # don't extend all the way in order not to break structure
        # TODO: find a better way to extend actuator without breaking structure
        piston.controller = edge.link.max / 4.0 if piston
      end

      @simulation.start
      @simulation.update_world_headless_by(1.0)
    end
  end
end
