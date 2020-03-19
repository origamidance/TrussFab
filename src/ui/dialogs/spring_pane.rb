require 'src/system_simulation/geometry_animation.rb'
require 'src/system_simulation/spring_picker.rb'
require 'src/system_simulation/simulation_runner_client.rb'
require 'src/utility/json_export.rb'

# Ruby integration for spring insights dialog
class SpringPane
  attr_accessor :force_vectors
  INSIGHTS_HTML_FILE = '../spring-pane/index.erb'.freeze

  def initialize
    @refresh_callback = nil
    @toggle_animation_callback = nil

    update_springs

    # Instance of the simulation runner used as an interface to the system simulation.
    @simulation_runner = nil
    # Array of AnimationDataSamples, each containing geometry information for hubs for a certain point in time.
    @simulation_data = nil
    # Sketchup animation object which animates the graph according to simulation data frames.
    @animation = nil
    # A simple visualization for simulation data, plotting circles into the scene.
    @trace_visualization = nil
    @animation_running = false

    # node_id => period
    @user_periods = {}

    @spring_picker = SpringPicker.instance

    @force_vectors = [{ node_id: 4, x: 1000, y: 0, z: 0 }]

    @dialog = nil
    open_dialog

  end

  # spring / graph manipulation logic:

  def update_constant_for_spring(spring_id, new_constant)
    edge = @spring_edges.find { |edge| edge.id == spring_id }
    parameters = get_spring(edge, new_constant)
    p parameters
    edge.link.spring_parameters = parameters
    edge.link.actual_spring_length = parameters[:unstreched_length].m
    # notify simulation runner about changed constants
    SimulationRunnerClient.update_spring_constants(constants_for_springs)

    # update simulation data and visualizations with adjusted results
    simulate
    # TODO: fix and reenable
    #put_geometry_into_equilibrium(spring_id)
    update_trace_visualization
    update_periods

    update_dialog if @dialog
  end

  def force_vectors=(vectors)
    @force_vectors = vectors
    simulate
    update_trace_visualization
    play_animation
  end

  def get_spring(edge, new_constant)
    @spring_picker.get_spring(new_constant, edge.length.to_m)
  end

  def update_springs
    @spring_edges = Graph.instance.edges.values.select { |edge| edge.link_type == 'spring' }
    update_dialog if @dialog
  end

  def update_mounted_users
    SimulationRunnerClient.update_mounted_users(mounted_users)
    update_periods
    update_dialog if @dialog
    update_trace_visualization
  end

  def update_periods
    mounted_users.keys.each do |node_id|
      period = SimulationRunnerClient.get_period(node_id)
      period = period.round(2) if period
      # catch invalid periods
      period ||= 'NaN'
      @user_periods[node_id] = period
      set_period(node_id, period)
    end
  end

  def update_trace_visualization
    @trace_visualization ||= TraceVisualization.new
    @trace_visualization.reset_trace
    # visualize every node with a mounted user
    @trace_visualization.add_trace(mounted_users.keys.map(&:to_s), 4, @simulation_data)
  end

  def put_geometry_into_equilibrium(spring_id)
    equilibrium_index = @simulation_runner.find_equilibrium(spring_id)
    set_graph_to_data_sample(equilibrium_index)
  end

  def set_graph_to_data_sample(index)
    current_data_sample = @simulation_data[index]

    Graph.instance.nodes.each do | node_id, node|
      node.update_position(current_data_sample.position_data[node_id.to_s])
      node.hub.update_position(current_data_sample.position_data[node_id.to_s])
      node.hub.update_user_indicator()
    end

    Graph.instance.edges.each do |_, edge|
      link = edge.link
      link.update_link_transformations
    end
  end

  # dialog logic:

  def set_period(node_id, value)
    @dialog.execute_script("set_period(#{node_id}, #{value})")
  end

  def set_constant(value, spring_id = 25)
    @dialog.execute_script("set_constant(#{spring_id},#{value})")
  end

  # TODO: should probably always be called when a link is changed... e.g also in actuator tool
  def update_dialog
    # load updated html
    file_path = File.join(File.dirname(__FILE__), INSIGHTS_HTML_FILE)
    content = File.read(file_path)
    t = ERB.new(content)

    # display updated html
    @dialog.set_html(t.result(binding))
  end

  def open_dialog
    return if @dialog && @dialog.visible?

    props = {
      resizable: true,
      preferences_key: 'com.trussfab.spring_insights',
      width: 250,
      height: 50 + @spring_edges.length * 200,
      left: 5,
      top: 5,
      # max_height: @height
      style: UI::HtmlDialog::STYLE_DIALOG
    }

    @dialog = UI::HtmlDialog.new(props)
    file_path = File.join(File.dirname(__FILE__), INSIGHTS_HTML_FILE)
    content = File.read(file_path)
    t = ERB.new(content)
    @dialog.set_html(t.result(binding))
    @dialog.set_position(500, 500)
    @dialog.show
    register_callbacks
  end

  # compilation / simulation logic:

  def compile
    # TODO: remove mounted users here in future and only update it (to keep the correct, empty default values in the
    # TODO: modelica file)
    SimulationRunnerClient.update_model(JsonExport.graph_to_json(nil, [], constants_for_springs, mounted_users))
  end

  private

  def constants_for_springs
    spring_constants = {}
    @spring_edges.map(&:link).each do |link|
      spring_constants[link.edge.id] = link.spring_parameters[:k]
    end
    spring_constants
  end

  def mounted_users
    mounted_users = {}
    Graph.instance.nodes.each do |node_id, node|
      hub = node.hub
      next unless hub.is_user_attached

      mounted_users[node_id] = hub.user_force
    end
    mounted_users
  end

  # compilation / simulation logic:

  def simulate
    @simulation_data = SimulationRunnerClient.get_hub_time_series(@force_vectors)
  end

  # animation logic:

  def play_animation
    # recreate animation
    create_animation
  end

  def toggle_animation
    simulate
    if @animation && @animation.running
      @animation.stop
      @animation_running = false
    else
      create_animation
      @animation_running = true
    end
    update_dialog
  end

  def create_animation
    @animation = GeometryAnimation.new(@simulation_data) do
      @animation_running = false
      update_dialog
    end
    Sketchup.active_model.active_view.animation = @animation
  end

  def register_callbacks
    @dialog.add_action_callback('spring_constants_change') do |_, spring_id, value|
      update_constant_for_spring(spring_id, value.to_i)
    end

    @dialog.add_action_callback('spring_insights_compile') do
      compile
    end

    @dialog.add_action_callback('spring_insights_toggle_play') do
      toggle_animation
    end
  end

end
