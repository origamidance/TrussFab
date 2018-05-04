require 'src/tools/hinge_analysis_tool'
require 'src/export/export_hinge'
require 'src/export/export_hub'
require 'src/export/export_elongation'
require 'src/export/export_cap'
require 'src/algorithms/relaxation.rb'
require 'src/export/presets.rb'

# exports hinges to scad file
class ScadExport
  # we choose the first node to get the big hole size for the actuator
  def self.get_appropriate_actuator_hole_size(edge, node)
    if edge.first_node?(node)
      PRESETS::ACTUATOR_CONNECTOR_HOLE_SIZE_BIG
    else
      PRESETS::ACTUATOR_CONNECTOR_HOLE_SIZE_SMALL
    end
  end

  def self.create_export_hinges(hinges, node, l1, l2, l3_min, hubs)
    export_hinges = []
    hinges.each do |hinge|
      a_other_node = hinge.edge1.other_node(node)
      b_other_node = hinge.edge2.other_node(node)

      other_a_hinges = hinges.select { |other| hinge.edge1 == other.edge2 }
      other_b_hinges = hinges.select { |other| hinge.edge2 == other.edge1 }

      if other_a_hinges.size > 1 || other_b_hinges.size > 1
        raise 'More than one hinge connected to a hinge.'
      end

      elongation1 = if hinge.edge1.first_node?(node)
                      hinge.edge1.first_elongation_length
                    else
                      hinge.edge1.second_elongation_length
                    end
      elongation2 = if hinge.edge2.first_node?(node)
                      hinge.edge2.first_elongation_length
                    else
                      hinge.edge2.second_elongation_length
                    end

      a_l3 = elongation1 - l1 - l2
      b_l3 = elongation2 - l1 - l2

      if (a_l3 < l3_min || b_l3 < l3_min) &&
         !hinge.edge1.dynamic? &&
         !hinge.edge2.dynamic?
        raise "Hinge l3 distance too small: #{a_l3.to_mm}, "\
              "#{b_l3.to_mm}, #{l3_min.to_mm}."
      end

      # actuator edges don't have elongations, so just set l3 to 0
      a_l3 = 0.0.mm if hinge.edge1.dynamic?
      b_l3 = 0.0.mm if hinge.edge2.dynamic?

      # a parts always have connectors
      # b parts only if
      #   1) no other hinge connects to it OR
      #   2) is not connecting to a subhub

      is_hinge_connecting_a = !other_a_hinges.empty?
      is_sub_hub_connecting_a = false
      is_hinge_connecting_b = !other_b_hinges.empty?
      is_sub_hub_connecting_b = false

      node_hubs = hubs[node]
      node_subhubs = node_hubs.drop(1)

      if node_subhubs.any? { |edges| edges.include?(hinge.edge1) }
        is_sub_hub_connecting_a = true
      end

      if node_subhubs.any? { |edges| edges.include?(hinge.edge2) }
        is_sub_hub_connecting_b = true
      end

      a_gap = is_hinge_connecting_a || is_sub_hub_connecting_a
      b_gap = is_hinge_connecting_b || is_sub_hub_connecting_b
      a_with_connector = true
      b_with_connector = !b_gap # only adding connector when there is no gap

      hinge_params_lengths = { l1: l1, a_l3: a_l3, b_l3: b_l3 }
      # I don't know why but it has to be converted here
      hinge_params_lengths.update(hinge_params_lengths) { |_, v| v.to_mm }

      # For now, we never really though of as the 'double hinge' as
      # two separate hinges.
      # It only happens in the following steps that the ones hinges get's
      # split into two.
      if hinge.is_double_hinge
        additional_first_params = {}
        additional_second_params = {}
        if hinge.edge1.dynamic?
          a_with_connector = false
          additional_first_params[:hole_size_a] =
            get_appropriate_actuator_hole_size(hinge.edge1, node)
        end

        if hinge.edge2.dynamic?
          b_with_connector = false
          additional_second_params[:hole_size_b] =
            get_appropriate_actuator_hole_size(hinge.edge2, node)
        end

        double_hinge_id = IdManager.instance
                                   .generate_next_tag_id('double_hinge')

        first_hinge_params_others = { a_gap: a_gap,
                                      b_gap: true,
                                      a_with_connector: a_with_connector,
                                      b_with_connector: false }
        first_hinge_params =
          first_hinge_params_others.merge(hinge_params_lengths)

        first_hinge_params = first_hinge_params.merge(additional_first_params)

        first_hinge = ExportHinge.new(node.id,
                                      a_other_node.id.to_s,
                                      'V' + double_hinge_id.to_s,
                                      :double,
                                      first_hinge_params)

        second_hinge_params_others = { a_gap: true,
                                       b_gap: b_gap,
                                       a_with_connector: false,
                                       b_with_connector: b_with_connector }
        second_hinge_params =
          second_hinge_params_others.merge(hinge_params_lengths)

        second_hinge_params =
          second_hinge_params.merge(additional_second_params)

        second_hinge = ExportHinge.new(node.id,
                                       'V' + double_hinge_id.to_s,
                                       b_other_node.id.to_s,
                                       :double,
                                       second_hinge_params)

        export_hinges.push(first_hinge)
        export_hinges.push(second_hinge)
      else
        export_hinge_params_other = { a_gap: a_gap,
                                      b_gap: b_gap,
                                      a_with_connector: a_with_connector,
                                      b_with_connector: b_with_connector,
                                      alpha: hinge.angle }

        export_hinges_params =
          export_hinge_params_other.merge(hinge_params_lengths)
        export_hinge = ExportHinge.new(node.id,
                                       a_other_node.id,
                                       b_other_node.id,
                                       :simple,
                                       export_hinges_params)

        export_hinges.push(export_hinge)
      end
    end
    export_hinges
  end

  def self.create_export_hubs(hubs, hinges, l1, l2, l3_min, node, hub_id)
    export_hubs = []
    i = 0

    hubs.each do |hub|
      is_main_hub = i.zero?
      i += 1

      export_hub = if is_main_hub
                     ExportMainHub.new(hub_id, l1.to_mm)
                   else
                     ExportSubHub.new(hub_id, l1.to_mm)
                   end

      if is_main_hub
        node.pods.each do |pod|
          export_hub.add_pod(pod)
        end
      end

      hub.edges.each do |edge|
        a_hinges = hinges.select { |hinge| hinge.edge1 == edge }
        b_hinges = hinges.select { |hinge| hinge.edge2 == edge }

        if a_hinges.size > 1 || b_hinges.size > 1
          raise 'More than one A or B hinge around an edge at node ' +
                node.id.to_s
        end

        elongation = if edge.first_node?(node)
                       edge.first_elongation_length
                     else
                       edge.second_elongation_length
                     end
        other_node = edge.other_node(node)
        direction = node.position.vector_to(other_node.position).normalize

        hinge_connection = NO_HINGE
        hinge_connection = B_HINGE unless a_hinges.empty?
        hinge_connection = A_HINGE unless b_hinges.empty?
        hinge_connection = A_B_HINGE unless a_hinges.empty? || b_hinges.empty?

        if export_hub.is_a?(ExportSubHub) && hinge_connection == A_B_HINGE
          raise 'Subhub can not be connected to both A and B hinge'
        end

        l3 = elongation - l1 - l2

        if export_hub.is_a?(ExportSubHub) && l3 < l3_min
          raise 'L3 distance for hub is too small.'
        end

        export_elongation = ExportElongation.new(hub_id,
                                                 other_node.id,
                                                 hinge_connection,
                                                 l1.to_mm,
                                                 l2.to_mm,
                                                 l3.to_mm,
                                                 direction)
        export_hub.add_elongation(export_elongation)
      end

      export_hubs.push(export_hub)
    end
    export_hubs
  end

  def self.export_to_scad(path)
    hinge_algorithm = HingePlacementAlgorithm.instance
    hinge_algorithm.run

    export_interface = hinge_algorithm.export_interface

    export_hinges = []
    export_hubs = []

    l2 = PRESETS::L2
    l3_min = PRESETS::L3_MIN

    export_interface.node_hinge_map.each do |node, hinges|
      l1 = export_interface.l1_at_node(node)
      export_hinges.concat(create_export_hinges(hinges,
                                                node,
                                                l1,
                                                l2,
                                                l3_min,
                                                export_interface.node_hub_map))
    end

    export_interface.node_hub_map.each do |node, hubs|
      hub_id = node.id
      l1 = export_interface.l1_at_node(node)

      hinges = export_interface.node_hinge_map[node]
      export_hubs.concat(create_export_hubs(hubs,
                                            hinges,
                                            l1,
                                            l2,
                                            l3_min,
                                            node,
                                            hub_id))
    end

    export_hinges.each do |hinge|
      hinge.write_to_file(path)
    end

    export_hubs.each do |hub|
      hub.write_to_file(path)
    end
  end
end
