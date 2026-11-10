// Renders the ```mermaid blocks of the built site (iltiam-deployment#4). GitHub renders them on its own.
// MkDocs wraps each block in <pre class="mermaid"><code>; Mermaid must get the plain text, so unwrap it first.
window.addEventListener('load', async () => {
  if (!window.mermaid) return
  const blocks = document.querySelectorAll('pre.mermaid')
  blocks.forEach((block) => {
    block.textContent = block.textContent
  })
  window.mermaid.initialize({ startOnLoad: false })
  await window.mermaid.run({ nodes: [...blocks] })
})
