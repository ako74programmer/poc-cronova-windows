// AI wiki chat for cronova console.
// Renders as a full main view reached from the sidebar, plus an in-app doc viewer modal.
(function () {
  let busy = false;
  let msgsEl = null;
  let inputEl = null;
  let sendBtn = null;
  let micBtn = null;
  let recognition = null;
  let voiceListening = false;
  let transcript = [];
  let conversationHistory = [];

  function buildUI() {
    resetVoiceRecognition();
    main.innerHTML = `<div class="aiwiki-page">
      <div class="aiwiki-page-head"><h1>${esc(t('aiwiki_title'))}</h1><p>${esc(t('aiwiki_sub'))}</p></div>
      <div class="aiwiki-msgs" id="aiwiki-msgs"></div>
      <div class="aiwiki-input">
        <input id="aiwiki-q" type="text" placeholder="${esc(t('aiwiki_placeholder'))}" autocomplete="off" />
        <button id="aiwiki-mic" class="icon aiwiki-mic" type="button" aria-label="${esc(t('aiwiki_voice_start'))}" title="${esc(t('aiwiki_voice_start'))}">🎙</button>
        <button id="aiwiki-send" class="primary">${esc(t('aiwiki_send'))}</button>
      </div>
    </div>`;
    msgsEl = $('aiwiki-msgs');
    inputEl = $('aiwiki-q');
    sendBtn = $('aiwiki-send');
    micBtn = $('aiwiki-mic');
    sendBtn.onclick = ask;
    setupVoiceInput();
    inputEl.onkeydown = e => { if (e.key === 'Enter') ask(); };
    inputEl.focus();
    if (!transcript.length) addMsg(t('aiwiki_welcome'), 'bot');
    else transcript.forEach(renderMessage);
  }

  window.showAIWiki = function () {
    view = 'aiwiki';
    setNav('aiwiki');
    buildUI();
  };

  function setupVoiceInput() {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) {
      micBtn.disabled = true;
      micBtn.title = t('aiwiki_voice_unsupported');
      micBtn.setAttribute('aria-label', t('aiwiki_voice_unsupported'));
      return;
    }
    micBtn.title = t('aiwiki_voice_start');
    micBtn.setAttribute('aria-label', t('aiwiki_voice_start'));
    micBtn.onclick = toggleVoiceInput;
  }

  function resetVoiceRecognition() {
    const current = recognition;
    recognition = null;
    voiceListening = false;
    if (!current) return;
    current.onstart = null;
    current.onresult = null;
    current.onerror = null;
    current.onend = null;
    try { current.abort(); } catch (_) {}
  }

  function toggleVoiceInput() {
    if (voiceListening && recognition) {
      recognition.stop();
      return;
    }
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) return;
    const current = new SpeechRecognition();
    recognition = current;
    current.lang = typeof lang !== 'undefined' && lang === 'pl' ? 'pl-PL' : 'en-US';
    current.continuous = false;
    current.interimResults = true;
    current.maxAlternatives = 1;
    const startingText = inputEl.value.trim();
    let receivedSpeech = false;
    let recognitionError = false;

    current.onstart = () => {
      if (recognition !== current) return;
      voiceListening = true;
      micBtn.classList.add('listening');
      micBtn.setAttribute('aria-pressed', 'true');
      micBtn.title = t('aiwiki_voice_stop');
      micBtn.setAttribute('aria-label', t('aiwiki_voice_stop'));
      window.toast && window.toast(t('aiwiki_voice_listening'), 'info');
    };
    current.onresult = (event) => {
      if (recognition !== current) return;
      let finalText = '';
      let interimText = '';
      for (let i = 0; i < event.results.length; i++) {
        const result = event.results[i];
        if (result.isFinal) finalText += result[0].transcript;
        else interimText += result[0].transcript;
      }
      const recognized = (finalText + interimText).trim();
      if (recognized) receivedSpeech = true;
      inputEl.value = [startingText, recognized].filter(Boolean).join(' ');
    };
    current.onerror = (event) => {
      if (recognition !== current || event.error === 'aborted') return;
      recognitionError = true;
      const messages = {
        'not-allowed': 'aiwiki_voice_denied',
        'service-not-allowed': 'aiwiki_voice_denied',
        'audio-capture': 'aiwiki_voice_audio',
        'network': 'aiwiki_voice_network',
        'no-speech': 'aiwiki_voice_no_speech',
        'language-not-supported': 'aiwiki_voice_language',
      };
      const key = messages[event.error];
      const message = key ? t(key) : t('aiwiki_voice_error') + (event.error || 'unknown');
      window.toast && window.toast(message, 'fail');
    };
    current.onend = () => {
      if (recognition !== current) return;
      recognition = null;
      voiceListening = false;
      micBtn.classList.remove('listening');
      micBtn.setAttribute('aria-pressed', 'false');
      micBtn.title = t('aiwiki_voice_start');
      micBtn.setAttribute('aria-label', t('aiwiki_voice_start'));
      if (!recognitionError) {
        const message = receivedSpeech ? t('aiwiki_voice_ready') : t('aiwiki_voice_no_speech');
        window.toast && window.toast(message, receivedSpeech ? 'ok' : 'warn');
      }
      inputEl.focus();
    };
    try {
      current.start();
    } catch (error) {
      recognition = null;
      window.toast && window.toast(t('aiwiki_voice_start_error') + (error.name || error.message || 'unknown'), 'fail');
    }
  }
  window.renderAIWiki = buildUI;

  function addMsg(text, who, extras) {
    if (!msgsEl) return;
    const item = {
      text,
      who,
      sources: extras && Array.isArray(extras.sources) ? extras.sources : [],
      actions: extras && Array.isArray(extras.actions) ? extras.actions : [],
    };
    transcript.push(item);
    renderMessage(item);
  }

  function renderMessage(item) {
    if (!msgsEl) return;
    const div = document.createElement('div');
    div.className = 'aiwiki-msg ' + item.who;
    if (item.who === 'bot') {
      const body = document.createElement('div');
      body.className = 'markdown-body aiwiki-answer';
      body.appendChild(renderMarkdown(item.text));
      div.appendChild(body);
    } else {
      div.textContent = item.text;
    }
    if (item.sources.length || item.actions.length) {
      const extras = document.createElement('div');
      const src = renderSources(item.sources);
      const acts = renderActions(item.actions);
      if (src) extras.appendChild(src);
      if (acts) extras.appendChild(acts);
      div.appendChild(extras);
    }
    msgsEl.appendChild(div);
    msgsEl.scrollTop = msgsEl.scrollHeight;
  }

  // Parse Markdown, then copy only an explicit safe subset into the live DOM.
  // Do not insert Marked's HTML directly: model output is untrusted input.
  function renderMarkdown(markdown) {
    if (typeof marked === 'undefined' || typeof DOMParser === 'undefined') {
      return document.createTextNode(markdown || '');
    }
    let parsed;
    try {
      parsed = new DOMParser().parseFromString(marked.parse(markdown || ''), 'text/html');
    } catch (_) {
      return document.createTextNode(markdown || '');
    }

    const allowed = new Set([
      'P', 'BR', 'STRONG', 'B', 'EM', 'I', 'DEL', 'S', 'UL', 'OL', 'LI',
      'PRE', 'CODE', 'BLOCKQUOTE', 'H1', 'H2', 'H3', 'H4', 'HR',
      'A', 'TABLE', 'THEAD', 'TBODY', 'TFOOT', 'TR', 'TH', 'TD'
    ]);
    const dropContent = new Set(['SCRIPT', 'STYLE', 'IFRAME', 'OBJECT', 'EMBED', 'SVG', 'MATH', 'TEMPLATE']);
    const output = document.createDocumentFragment();

    function safeLink(raw) {
      if (!raw) return null;
      try {
        const url = new URL(raw, window.location.href);
        if (!['http:', 'https:', 'mailto:'].includes(url.protocol)) return null;
        return url;
      } catch (_) {
        return null;
      }
    }

    function copyChildren(source, target) {
      for (const child of source.childNodes) {
        if (child.nodeType === Node.TEXT_NODE) {
          target.appendChild(document.createTextNode(child.nodeValue || ''));
          continue;
        }
        if (child.nodeType !== Node.ELEMENT_NODE) continue;
        const tag = child.tagName;
        if (dropContent.has(tag)) continue;
        if (!allowed.has(tag)) {
          copyChildren(child, target);
          continue;
        }
        const clean = document.createElement(tag.toLowerCase());
        if (tag === 'A') {
          const url = safeLink(child.getAttribute('href'));
          if (!url) {
            copyChildren(child, target);
            continue;
          }
          clean.href = url.href;
          if (url.origin !== window.location.origin && url.protocol !== 'mailto:') {
            clean.target = '_blank';
            clean.rel = 'noopener noreferrer';
          }
        }
        copyChildren(child, clean);
        target.appendChild(clean);
      }
    }

    copyChildren(parsed.body, output);
    return output;
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
    if ((s.type === 'runtime' || s.type === 'runtime_log') && src.startsWith('runs/')) {
      const runId = s.path.slice('runs/'.length);
      window.location.hash = '#/run/' + encodeURIComponent(runId);
    } else if (src.startsWith('dags/')) {
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
                window.location.hash = '#/run/' + encodeURIComponent(run.run_id);
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
        body: JSON.stringify({
          question: q,
          lang: (typeof lang !== 'undefined' ? lang : 'en'),
          history: conversationHistory.slice(-8),
        }),
      });
      if (!resp.ok) throw new Error('HTTP ' + resp.status);
      const data = await resp.json();
      const answer = data.answer || t('aiwiki_fallback');
      addMsg(answer, 'bot', { sources: data.sources, actions: data.actions });
      const runtimeSource = (data.sources || []).find(s => s.type === 'runtime' || s.type === 'runtime_log');
      const historyAnswer = runtimeSource
        ? 'Cronova runtime data was shown for ' + runtimeSource.path.replace(/^runs\//, '') + '.'
        : answer;
      conversationHistory.push({ role: 'user', content: q }, { role: 'assistant', content: historyAnswer });
      if (conversationHistory.length > 8) conversationHistory = conversationHistory.slice(-8);
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
