const menu = document.getElementById('menu');
const trackerState = document.getElementById('trackerState');
const panicState = document.getElementById('panicState');

const post = (eventName, body = {}) => {
  fetch(`https://${GetParentResourceName()}/${eventName}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body),
  });
};

const setVisible = (visible) => {
  menu.classList.toggle('hidden', !visible);
};

const setState = (trackerEnabled, panicEnabled) => {
  trackerState.textContent = trackerEnabled ? 'ON' : 'OFF';
  trackerState.style.color = trackerEnabled ? '#58e07e' : '#ff7676';

  panicState.textContent = panicEnabled ? 'ON' : 'OFF';
  panicState.style.color = panicEnabled ? '#58e07e' : '#ff7676';
};

window.addEventListener('message', (event) => {
  const data = event.data;
  if (!data || !data.type) {
    return;
  }

  if (data.type === 'gps_tracker:menu') {
    setVisible(data.visible === true);
  }

  if (data.type === 'gps_tracker:state') {
    setState(data.trackerEnabled === true, data.panicEnabled === true);
  }
});

document.getElementById('toggleTracker').addEventListener('click', () => {
  post('gps_tracker:toggleTracker');
});

document.getElementById('togglePanic').addEventListener('click', () => {
  post('gps_tracker:togglePanic');
});

document.getElementById('closeMenu').addEventListener('click', () => {
  post('gps_tracker:close');
});

document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') {
    post('gps_tracker:close');
  }
});
