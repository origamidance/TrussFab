function toggleSimulation() {
  window.sketchup.toggle_simulation();
}

function togglePauseSimulation() {
  window.sketchup.toggle_pause_simulation();
}

function restartSimulation() {
  window.sketchup.restart_simulation();
}

function moveJoint(id, newValue, duration) {
  window.sketchup.move_joint(id, newValue, duration);
}

function setBreakingForce(value) {
  window.sketchup.set_breaking_force(value);
}

function setMaxSpeed(value) {
  window.sketchup.set_max_speed(value);
}

function changeHighestForceMode(checked) {
  window.sketchup.change_highest_force_mode(checked);
}

function changePeakForceMode(checked) {
  window.sketchup.change_peak_force_mode(checked);
}

function changeDisplayValues(checked) {
  console.log('cdv');
  // todo
}

function setStiffness(value) {
  window.sketchup.set_stiffness(value);
}

function changePistonValue(id, value) {
  window.sketchup.change_piston_value(id, value);
}

function togglePane() {
  window.sketchup.animation_pane_toggle();
}

export {
  togglePane,
  toggleSimulation,
  togglePauseSimulation,
  restartSimulation,
  moveJoint,
  setBreakingForce,
  setMaxSpeed,
  setStiffness,
  changeHighestForceMode,
  changeDisplayValues,
  changePeakForceMode,
  changePistonValue,
};