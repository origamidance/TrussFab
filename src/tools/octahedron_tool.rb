require 'src/tools/json_tool.rb'

class OctahedronTool < JsonTool
  def initialize(ui)
    super
    @path = Configuration::OCTAHEDRON
  end
end
