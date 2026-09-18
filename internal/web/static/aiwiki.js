// AI wiki chat for cronova console.
// Renders as a full main view reached from the sidebar, plus an in-app doc viewer modal.
(function () {
  let busy = false;
  let msgsEl = null;
  let inputEl = null;
  let sendBtn = null;

  function buildUI() {
    main.innerHTML = `<div class="aiwiki-page">
      <div class="aiwiki-page-head"><h1>${esc(t('aiwiki_title'))}</h1><p>${esc(t('aiwiki_sub'))}</p></div>
      <div class="aiwiki-msgs" id="aiwiki-msgs"></div>
      <div class="aiwiki-input">
        <input id="aiwiki-q" type="text" placeholder="${esc(t('aiwiki_placeholder'))}" autocomplete="off" />
        <button id="aiwiki-send" class="primary">${esc(t('aiwiki_send'))}</button>
      </div>
    </div>`;
    msgsEl = $('aiwiki-msgs');
    inputEl = $('aiwiki-q');
    sendBtn = $('aiwiki-send');
    sendBtn.onclick = ask;
    inputEl.onkeydown = e => { if (e.key === 'Enter') ask(); };
    inputEl.focus();
    if (!msgsEl.childElementCount) addMsg(t('aiwiki_welcome'), 'bot');
  }

  window.showAIWiki = function () {
    view = 'aiwiki';
    setNav('aiwiki');
    buildUI();
  };
  window.renderAIWiki = buildUI;

  function addMsg(text, who, extras) {
    if (!msgsEl) return;
    const div = document.createElement('div');
    div.className = 'aiwiki-msg ' + who;
    div.textContent = text;
    if (extras) div.appendChild(extras);
    msgsEl.appendChild(div);
    msgsEl.scrollTop = msgsEl.scrollHeight;
  }

  function renderSources(sources) {
    if (!sources || !sources.length) return null;
    const wrap = document.createElement('div');
    wrap.className = 'src';
    const label = document.createElement('span');
    label.textContent = t('aiwiki_sources');
    wrap.appendChild(label);
    sources.forEach(s => {
      const a = document.createElement('a');
      a.className = 'src-link';
      a.href = '#';
      a.textContent = s.path + (s.section ? ' / ' + s.section : '');
      a.addEventListener('click', (e) => {
        e.preventDefault();
        openSource(s);
      });
      wrap.appendChild(a);
    });
    return wrap;
  }

  function openSource(s) {
    const src = (s.path || '').toLowerCase();
    if (src.startsWith('dags/')) {
      const dagId = src.replace('dags/', '').replace('.yaml', '');
      window.location.hash = '#/dags/' + encodeURIComponent(dagId);
    } else if (src.startsWith('docs/')) {
      let path = s.path.replace('docs/', '');
      if (typeof lang !== 'undefined' && lang === 'pl') {
        path = path.replace(/\.md$/, '.pl.md');
      }
      openDocViewer('/doc/' + path);
    } else if (src === 'readme.md') {
      openDocViewer('/doc/README.md');
    }
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
      if (a.dag_id) btn.dataset.dagId = a.dag_id;
      if (a.path) btn.dataset.path = a.path;
      if (a.command) btn.dataset.command = a.command;
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
        if (a.path && a.path.startsWith('dags/')) {
          const dagId = a.path.replace('dags/', '').replace('.yaml', '');
          window.location.hash = '#/dags/' + encodeURIComponent(dagId);
        } else if (a.path) {
          window.open(a.path, '_blank');
        }
        break;
      case 'open_docs':
        if (a.path && a.path.startsWith('/doc/')) {
          openDocViewer(a.path);
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
    if (!inputEl || !sendBtn) return;
    const q = inputEl.value.trim();
    if (!q || busy) return;
    busy = true;
    sendBtn.disabled = true;
    addMsg(q, 'user');
    inputEl.value = '';

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
      inputEl.focus();
    }
  }

  // Open a documentation markdown file in an in-app modal viewer.
  function openDocViewer(path) {
    const url = path + (path.includes('?') ? '&' : '?') + 'lang=' + encodeURIComponent(typeof lang !== 'undefined' ? lang : 'en');
    fetch(url)
      .then(r => { if (!r.ok) throw new Error('HTTP ' + r.status); return r.text(); })
      .then(md => {
        const html = (typeof marked !== 'undefined' ? marked.parse(md) : esc(md).replace(/\n/g, '<br>'));
        const title = path.split('/').pop().replace(/\.pl\.md$/, '.md');
        const root = $('modal-root');
        const docLang = typeof lang !== 'undefined' ? lang : 'en';
        root.innerHTML = `<div class="overlay" id="doc-ovl"><div class="modal wide doc-viewer" role="dialog" aria-modal="true" aria-label="${esc(title)}">
          <h2>${esc(title)}
            <span class="doc-tools">
              <button id="doc-speak" class="icon" title="${esc(t('aiwiki_speak'))}">🔊</button>
              <button id="doc-close" class="icon" title="${esc(t('aiwiki_close'))}">✕</button>
            </span>
          </h2>
          <div class="body markdown-body" id="doc-body">${html}</div>
        </div></div>`;
        const close = () => {
          window.speechSynthesis && window.speechSynthesis.cancel();
          document.removeEventListener('keydown', onKey);
          root.innerHTML = '';
        };
        const onKey = (e) => { if (e.key === 'Escape') close(); };
        document.addEventListener('keydown', onKey);
        $('doc-close').onclick = close;
        $('doc-ovl').onclick = (e) => { if (e.target.id === 'doc-ovl') close(); };
        $('doc-speak').onclick = () => speakDoc(docLang);
      })
      .catch(e => window.toast && window.toast('Error: ' + e.message, 'error'));
  }

  // Read the current doc aloud using the browser's Web Speech API.
  function speakDoc(docLang) {
    if (!window.speechSynthesis) {
      window.toast && window.toast(t('aiwiki_speak_unsupported'), 'warn');
      return;
    }
    window.speechSynthesis.cancel();
    const body = $('doc-body');
    if (!body) return;
    const text = body.innerText || body.textContent || '';
    if (!text.trim()) return;
    const u = new SpeechSynthesisUtterance(text);
    u.lang = docLang === 'pl' ? 'pl-PL' : 'en-US';
    u.rate = 1;
    window.speechSynthesis.speak(u);
  }

  // Re-render labels when language changes.
  document.addEventListener('cronova:langchanged', () => {
    if (view === 'aiwiki') buildUI();
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
