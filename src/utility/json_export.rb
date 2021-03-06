require 'json'
require 'src/database/graph.rb'
require 'src/utility/geometry.rb'

# puts necessary parameters in json file for export
class JsonExport
  def self.export(path, triangle = nil, animation)
    file = File.open(path, 'w')
    # TODO: also export spring parameters and mounted users to json
    file.write(graph_to_json(triangle, animation, {}, mounted_users_to_hash(Graph.instance.nodes)))
    file.close
  end

  def self.graph_to_json(triangle = nil, animation, spring_constants_for_ids, mounted_users)
    graph = Graph.instance
    json = {distance_unit: 'mm', force_unit: 'N'}
    json[:nodes] = nodes_to_hash(graph.nodes)
    json[:edges] = edges_to_hash(graph.edges)
    json[:animation] = animation
    if triangle.nil?
      triangle = Graph.instance.triangles.first[1] # Just take any triangle
    end
    json[:spring_constants] = spring_constants_for_ids if spring_constants_for_ids
    json[:standard_surface] = triangle.nodes_ids_towards_user
    json[:mounted_users] = mounted_users if mounted_users
    JSON.pretty_generate(json)
  end

  def self.nodes_to_hash(nodes)
    nodes.map do |id, node|
      {
        id: id,
        x: node.position.x.to_mm,
        y: node.position.y.to_mm,
        z: node.position.z.to_mm,
        pods: node.pod_export_info,
        added_mass: node.hub.mass
      }
    end
  end

  def self.edges_to_hash(edges)
    edges.map do |id, edge|
      hash = {
        id: id,
        n1: edge.first_node.id,
        n2: edge.second_node.id,
        type: edge.link_type,
        bottle_type: edge.bottle_type,
        piston_group: edge.link.piston_group,
        e1: edge.link.first_elongation_length.to_mm,
        e2: edge.link.second_elongation_length.to_mm,
        uncompressed_length: edge.link_type == 'spring' ? edge.link.spring_parameters[:unstreched_length] * 1e3 : edge.length.to_mm
      }
      hash['spring_parameter_k'] = edge.link.spring_parameter_k if edge.link.is_a? SpringLink
      hash
    end
  end

  def self.mounted_users_to_hash(nodes)
    users = []
    nodes.each do |id, node|
      next unless node.hub.is_user_attached

      users << {
        id: id,
        filename: node.hub.user_indicator_filename,
        transformation: node.hub.user_transformation.to_a,
        weight: node.hub.user_weight
      }
    end
    users
  end
end
