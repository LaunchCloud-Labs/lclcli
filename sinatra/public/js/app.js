/* ============================================================
   LaunchCore Command — app.js
   Live Terminal Console + CLI Bridge
   LaunchCloud Labs © 2026
   ============================================================ */

'use strict';

/* ── Terminal State ─────────────────────────────────────────── */
const Terminal = {
  history:     [],
  historyIdx:  -1,
  pendingLine: '',

  init() {
    const input = document.getElementById('terminal-input');
    if (!input) return;

    input.addEventListener('keydown', e => {
      if (e.key === 'Enter') {
        e.preventDefault();
        this.exec(input.value.trim());
        input.value = '';
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        if (this.history.length === 0) return;
        if (this.historyIdx === -1) this.pendingLine = input.value;
        this.historyIdx = Math.min(this.historyIdx + 1, this.history.length - 1);
        input.value = this.history[this.historyIdx] || '';
      } else if (e.key === 'ArrowDown') {
        e.preventDefault();
        if (this.historyIdx <= 0) {
          this.historyIdx = -1;
          input.value = this.pendingLine;
          return;
        }
        this.historyIdx--;
        input.value = this.history[this.historyIdx] || '';
      } else if (e.key === 'Escape') {
        closeTerminal();
      }
    });
  },

  exec(command) {
    if (!command) return;
    this.history.unshift(command);
    this.historyIdx = -1;
    this.pendingLine = '';
    if (this.history.length > 100) this.history.pop();

    this.appendLine(`$ lc ${command} --json`, 'cmd');
    this.appendLine('Executing…', 'info');

    fetch('/api/exec', {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    JSON.stringify({ command })
    })
    .then(r => {
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      return r.json();
    })
    .then(data => {
      // Remove the "Executing…" placeholder
      const out    = document.getElementById('terminal-output');
      const pending = out.querySelector('.term-pending');
      if (pending) pending.remove();

      const formatted = JSON.stringify(data, null, 2);
      const cls       = data.status === 'ok' ? 'ok' : 'err';
      this.appendLine(formatted, cls);

      // Mirror to dashboard output panel
      const panel = document.getElementById('cli-output-panel');
      if (panel) {
        panel.innerHTML = `<pre class="cli-output-json">${syntaxHighlight(formatted)}</pre>`;
      }
    })
    .catch(err => {
      const out     = document.getElementById('terminal-output');
      const pending = out.querySelector('.term-pending');
      if (pending) pending.remove();
      this.appendLine(`Error: ${err.message}`, 'err');
    });
  },

  appendLine(text, type = 'info') {
    const out  = document.getElementById('terminal-output');
    if (!out) return;
    const div  = document.createElement('div');
    div.className = `terminal-entry term-${type}${type === 'info' ? ' term-pending' : ''}`;

    if (type === 'ok' || type === 'err') {
      // Pretty-print JSON with syntax highlighting
      try {
        const parsed = JSON.parse(text);
        div.innerHTML = syntaxHighlight(JSON.stringify(parsed, null, 2));
      } catch {
        div.textContent = text;
      }
    } else {
      div.textContent = text;
    }

    out.appendChild(div);
    out.scrollTop = out.scrollHeight;
  }
};

/* ── JSON Syntax Highlighting ────────────────────────────────── */
function syntaxHighlight(json) {
  if (typeof json !== 'string') json = JSON.stringify(json, null, 2);
  return json
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(
      /("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?)/g,
      match => {
        let cls = 'json-num';
        if (/^"/.test(match)) {
          cls = /:$/.test(match) ? 'json-key' : 'json-str';
        } else if (/true|false/.test(match)) {
          cls = 'json-bool';
        } else if (/null/.test(match)) {
          cls = 'json-null';
        }
        return `<span class="${cls}">${match}</span>`;
      }
    );
}

/* ── Terminal Overlay Controls ────────────────────────────────── */
function openTerminal() {
  const overlay = document.getElementById('terminal-overlay');
  if (!overlay) return;
  overlay.classList.remove('hidden');
  document.body.style.overflow = 'hidden';
  const input = document.getElementById('terminal-input');
  if (input) setTimeout(() => input.focus(), 100);
}

function closeTerminal() {
  const overlay = document.getElementById('terminal-overlay');
  if (!overlay) return;
  overlay.classList.add('hidden');
  document.body.style.overflow = '';
}

function toggleTerminal() {
  const overlay = document.getElementById('terminal-overlay');
  if (!overlay) return;
  overlay.classList.contains('hidden') ? openTerminal() : closeTerminal();
}

function setTermCmd(cmd) {
  const input = document.getElementById('terminal-input');
  if (input) {
    input.value = cmd;
    input.focus();
  }
}

/* Called from terminal overlay "Execute" button */
function terminalExec() {
  const input = document.getElementById('terminal-input');
  if (!input) return;
  Terminal.exec(input.value.trim());
  input.value = '';
}

/* ── Dashboard helpers ───────────────────────────────────────── */

// Runs a command and shows output in the CLI output panel + opens terminal
function runCmd(command) {
  openTerminal();
  const input = document.getElementById('terminal-input');
  if (input) input.value = command;
  Terminal.exec(command);
  if (input) input.value = '';
}

// Append a line from external callers (e.g. dashboard quick-action)
function appendTerminalLine(text, type) {
  Terminal.appendLine(text, type);
}

/* ── Flash auto-dismiss ───────────────────────────────────────── */
function autoDismissFlash() {
  const flash = document.querySelector('.flash');
  if (flash) {
    setTimeout(() => {
      flash.style.transition = 'opacity 0.5s';
      flash.style.opacity    = '0';
      setTimeout(() => flash.remove(), 600);
    }, 4000);
  }
}

/* ── Click outside to close terminal ─────────────────────────── */
function bindClickOutside() {
  const overlay = document.getElementById('terminal-overlay');
  if (!overlay) return;
  overlay.addEventListener('click', e => {
    if (e.target === overlay) closeTerminal();
  });
}

/* ── Keyboard shortcut ───────────────────────────────────────── */
function bindKeyboardShortcuts() {
  document.addEventListener('keydown', e => {
    // ` (backtick) toggles terminal
    if (e.key === '`' && !e.ctrlKey && !e.metaKey && !e.altKey) {
      const active = document.activeElement;
      if (active && (active.tagName === 'INPUT' || active.tagName === 'TEXTAREA')) return;
      e.preventDefault();
      toggleTerminal();
    }
    // Escape closes terminal
    if (e.key === 'Escape') {
      const overlay = document.getElementById('terminal-overlay');
      if (overlay && !overlay.classList.contains('hidden')) closeTerminal();
    }
  });
}

/* ── Product tile click (dashboard) ─────────────────────────── */
function execProduct(key) {
  const command = `/${key}`;
  openTerminal();
  const input = document.getElementById('terminal-input');
  if (input) input.value = command;
  Terminal.exec(command);
  if (input) input.value = '';
}

/* ── Init ─────────────────────────────────────────────────── */
document.addEventListener('DOMContentLoaded', () => {
  Terminal.init();
  autoDismissFlash();
  bindClickOutside();
  bindKeyboardShortcuts();

  // Add 'products' and 'auth_levels' helpers to the index page if needed
  // (passed server-side as data attrs on the container)
  const container = document.getElementById('lc-data');
  if (container) {
    window._LC = {
      products:    JSON.parse(container.dataset.products   || '{}'),
      auth_levels: JSON.parse(container.dataset.authLevels || '{}')
    };
  }
});
