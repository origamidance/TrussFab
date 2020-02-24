require 'csv'
require_relative './animation_data_sample.rb'
require 'open3'
require 'singleton'
require 'benchmark'

require 'fileutils'
require 'tmpdir'

class SimulationRunner
  include Singleton

  def initialize(suppress_compilation=false, keep_temp_dir=false)
    @model_name = "seesaw3"

    if suppress_compilation
      @directory = File.dirname(__FILE__)
    else
      @directory = Dir.mktmpdir
      puts @directory
      if not keep_temp_dir
        ObjectSpace.define_finalizer(self, proc { FileUtils.remove_entry @directory })
      end

      run_compilation
    end
  end

  def get_hub_time_series(hubIDs, stepSize, mass, constant=50)
    data = []
    simulation_time = Benchmark.realtime { run_simulation(constant, mass, "node_pos.*") }
    import_time = Benchmark.realtime { data = parse_data(read_csv) }
    puts("simulation time: #{simulation_time.to_s}s csv parsing time: #{import_time.to_s}s")
    data
  end


  def get_period(mass=20, constant=5000)
    # TODO confirm correct result
    run_simulation(constant, mass, "revLeft.phi")

    require 'gsl'
    require 'csv'

    stop_time = 10

    # TODO make this call use read_csv
    data = CSV.read((File.join(@directory, "#{@model_name}_res.csv")), :headers=>true)['revLeft.phi']
    vector = data.map{ |v| v.to_f }.to_gv

    sample_rate = vector.length / stop_time

    # https://github.com/SciRuby/rb-gsl/blob/master/examples/fft/fft.rb
    y2 = vector.fft.subvector(1, data.length - 2).to_complex2
    mag = y2.abs
    f = GSL::Vector.linspace(0, sample_rate/2, mag.size)
    #p mag.to_a
    #p mag.max_index
    #p f.to_a
    return 1 / f[mag.max_index]
  end

  # Returns index of animation frame when system is in equilibrium i.e. the mean of the angle difference
  def find_equilibrium(constant=50, mass=20)
    run_simulation(constant, mass, "revLeft.phi")
    raw_data = read_csv

    # remove initial data point, the header
    raw_data.shift
    angles = raw_data.map { |data_sample| data_sample[1].to_f }

    # center of oscillation
    equilibrium_angle = angles.min + (angles.max - angles.min) / 2
    equilibrium_data_row = raw_data.min_by do | data_row |
      # find data row with angle that is the closest to the equilibrium
      # (can't check for equality since we only have samples in time)
      (equilibrium_angle - data_row[1].to_f).abs
    end

    raw_data.index(equilibrium_data_row)
  end

  def constant_for_constrained_angle(allowed_angle_delta = Math::PI / 2.0, initial_constant = 500, mass = 20,
                                     spring_id = 0, angle_id = 0)
    # steps which the algorithm uses to approximate the valid spring constant
    step_sizes = [1500, 1000, 200, 50, 5]
    constant = initial_constant
    step_size = step_sizes.shift
    keep_searching = true
    abort_threshold = 50000
    while keep_searching
      # puts "Current k: #{constant} Step size: #{step_size}"
      run_simulation(constant, mass, "revLeft.phi")
      if !angle_valid(read_csv, allowed_angle_delta)
        # increase spring constant to decrease angle delta
        constant += step_size
      else if step_sizes.length > 0
             # go back last step_size
             constant -= step_size
             # reduce step size and continue
             step_size = step_sizes.shift
           else
             # we reached smallest step size and found a valid spring constant, so we're done
             keep_searching = false
           end
      end

      if constant >= abort_threshold
        keep_searching = false
      end
    end

    constant
  end




  private

  def angle_valid(data, max_allowed_delta = Math::PI / 2.0)
    data = data.map { |data_sample| data_sample[1].to_f }
    # remove initial data point
    data.shift

    delta = data.max - data.min
    puts "delta: #{delta} maxdelta: #{max_allowed_delta} max: #{data.max}, min: #{data.min}, "
    delta < max_allowed_delta
  end

  def run_compilation()
    output, signal = Open3.capture2e("cp #{@model_name}.mo  #{@directory}", :chdir => File.dirname(__FILE__))
    p output
    output, signal = Open3.capture2e("omc -s #{@model_name}.mo && mv #{@model_name}.makefile Makefile && make -j 8", :chdir => @directory)
    p output
  end

  def run_simulation(constant, mass, filter="*")
    # TODO adjust sampling rate dynamically
    overrides = "outputFormat='csv',variableFilter='#{filter}',startTime=0.3,stopTime=10,stepSize=0.1,springDamperParallel1.c='#{constant}'"
    command = "./#{@model_name} -override #{overrides}"
    puts(command)
    Open3.popen2e(command, :chdir => @directory) do |i, o, t|
      o.each {|l| puts l }
      status = t.value
    end
  end

  def read_csv()
    CSV.read(File.join(@directory, "#{@model_name}_res.csv"))
  end

  def parse_data(raw_data)
    # parse in which columns the coordinates for each node are stored
    indices_map = AnimationDataSample.indices_map_from_header(raw_data[0])

    #remove header of loaded data
    raw_data.shift()

    # parse csv
    data_samples = []
    raw_data.each do | value |
      data_samples << AnimationDataSample.from_raw_data(value, indices_map)
    end

    # todo DEBUG
    #data_samples.each {|sample| puts sample.inspect}

    data_samples

  end

end

