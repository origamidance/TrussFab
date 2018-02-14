require 'src/export/presets.rb'


class ExportHub
  def initialize(id, l1)
    @id = id
    @l1 = l1
    @elongations = []
  end

  def add_elongation(elongation)
    @elongations.push(elongation)
  end
end

class ExportSubHub < ExportHub
  def initialize(id, l1)
    super(id, l1)
  end

  def write_to_file(path)
    vector_array = []
    gap_type_array = []
    connector_type_array = []
    l3_array = []

    @elongations.each do |elongation|
      gap_type_string = "none"
      connector_type_string = "none"

      if elongation.hinge_connection == A_HINGE
        gap_type_string = "a"
        connector_type_string = "bottle"
      elsif elongation.hinge_connection == B_HINGE
        gap_type_string = "b"
      elsif elongation.hinge_connection == A_B_HINGE
        raise RuntimeError, 'Subhub can not be connected to both a and b hinge at same edge.'
      end

      vector_array << "[#{elongation.direction.to_a.join(', ')}]"
      gap_type_array << "\"#{gap_type_string}\""
      connector_type_array << "\"#{connector_type_string}\""
      l3_array << elongation.l3.to_s
    end

    params = "normal_vectors = [\n" + vector_array.join(",\n") + "],\n" +
             "gap_types = [\n" + gap_type_array.join(",\n") + "],\n" +
             "connector_types = [\n" + connector_type_array.join(",\n") + "],\n" +
             "l1 = #{@l1},\n" +
             "l3 = [\n" + l3_array.join(",\n") + "],\n"

    # TODO: rename get_defaults_for_openscad
    default_params = get_defaults_for_openscad(PRESETS::SUBHUB_OPENSCAD)
    filename = "#{path}/SubHub_#{@id}.scad"
    file = File.new(filename, 'w')

    export_string = ["// adjust filepath to LibSTLExport if necessary",
      "use <#{ProjectHelper.library_directory}/openscad/Hinge/subhub.scad>",
      "draw_subhub(",
    ].join("\n") + "\n" + params + default_params + ");\n"

    file.write(export_string)
    file.close
    export_string
  end
end

class ExportMainHub < ExportHub
  def initialize(id, l1)
    super(id, l1)
    @pods = []
  end

  def add_pod(pod)
    @pods.push(pod)
  end

  def write_to_file(path)
    filename = "#{path}/Hub_#{@id}.scad"
    file = File.new(filename, 'w')

    mode = 'Tube'

    vector_array = []
    addon_array = []
    type_array = []

    @elongations.each do |elongation|
      if elongation.hinge_connection == NO_HINGE
        length = elongation.total_length
        type_array << '"PLUG"'
      else
        length = elongation.l1
        type_array << '"HOLE"'
      end

      vector_array << "[#{elongation.direction.to_a.join(', ')}]"
      addon_array << "[#{length}, \"#{elongation.other_hub_id}\"]"
    end

    @pods.each do |pod|
      addon_array << '[(45 - 0 - 10), "STAND",0,24,10,60,0]'
      type_array << '"STAND"'
      vector_array << "[" + pod.direction.normalize.to_a.join(', ').to_s + "]"
    end

    export_string =
        "// adjust filepath to LibSTLExport if neccessary\n" \
        "include <#{ProjectHelper.library_directory}/openscad/LibSTLExport.scad>\n" \
        "\n" \
        "hubID = \"#{@id}\";\n" \
        "mode = \"#{mode}\";\n" \
        "safetyFlag = false;\n" \
        "connectorDataDistance = 0;\n" \
        "tubeThinning = 1.0;\n" \
        "useFixedCenterSize = false;\n" \
        "hubCenterSize = 0;\n" \
        "printVectorInteger = 8;\n" \
        "dataFileVectorArray = [\n" \
        "#{vector_array.join(",\n")}\n" \
        "];\n" \
        "dataFileAddonParameterArray = [\n" \
        "#{addon_array.join(",\n")}\n" \
        "];\n" \
        "connectorTypeArray = [\n" \
        "#{type_array.join(",\n")}\n" \
        "];\n" \
        "drawHub(dataFileVectorArray, dataFileAddonParameterArray, connectorTypeArray);\n"

    file.write(export_string)
    file.close
    export_string
  end
end
