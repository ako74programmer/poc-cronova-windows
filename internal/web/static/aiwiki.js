// AI wiki chat widget for cronova console.
// Provides a floating button + chat window that talks to POST /api/ask.
(function () {
  const root = document.getElementById('aiwiki-root');
  if (!root) return;

  let open = false;
  let busy = false;

  const fab = document.createElement('button');
  fab.className = 'aiwiki-fab';
  fab.title = 'AI wiki / ' + t('aiwiki_title');
  fab.innerHTML = '✦';
  fab.setAttribute('aria-label', t('aiwiki_title'));

  const win = document.createElement('div');
  win.className = 'aiwiki-window aiwiki-hidden';
  win.innerHTML = `
    <div class="aiwiki-head">
      <b>${t('aiwiki_title')}</b>
      <button id="aiwiki-close" title="${t('aiwiki_close')}">✕</button>
    </div>
    <div class="aiwiki-msgs" id="aiwiki-msgs"></div>
    <div class="aiwiki-input">
      <input id="aiwiki-q" type="text" placeholder="${t('aiwiki_placeholder')}" autocomplete="off" />
      <button id="aiwiki-send" class="primary">${t('aiwiki_send')}</button>
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
    fab.setAttribute('aria-label', open ? t('aiwiki_close') : t('aiwiki_title'));
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
    wrap.textContent = t('aiwiki_sources') + sources.map(s => s.path + (s.section ? ' / ' + s.section : '')).join('; ');
    return wrap;
  }

  function actionLabel(a) {
    if (a.label) return a.label;
    switch (a.type) {
      case 'trigger_dag': return t('aiwiki_run_dag');
      case 'open_dag_runs': return t('aiwiki_dag_runs');
      case 'show_logs': return t('aiwiki_show_logs');
      case 'copy_command': return t('aiwiki_copy_cmd');
      case 'open_docs': return t('aiwiki_open_docs');
      case 'open_editor': return t('aiwiki_see_dag');
      default: return a.type;
    }
  }

  function renderActions(actions) {
    if (!actions || !actions.length) return null;
    const wrap = document.createElement('div');
    wrap.className = 'actions';
    actions.forEach(a => {
      const btn = document.createElement('button');
      btn.dataset.actionType = a.type;
      btn.textContent = actionLabel(a);
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
            window.toast && window.toast(t('aiwiki_triggered') + a.dag_id);
            window.location.hash = '#/dags/' + encodeURIComponent(a.dag_id);
          })
          .catch(e => window.toast && window.toast('Error: ' + e.message, 'error'));
        break;
      case 'open_dag_runs':
        if (a.dag_id) window.location.hash = '#/dags/' + encodeURIComponent(a.dag_id);
        break;
      case 'show_logs':
        if (a.dag_id) {
          fetch('/api/dags/' + encodeURIComponent(a.dag_id) + '/runs')
            .then(r => r.json())
            .then(runs => {
              const run = (runs || []).find(x => x.run_id) || (runs && runs.value && runs.value.find(x => x.run_id));
              if (run && run.run_id) {
                window.location.hash = '#/runs/' + encodeURIComponent(run.run_id);
              } else {
                window.toast && window.toast(t('aiwiki_no_runs') + a.dag_id);
              }
            })
            .catch(e => window.toast && window.toast('Error: ' + e.message, 'error'));
        }
        break;
      case 'open_editor':
      case 'open_docs':
        if (a.path && a.path.startsWith('dags/')) {
          const dagId = a.path.replace('dags/', '').replace('.yaml', '');
          window.location.hash = '#/dags/' + encodeURIComponent(dagId);
        } else if (a.path && a.path.startsWith('/doc/')) {
          const sep = a.path.includes('?') ? '&' : '?';
          const l = (typeof lang !== 'undefined' ? lang : 'en');
          window.open(a.path + sep + 'lang=' + encodeURIComponent(l), '_blank');
        } else if (a.path) {
          window.open(a.path, '_blank');
        }
        break;
      case 'copy_command':
        navigator.clipboard.writeText(a.command || '').then(() => {
          window.toast && window.toast(t('aiwiki_copied'));
        }).catch(() => {});
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
        body: JSON.stringify({ question: q, lang: (typeof lang !== 'undefined' ? lang : 'en') }),
      });
      if (!resp.ok) throw new Error('HTTP ' + resp.status);
      const data = await resp.json();
      const extras = document.createElement('div');
      const src = renderSources(data.sources);
      const acts = renderActions(data.actions);
      if (src) extras.appendChild(src);
      if (acts) extras.appendChild(acts);
      addMsg(data.answer || t('aiwiki_fallback'), 'bot', extras);
    } catch (e) {
      addMsg(t('aiwiki_error') + e.message, 'bot');
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
      addMsg(t('aiwiki_welcome'), 'bot');
    }
  }, 500);

  // Re-render labels when language changes.
  document.addEventListener('cronova:langchanged', () => {
    fab.title = 'AI wiki / ' + t('aiwiki_title');
    fab.setAttribute('aria-label', open ? t('aiwiki_close') : t('aiwiki_title'));
    win.querySelector('.aiwiki-head b').textContent = t('aiwiki_title');
    win.querySelector('#aiwiki-close').title = t('aiwiki_close');
    input.placeholder = t('aiwiki_placeholder');
    sendBtn.textContent = t('aiwiki_send');
    // Re-render action buttons in existing messages.
    document.querySelectorAll('.aiwiki-msg.bot .actions button').forEach(btn => {
      const type = btn.dataset.actionType;
      if (!type) return;
      const label = (() => {
        switch (type) {
          case 'trigger_dag': return t('aiwiki_run_dag');
          case 'open_dag_runs': return t('aiwiki_dag_runs');
          case 'show_logs': return t('aiwiki_show_logs');
          case 'copy_command': return t('aiwiki_copy_cmd');
          case 'open_docs': return t('aiwiki_open_docs');
          case 'open_editor': return t('aiwiki_see_dag');
          default: return type;
        }
      })();
      btn.textContent = label;
    });
  });
})();
