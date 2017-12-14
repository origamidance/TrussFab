require 'src/export/presets.rb'

class ExportCap
  attr_accessor :length

  def initialize(hub_id, other_hub_id, length)
    @hub_id = hub_id
    @other_hub_id = other_hub_id
    @length = length
  end

  def write_to_file(path)
    identifier= "#{@hub_id}.#{@other_hub_id}"
    filename = "#{path}/Cap_#{identifier}.scad"
    file = File.new(filename, 'w')
    defaults = get_defaults_for_openscad PRESETS::CAP_RUBY
    export_string = [
      "// adjust filepath to LibSTLExport if neccessary",
      "use <#{ProjectHelper.library_directory}/openscad/Hinge/cap.scad>",
      "draw_hinge_cap(",
      "cap_height=#{@length},",
      "label=\"#{identifier}\",",
      "#{defaults});"].join("\n") + "\n"

    file.write(export_string)
    file.close
    export_string
  end
end
