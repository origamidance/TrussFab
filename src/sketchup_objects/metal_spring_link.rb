require 'src/sketchup_objects/generic_link.rb'
require 'src/configuration/configuration.rb'

# PhysicsLink that behaves like a gas spring
class MetalSpringLink < GenericLink
  attr_accessor :spring_constant
  
  class << self
	attr_accessor :debug
	@debug = false
  end

  def initialize(first_node, second_node, edge, id: nil, spring_constant: 1000)
    super(first_node, second_node, edge, id: id)

	#puts "metal spring object initialized"
	
    @spring_constant = spring_constant
	@initial_force = 0
	@force = @initial_force

    persist_entity
  end

  #
  # Physics methods
  #

  def update_force
	self.force =  (@default_length - length_current) * @spring_constant
	if MetalSpringLink.debug
	  puts "Länge: #{length_current}, Normallänge: #{@default_length}, F:#{@force}"
	end
  end
end
