require ProjectHelper.database_directory + '/graph_object.rb'
require ProjectHelper.database_directory + '/link.rb'
require ProjectHelper.model_directory + '/model_storage.rb'

class Edge < GraphObject
  attr_reader :first_node, :second_node
  def initialize first_node, second_node, link_type, model_name, first_elongation_length, second_elongation_length,
                 id: nil
    @first_node = first_node
    @second_node = second_node
    @model = ModelStorage.instance.models[model_name]
    @first_elongation_length = first_elongation_length
    @second_elongation_length = second_elongation_length
    super id
    @first_node.add_partner @second_node, self
    @second_node.add_partner @first_node, self
  end

  private
  def create_thingy id
    length = @first_node.position.distance @second_node.position
    model_length = length - @first_elongation_length - @second_elongation_length
    shortest_model = @model.find_model_shorter_than model_length
    @thingy = Link.new @first_node.position, @second_node.position, shortest_model.definition, @first_elongation_length,
                       @second_elongation_length, id: id
  end
end