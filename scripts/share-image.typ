// Social preview image (1200x630) in the Borba Design System.
// Regenerate: typst compile --format png --ppi 72 \
//   --font-path vendor/borba-design-system/fonts scripts/share-image.typ assets/share.png

#let midnight = rgb("#000510")
#let white = rgb("#ffffff")
#let grey = rgb("#8899a6")
#let blue = rgb("#0074D9")
#let border = rgb("#333333")

#set page(width: 1200pt, height: 630pt, margin: 72pt, fill: midnight)
#set text(font: "Inter", fill: white)

#place(top + left)[
  #text(size: 34pt, weight: "bold", tracking: 2pt)[BORBA#text(fill: blue)[.]]
]

#place(horizon + left)[
  #text(font: "JetBrains Mono", size: 22pt, fill: blue)[COMMON LISP REFERENCE] \
  #v(8pt)
  #text(size: 104pt, weight: "bold")[CLDocs] \
  #v(4pt)
  #text(size: 34pt, fill: grey)[Every symbol on its own page, with examples that run.]
]

#place(bottom + left)[
  #line(length: 1056pt, stroke: 1pt + border)
  #v(10pt)
  #text(font: "JetBrains Mono", size: 20pt, fill: grey)[af2b.github.io/cldocs · EN · PT-BR]
]
