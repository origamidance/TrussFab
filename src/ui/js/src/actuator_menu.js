function showManualActuatorSettings(pistons, breakingForce, maxSpeed) {
  $('#manual').empty();
  pistons.forEach(pistonId => {
    const pistonElement = $(
      `<input type="range" min="0" max="1" value="0.5" step="0.01">`
    );
    pistonElement.on('input', event =>
      changePistonValue(pistonId, event.currentTarget.value)
    );
    $('#manual').append(pistonElement);

    const pistonTestButton = $(`<button>Test</button>`);

    pistonTestButton.click(() => testPiston(pistonId));

    $('#manual').append(pistonTestButton);
  });

  const breakingForceElement = $(
    `<input type="number" min = "0" value="${breakingForce}" step="1"> N`
  );
  breakingForceElement.on('change', event =>
    setBreakingForce(event.currentTarget.value)
  );

  $('#manual').append(breakingForceElement);

  const maxSpeedElement = $(
    `<input type="number" min = "0" value="${maxSpeed}" step="1"> m/s`
  );
  maxSpeedElement.on('change', event => setMaxSpeed(event.currentTarget.value));

  $('#manual').append(maxSpeedElement);

  const highestForceModeElement = $(
    `<input id="force_mode_checkbox" type="checkbox"">`
  );

  highestForceModeElement.on('change', event =>
    changeHighestForceMode(event.currentTarget.checked)
  );

  $('#manual').append(highestForceModeElement);
}

function toggleSimulation() {
  sketchup.toggle_simulation();
}

function togglePauseSimulation() {
  sketchup.toggle_pause_simulation();
}

function restartSimulation() {
  sketchup.restart_simulation();
}

function changePistonValue(id, newValue) {
  sketchup.change_piston_value(id, newValue);
}

function testPiston(id) {
  sketchup.test_piston(id);
}

function setBreakingForce(value) {
  sketchup.set_breaking_force(value);
}

function setMaxSpeed(value) {
  sketchup.set_max_speed(value);
}

function changeHighestForceMode(checked) {
  sketchup.change_highest_force_mode(checked);
}

// function reset_sliders() {
//   <% for piston_id in @pistons.keys %>
//       document.getElementById("<%= piston_id %>").value = "0.5";
//   <% end %>
// }

function apply_force() {
  sketchup.apply_force();
}

function release_force() {
  sketchup.release_force();
}

$(() => {
  $('.start-button').click(toggleSimulation);
  $('.pause-button').click(togglePauseSimulation);
  $('.restart-button').click(restartSimulation);
  // startSimulation();
});
