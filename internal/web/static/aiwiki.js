// AI wiki chat widget for cronova console.
// Provides a floating button + chat window that talks to POST /api/ask.
(function () {
  const root = document.getElementById('aiwiki-root');
  if (!root) return;

  let open = false;
  let busy = false;

  const fab = document.createElement('button');
  fab.className = 'aiwiki-fab';
  fab.title = 'AI wiki / Pomoc';
  fab.innerHTML = '✦';
  fab.setAttribute('aria-label', 'Otwórz chat AI wiki');

  const win = document.createElement('div');
  win.className = 'aiwiki-window aiwiki-hidden';
  win.innerHTML = `
    <div class="aiwiki-head">
      <b>AI wiki — cronova</b>
      <button id="aiwiki-close" title="Zamknij">✕</button>
    </div>
    <div class="aiwiki-msgs" id="aiwiki-msgs"></div>
    <div class="aiwiki-input">
      <input id="aiwiki-q" type="text" placeholder="Zapytaj np. jak zrobić DAG…" autocomplete="off" />
      <button id="aiwiki-send" class="primary">Wyślij</button>
    </div>
  `;

  root.appendChild(fab);
  root.appendChild(win);

  const msgs = win.querySelector('#aiwiki-msgs');
  const input = win.querySelector('#aiwiki-q');
  const sendBtn = win.querySelector('#aiwiki-send');
  const closeBtn = win.querySelector('#aiwiki-close');

  function toggle(show) {
    open = show !== undefined ? show : !open;
    win.classList.toggle('aiwiki-hidden', !open);
    fab.setAttribute('aria-label', open ? 'Zamknij chat AI wiki' : 'Otwórz chat AI wiki');
    if (open) setTimeout(() => input.focus(), 50);
  }

  fab.addEventListener('click', () => toggle());
  closeBtn.addEventListener('click', () => toggle(false));

  function addMsg(text, who, extras) {
    const div = document.createElement('div');
    div.className = 'aiwiki-msg ' + who;
    div.textContent = text;
    if (extras) div.appendChild(extras);
    msgs.appendChild(div);
    msgs.scrollTop = msgs.scrollHeight;
  }

  function renderSources(sources) {
    if (!sources || !sources.length) return null;
    const wrap = document.createElement('div');
    wrap.className = 'src';
    wrap.textContent = 'Źródła: ' + sources.map(s => s.path + (s.section ? ' / ' + s.section : '')).join('; ');
    return wrap;
  }

  function renderActions(actions) {
    if (!actions || !actions.length) return null;
    const wrap = document.createElement('div');
    wrap.className = 'actions';
    actions.forEach(a => {
      const btn = document.createElement('button');
      btn.textContent = a.label || a.type;
      btn.addEventListener('click', () => runAction(a));
      wrap.appendChild(btn);
    });
    return wrap;
  }

  function runAction(a) {
    switch (a.type) {
      case 'trigger_dag':
        if (!a.dag_id) return;
        fetch('/api/dags/' + encodeURIComponent(a.dag_id) + '/trigger', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({})
        })
          .then(r => {
            if (!r.ok) throw new Error('HTTP ' + r.status);
            window.toast && window.toast('Wyzwolono DAG ' + a.dag_id);
            window.location.hash = '#/dags/' + encodeURIComponent(a.dag_id);
          })
          .catch(e => window.toast && window.toast('Błąd: ' + e.message, 'error'));
        break;
      case 'open_editor':
        if (a.path && a.path.startsWith('dags/')) {
          const dagId = a.path.replace('dags/', '').replace('.yaml', '');
          window.location.hash = '#/dags/' + encodeURIComponent(dagId);
        } else {
          window.open(a.path, '_blank');
        }
        break;
      case 'copy_command':
        navigator.clipboard.writeText(a.command || '').catch(() => {});
        break;
      default:
        break;
    }
  }

  async function ask() {
    const q = input.value.trim();
    if (!q || busy) return;
    busy = true;
    sendBtn.disabled = true;
    addMsg(q, 'user');
    input.value = '';

    try {
      const resp = await fetch('/api/ask', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ question: q }),
      });
      if (!resp.ok) throw new Error('HTTP ' + resp.status);
      const data = await resp.json();
      const extras = document.createElement('div');
      const src = renderSources(data.sources);
      const acts = renderActions(data.actions);
      if (src) extras.appendChild(src);
      if (acts) extras.appendChild(acts);
      addMsg(data.answer || 'Brak odpowiedzi.', 'bot', extras);
    } catch (e) {
      addMsg('Błąd połączenia z AI wiki: ' + e.message, 'bot');
    } finally {
      busy = false;
      sendBtn.disabled = false;
      input.focus();
    }
  }

  sendBtn.addEventListener('click', ask);
  input.addEventListener('keydown', e => { if (e.key === 'Enter') ask(); });

  // Welcome message.
  setTimeout(() => {
    if (!msgs.childElementCount) {
      addMsg('Witaj! Jestem AI wiki cronova. Zapytaj mnie np. "Jak zrobić DAG?" lub "Co to jest retry?"', 'bot');
    }
  }, 500);
})();
