// Minimal CodeMirror 6 editor bundle for Wikiwise.
// Gets bundled into a single IIFE via esbuild, loaded in a WKWebView.

import { EditorView, keymap, lineNumbers, highlightActiveLine, highlightActiveLineGutter, drawSelection } from '@codemirror/view'
import { EditorState } from '@codemirror/state'
import { markdown } from '@codemirror/lang-markdown'
import { defaultKeymap, history, historyKeymap, indentWithTab } from '@codemirror/commands'
import { syntaxHighlighting, HighlightStyle, bracketMatching } from '@codemirror/language'
import { tags } from '@lezer/highlight'

let view = null
let saveTimeout = null

// Called from Swift to set the editor content
window.setContent = function(text) {
  if (view) {
    view.dispatch({
      changes: { from: 0, to: view.state.doc.length, insert: text }
    })
  }
}

// Called from Swift to get the current content
window.getContent = function() {
  return view ? view.state.doc.toString() : ''
}

function notifyChange() {
  clearTimeout(saveTimeout)
  saveTimeout = setTimeout(function() {
    if (window.webkit && window.webkit.messageHandlers.contentChanged) {
      window.webkit.messageHandlers.contentChanged.postMessage(
        view.state.doc.toString()
      )
    }
  }, 500)
}

// ── Editorial highlight style ───────────────────────────────
// Makes markdown source feel closer to rendered output:
// big headers, real bold/italic, styled quotes and code.
const editorialHighlight = HighlightStyle.define([
  // Headings — progressively larger, serif, like the rendered output
  { tag: tags.heading1,
    fontSize: '1.5em', fontWeight: '400', fontStyle: 'italic',
    fontFamily: '"Source Serif 4", "Charter", Georgia, serif',
    color: '#1a1612', lineHeight: '1.2' },
  { tag: tags.heading2,
    fontSize: '1.25em', fontWeight: '500',
    fontFamily: '"Source Serif 4", "Charter", Georgia, serif',
    color: '#1a1612', lineHeight: '1.3' },
  { tag: tags.heading3,
    fontSize: '1.15em', fontWeight: '600', fontStyle: 'italic',
    fontFamily: '"Source Serif 4", "Charter", Georgia, serif',
    color: '#1a1612' },
  { tag: tags.heading4,
    fontSize: '0.85em', fontWeight: '600', textTransform: 'uppercase',
    letterSpacing: '0.08em', color: '#6c645a' },
  { tag: tags.heading5, fontSize: '0.85em', fontWeight: '600', color: '#6c645a' },
  { tag: tags.heading6, fontSize: '0.85em', fontWeight: '600', color: '#948b7e' },

  // Bold and italic — actually render as bold/italic
  { tag: tags.strong, fontWeight: '700', color: '#1a1612' },
  { tag: tags.emphasis, fontStyle: 'italic', color: '#2c2722' },

  // Links
  { tag: tags.link, color: '#7a1f1f', textDecoration: 'underline' },
  { tag: tags.url, color: '#948b7e', fontSize: '0.9em' },

  // Inline code
  { tag: tags.monospace,
    fontFamily: '"JetBrains Mono", "SF Mono", Menlo, monospace',
    fontSize: '0.88em', color: '#4a4540',
    backgroundColor: '#efe8d6', borderRadius: '2px' },

  // Code block info string (language label)
  { tag: tags.labelName, color: '#948b7e', fontStyle: 'italic' },

  // Block quotes — muted color
  { tag: tags.quote,
    color: '#6c645a', fontStyle: 'italic',
    fontFamily: '"Source Serif 4", "Charter", Georgia, serif' },

  // List markers — slightly darker so they don't look washed out
  { tag: tags.list, color: '#6c645a' },

  // Markdown punctuation — dim it so content stands out
  { tag: tags.processingInstruction, color: '#c8c0b4',
    fontSize: '0.85em', fontFamily: '"JetBrains Mono", Menlo, monospace' },
  { tag: tags.meta, color: '#b0a898' },                    // # markers, > markers, ** markers
  { tag: tags.contentSeparator, color: '#c8c0b4' },        // ---

  // Strikethrough
  { tag: tags.strikethrough, textDecoration: 'line-through', color: '#948b7e' },
])

// ── Editor chrome theme ─────────────────────────────────────
const openReaderTheme = EditorView.theme({
  '&': {
    fontSize: '15px',
    fontFamily: '"Source Serif 4", "Charter", "Iowan Old Style", Georgia, serif',
    backgroundColor: '#fbfaf5',
    color: '#1a1612',
    height: '100%',
  },
  '.cm-content': {
    padding: '24px 40px',
    maxWidth: '52rem',
    margin: '0 auto',
    caretColor: '#7a1f1f',
    lineHeight: '1.65',
  },
  '.cm-cursor': {
    borderLeftColor: '#7a1f1f',
  },
  '.cm-gutters': {
    backgroundColor: '#f5f0e6',
    color: '#c8c0b4',
    border: 'none',
    paddingRight: '8px',
    fontSize: '12px',
    fontFamily: '"JetBrains Mono", "SF Mono", Menlo, monospace',
  },
  '.cm-activeLineGutter': {
    backgroundColor: '#efe8d6',
    color: '#948b7e',
  },
  '.cm-activeLine': {
    backgroundColor: 'rgba(122, 31, 31, 0.03)',
  },
  '.cm-selectionBackground': {
    backgroundColor: 'rgba(122, 31, 31, 0.12) !important',
  },
  '&.cm-focused .cm-selectionBackground': {
    backgroundColor: 'rgba(122, 31, 31, 0.15) !important',
  },
  '.cm-line': {
    padding: '1px 0',
  },
  // Blockquote lines get a left border
  '.cm-line:has(.tok-quote)': {
    borderLeft: '3px solid #e3dccb',
    paddingLeft: '12px',
    marginLeft: '-15px',
  },
  // Fenced code blocks
  '.cm-line:has(.tok-monospace)': {
    fontFamily: '"JetBrains Mono", "SF Mono", Menlo, monospace',
    fontSize: '13px',
    lineHeight: '1.5',
  },
})

function init() {
  const parent = document.getElementById('editor')

  view = new EditorView({
    state: EditorState.create({
      doc: '',
      extensions: [
        lineNumbers(),
        highlightActiveLine(),
        highlightActiveLineGutter(),
        drawSelection(),
        bracketMatching(),
        history(),
        markdown(),
        syntaxHighlighting(editorialHighlight),
        EditorView.lineWrapping,
        keymap.of([
          ...defaultKeymap,
          ...historyKeymap,
          indentWithTab,
        ]),
        openReaderTheme,
        EditorView.updateListener.of(function(update) {
          if (update.docChanged) {
            notifyChange()
          }
        }),
        keymap.of([{
          key: 'Mod-s',
          run: function() {
            clearTimeout(saveTimeout)
            if (window.webkit && window.webkit.messageHandlers.contentChanged) {
              window.webkit.messageHandlers.contentChanged.postMessage(
                view.state.doc.toString()
              )
            }
            return true
          }
        }]),
      ],
    }),
    parent: parent,
  })

  if (window.webkit && window.webkit.messageHandlers.editorReady) {
    window.webkit.messageHandlers.editorReady.postMessage('ready')
  }
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init)
} else {
  init()
}
