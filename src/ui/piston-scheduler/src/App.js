import React, { Component } from 'react';
import * as d3 from 'd3';

import logo from './logo.svg';
import './App.css';
import { toggleDiv } from './util';
import { getInterpolationForTime } from './serious-math';
import {
  toggleSimulation,
  moveJoint,
  restartSimulation,
  togglePauseSimulation,
  setBreakingForce,
  getBreakingForce,
  setMaxSpeed,
  changeHighestForceMode,
  setStiffness,
  getStiffness,
  changePeakForceMode,
  changeDisplayValues,
  changePistonValue,
} from './sketchup-integration';

const xAxis = 300;
const yAxis = 50;
const timelineStepSeconds = 10;

class App extends Component {
  constructor(props) {
    super(props);
    this.state = {
      pistons: [],
      keyframes: new Map(),
      seconds: 5,
      timeSelection: new Map(),
      simulationPaused: true,
      timlineInterval: null,
      timelineCurrentTime: 0,
      startedSimulationCycle: false,
      startedSimulationOnce: false,
      simulationIsPausedAfterOnce: false,
      currentCycle: 0,
      highestForceMode: false,
      peakForceMode: false,
      displayVol: false,
      breakingForce: 1000,
      stiffness: 90,
    };
  }

  initState(breakingForce, stiffness) {
  	this.setState({breakingForce, stiffness});
  }

  componentDidMount() {
    window.addPiston = this.addPiston;
    window.cleanupUiAfterStoppingSimulation = this.cleanupUiAfterStoppingSimulation;

    document.addEventListener('keyup', e => {
      console.log(e);
      // ESC
      if (e.keyCode === 27) {
        this.stopSimulation();
      }
    });
  }

  componentWillUnmount() {
    document.removeEventListener('keyup', this.stopSimulation);
  }

  addPiston = id => {
    console.log('new piston added', id);

    // const id = this.state.pistons.length;
    const oldKeyframes = this.state.keyframes;
    this.setState({
      pistons: this.state.pistons.concat(id),
      keyframes: oldKeyframes.set(id, [
        { time: 0, value: 0.5 },
        { time: this.state.seconds, value: 0.5 },
      ]), // init
    });
    setTimeout(() => {
      this.addTimeSelectionForNewKeyFrame(id);
    }, 100);
  };

  cleanupUiAfterStoppingSimulation = () => {
    this.resetState();
  };

  addKeyframe = event => {
    const pistonId = parseInt(event.currentTarget.id);
    const value = event.currentTarget.previousSibling.value / 100;
    const time = parseFloat(
      event.currentTarget.previousSibling.previousSibling.value
    );

    const oldKeyframes = this.state.keyframes;
    const oldKeyframesPiston = oldKeyframes.get(pistonId) || [];
    const keyframes = oldKeyframes.set(
      pistonId,
      oldKeyframesPiston.concat({ time, value }).sort((a, b) => a.time - b.time)
    );
    this.setState({ keyframes });
  };

  renderGraph = id => {
    const keyframes = this.state.keyframes.get(id) || [];

    const points = keyframes.map(kf => {
      return [kf.time * xAxis / this.state.seconds, (1 - kf.value) * yAxis];
    });

    const viewBox = `0 0 ${xAxis} ${yAxis}`;
    const pointsString = points.map(p => p.join(',')).join('\n');

    const oldKeyframesMap = this.state.keyframes;

    const deleteCircle = keyframeIndex => {
      this.setState({
        keyframes: oldKeyframesMap.set(
          id,
          oldKeyframesMap.get(id).filter((_, index) => index !== keyframeIndex)
        ),
      });
    };

    const circles = points.map((x, index) => (
      <circle
        onClick={() => deleteCircle(index)}
        cx={x[0]}
        cy={x[1]}
        r="4"
        fill="#0074d9"
      />
    ));

    return (
      <div style={{ position: 'relative' }}>
        <svg viewBox={viewBox} className="chart" id={`svg-${id}`}>
          <polyline
            fill="none"
            stroke="#0074d9"
            strokeWidth="3"
            points={pointsString}
          />
          {circles}
        </svg>
        <span
          style={{ position: 'absolute', bottom: 0, left: 0, fontSize: 10 }}
        >
          0s
        </span>
        <span
          style={{
            position: 'absolute',
            bottom: 0,
            right: xAxis / 2,
            fontSize: 10,
          }}
        >
          {this.state.seconds / 2}s
        </span>
        <span
          style={{ position: 'absolute', bottom: 0, right: 0, fontSize: 10 }}
        >
          {this.state.seconds}s
        </span>
      </div>
    );
  };

  addTimeSelectionForNewKeyFrame = id => {
    console.log(id);
    const self = this;

    function scrubLine() {
      let newX = d3.event.x;
      newX = Math.min(Math.max(0, newX), xAxis);

      const oldTimeSelection = self.state.timeSelection;

      self.setState({
        timeSelection: oldTimeSelection.set(
          id,
          (newX / xAxis * self.state.seconds).toFixed(1)
        ),
      });

      d3
        .select(this)
        .attr('x1', newX)
        .attr('x2', newX);
    }

    const scrub = d3.drag().on('drag', scrubLine);

    d3
      .select('#svg-' + id)
      .append('line')
      .classed('timeSelection', true)
      .attr('x1', xAxis / 2)
      .attr('y1', 0)
      .attr('x2', xAxis / 2)
      .attr('y2', yAxis)
      .style('stroke-width', 3)
      .style('stroke', 'red')
      .style('fill', 'none')
      .call(scrub);
  };

  playOneTimelineStep = () => {
    let { timelineCurrentTime } = this.state;

    if (timelineCurrentTime / 1000 > this.state.seconds) {
      if (this.state.startedSimulationOnce) {
        this._removeInterval();
        this._removeLines();
        // toggleSimulation();
        togglePauseSimulation();

        this.setState({
          startedSimulationOnce: false,
          startedSimulationCycle: false,
          simulationPaused: true,
          timelineCurrentTime: 0,
          currentCycle: 0,
          simulationIsPausedAfterOnce: true,
        });
      } else {
        timelineCurrentTime = 0;
        this.setState({ currentCycle: this.state.currentCycle + 1 });
      }
    }

    const timelineCurrentTimeSeconds = timelineCurrentTime / 1000;

    this.state.keyframes.forEach((value, key) => {
      const keyframes = value;

      for (let i = 0; i < keyframes.length; i++) {
        const x = keyframes[i];
        if (timelineCurrentTime === x.time * 1000) {
          let duration;
          let newValue;
          // check if last one
          if (i === keyframes.length - 1) {
            // newValue = keyframes[0].value;
            // duration = this.state.seconds - x.time; // value until end
          } else {
            newValue = keyframes[i + 1].value;
            duration = keyframes[i + 1].time - x.time; // next

            // some hack because the inital value of the piston is 0
            // so we have to fix it here
            // if (
            //   i === 0 &&
            //   this.state.currentCycle === 0 &&
            //   keyframes[0].value !== keyframes[1].value
            // ) {
            //   console.log('fixing');
            //   if (keyframes[0].value > keyframes[1].value)
            //     newValue -= keyframes[0].value;
            //   else newValue += keyframes[0].value;
            // }
            moveJoint(key, newValue, duration);
          }
        }
      }
    });

    const newX = timelineCurrentTimeSeconds * xAxis / this.state.seconds;

    d3
      .selectAll('line.timeline')
      .attr('x1', newX)
      .attr('x2', newX);

    this.setState({
      timelineCurrentTime: timelineCurrentTime + timelineStepSeconds,
    });
  };

  _startSimulation = playOnce => {
    this._removeLines();
    this._addLines();

    this._removeInterval();
    this._addInterval();

    if (this.state.simulationIsPausedAfterOnce) restartSimulation();
    else toggleSimulation();

    // TODO
    setBreakingForce(this.state.breakingForce);

    if (playOnce) {
      this.setState({
        startedSimulationOnce: true,
        startedSimulationCycle: false,
        simulationPaused: false,
        timelineCurrentTime: 0,
        currentCycle: 0,
      });
    } else {
      this.setState({
        startedSimulationCycle: true,
        startedSimulationOnce: false,
        simulationPaused: false,
        timelineCurrentTime: 0,
        currentCycle: 0,
      });
    }
  };

  _addInterval = () => {
    const timlineInterval = setInterval(
      this.playOneTimelineStep,
      timelineStepSeconds
    );
    this.setState({ timlineInterval });
  };

  _removeInterval = () => {
    clearInterval(this.state.timlineInterval);
  };

  _addLines = () => {
    d3
      .selectAll('svg')
      .append('line')
      .classed('timeline', true)
      .attr('x1', 0)
      .attr('y1', 0)
      .attr('x2', 0)
      .attr('y2', yAxis)
      .style('stroke-width', 1)
      .style('stroke', '#D3D3D3')
      .style('fill', 'none');
  };

  _removeLines = () => d3.selectAll('line.timeline').remove();

  _togglePause = () => {
    const { simulationPaused } = this.state;
    if (simulationPaused) {
      // togglePauseSimulation();
      this.setState({ simulationPaused: !simulationPaused });

      this._addLines();

      this._addInterval();
    } else {
      // togglePauseSimulation();
      this._removeInterval();
      this.setState({ simulationPaused: !simulationPaused });
    }
  };

  toggelSimulation = playOnce => {
    const { startedSimulationOnce, startedSimulationCycle } = this.state;

    if (playOnce) {
      if (startedSimulationOnce) {
        this._togglePause();
      } else {
        this._startSimulation(playOnce);
      }
    } else {
      if (startedSimulationCycle) {
        this._togglePause();
      } else {
        this._startSimulation(playOnce);
      }
    }
  };

  resetState = () => {
    this._removeLines();
    clearInterval(this.state.timlineInterval);
    this.setState({
      simulationPaused: true,
      timelineCurrentTime: 0,
      currentCycle: 0,
      startedSimulationOnce: false,
      startedSimulationCycle: false,
      simulationIsPausedAfterOnce: false,
    });
  };

  stopSimulation = () => {
    const {
      startedSimulationOnce,
      startedSimulationCycle,
      simulationIsPausedAfterOnce,
    } = this.state;

    if (
      !(startedSimulationOnce || startedSimulationCycle) &&
      !simulationIsPausedAfterOnce
    ) {
      return;
    }

    toggleSimulation();
    this.resetState();
  };

  removeTimeSelectionForNewKeyFrame = id => {
    d3
      .select('#svg-' + id)
      .select('line.timeSelection')
      .remove();
    const oldTimeSelection = this.state.timeSelection;
    this.setState({
      timeSelection: oldTimeSelection.set(id, this.state.seconds / 2),
    });
  };

  newKeyframeToggle = id => {
    toggleDiv(`add-kf-${id}`);
    toggleDiv(`new-kf-${id}`);
  };

  onTimeSelectionInputChange = (id, value) => {
    this.setState({ timeSelection: this.state.timeSelection.set(id, value) });

    const newX = value / this.state.seconds * xAxis;

    const line = d3
      .select('#svg-' + id)
      .select('line')
      .attr('x1', newX)
      .attr('x2', newX);
  };

  renderControlls = () => {
    const { startedSimulationCycle, startedSimulationOnce } = this.state;
    const simulationIsRunning = startedSimulationCycle || startedSimulationOnce;
    return (
      <div
        className="col-4"
        style={{
          borderRight: '1px solid lightgrey',
          height: '100%',
          paddingRight: '3px',
        }}
      >
        <div className="row no-gutters control-buttons">
          <div className="col">
            <button onClick={() => this.toggelSimulation(true)}>
              <img
                src={
                  this.state.startedSimulationOnce &&
                  !this.state.simulationPaused
                    ? '../../assets/icons/pause.png'
                    : '../../assets/icons/play.png'
                }
              />
            </button>
          </div>
          <div className="col">
            <button onClick={() => this.toggelSimulation(false)}>
              <img
                src={
                  this.state.startedSimulationCycle &&
                  !this.state.simulationPaused
                    ? '../../assets/icons/pause.png'
                    : '../../assets/icons/cycle.png'
                }
              />
            </button>
          </div>
          <div className="col">
            <button onClick={this.stopSimulation}>
              <img src="../../assets/icons/stop.png" />
            </button>
          </div>
        </div>
        <form>
          <div className="form-check">
            <input
              className="form-check-input"
              type="checkbox"
              value=""
              id="defaultCheck1"
              value={this.state.highestForceMode}
              onChange={event => {
                this.setState({ highestForceMode: event.target.value });
                changeHighestForceMode(event.target.value);
              }}
            />
            <label className="form-check-label" for="defaultCheck1">
              Highest Force
            </label>
          </div>
          <div className="form-check">
            <input
              className="form-check-input"
              type="checkbox"
              value=""
              id="defaultCheck1"
              value={this.state.peakForceMode}
              onChange={event => {
                this.setState({ peakForceMode: event.target.value });
                changePeakForceMode(event.target.value);
              }}
            />
            <label className="form-check-label" for="defaultCheck1">
              Peak Force
            </label>
          </div>
          <div className="form-check">
            <input
              className="form-check-input"
              type="checkbox"
              value=""
              id="defaultCheck1"
              value={this.state.displayVol}
              onChange={event => {
                this.setState({ displayVol: event.target.value });
                changeDisplayValues(event.target.value);
              }}
            />
            <label className="form-check-label" for="defaultCheck1">
              Display Values
            </label>
          </div>
          <div className="form-group row no-gutters">
            <label for="inputEmail3" className="col-sm-6 col-form-label">
              Cycle Length
            </label>
            <div className="input-group input-group-sm col-sm-6">
              <input
                type="number"
                className="form-control form-control-sm"
                id="inputEmail3"
                placeholder="6"
                value={this.state.seconds}
                onChange={event => {
                  const newSeconds = event.target.value;
                  // fix old values
                  const newKeyframes = new Map();
                  const oldKeyframes = this.state.keyframes;

                  oldKeyframes.forEach((value, key) => {
                    const updatedValues = value.map(oneKeyframe => {
                      if (oneKeyframe.time === this.state.seconds) {
                        return { value: oneKeyframe.value, time: newSeconds };
                      } else return oneKeyframe;
                    });
                    newKeyframes.set(key, updatedValues);
                  });

                  this.setState({
                    seconds: newSeconds,
                    keyframes: newKeyframes,
                  });
                }}
              />
              <div class="input-group-append">
                <span class="input-group-text" id="basic-addon2">
                  s
                </span>
              </div>
            </div>
          </div>
          <div className="form-group row no-gutters">
            <label for="inputEmail3" className="col-sm-6 col-form-label">
              Breaking Force
            </label>
            <div className="input-group input-group-sm col-sm-6">
              <input
                type="number"
                className="form-control form-control-sm"
                id="inputEmail3"
                placeholder="300"
                value={this.state.breakingForce}
                onChange={event => {
                  this.setState({ breakingForce: event.target.value });
                  if (simulationIsRunning) {
                    setBreakingForce(event.target.value);
                  }
                }}
              />
              <div class="input-group-append">
                <span class="input-group-text" id="basic-addon2">
                  N
                </span>
              </div>
            </div>
          </div>
          <div className="form-group row no-gutters">
            <label for="inputEmail3" className="col-sm-6 col-form-label">
              Stiffness
            </label>
            <div className="input-group input-group-sm col-sm-6">
              <input
                type="number"
                className="form-control form-control-sm"
                id="inputEmail3"
                placeholder="Email"
                value={this.state.stiffness}
                onChange={event => {
                  this.setState({ stiffness: event.target.value });
                  setStiffness(event.target.value);
                }}
              />
              <div class="input-group-append">
                <span class="input-group-text" id="basic-addon2">
                  %
                </span>
              </div>
            </div>
          </div>
        </form>
      </div>
    );
  };

  render() {
    const { startedSimulationCycle, startedSimulationOnce } = this.state;
    const simulationIsRunning = startedSimulationCycle || startedSimulationOnce;
    const pistons = this.state.pistons.map(x => (
      <div>
        <div
          style={{
            display: 'flex',
            alignContent: 'flex-start',
            alignItems: 'flex-start',
          }}
        >
          <div
            style={{ 'margin-top': yAxis / 3, marginLeft: 3, marginRight: 3 }}
          >{`#${x}`}</div>
          {this.renderGraph(x)}
          <div id={`add-kf-${x}`}>
            <input
              hidden
              type="number"
              step="0.1"
              min="0"
              max={this.state.seconds}
              value={this.state.timeSelection.get(x) || this.state.seconds / 2}
              onChange={event =>
                this.onTimeSelectionInputChange(x, event.currentTarget.value)
              }
            />
            <input
              type="range"
              onChange={event => {
                if (simulationIsRunning)
                  changePistonValue(x, parseFloat(event.target.value) / 100);
                else {
                  // // this.toggelSimulation();
                  // toggleSimulation();
                  // setTimeout(() => {
                  //   changePistonValue(x, parseFloat(event.target.value));
                  // }, 1000);
                  // // this._togglePause();
                  // setTimeout(() => {
                  //   this.setState({ simulationIsPausedAfterOnce: true });
                  //   // togglePauseSimulation();
                  // }, 1000);
                }
              }}
            />
            <button onClick={this.addKeyframe} className="add-new-kf" id={x}>
              +
            </button>
          </div>
        </div>
      </div>
    ));
    return (
      <div className="row no-gutters">
        {this.renderControlls()}
        <div className="col-8">
          <div className="App">
            {/* {this.state.startedSimulation && (
              <span>{(this.state.timelineCurrentTime / 1000).toFixed(1)}s</span>
            )} */}
            {pistons}
          </div>
        </div>
      </div>
    );
  }
}

export default App;
