// Renders the ```mermaid blocks of the built site (iltiam-deployment#4). GitHub renders them on its own.
// MkDocs wraps each block in <pre class="mermaid"><code>, and Mermaid must get the plain text. So: stop Mermaid's own
// start-on-load (it would render the wrapped HTML first), unwrap the blocks, then render them.
if (window.mermaid) window.mermaid.initialize({ startOnLoad: false })
window.addEventListener('DOMContentLoaded', async () => {
  if (!window.mermaid) return
  const blocks = [...document.querySelectorAll('pre.mermaid')]
  blocks.forEach((block) => {
    block.textContent = block.textContent
  })
  await window.mermaid.run({ nodes: blocks })
})
