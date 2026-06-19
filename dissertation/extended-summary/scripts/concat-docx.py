import sys

from docxcompose.composer import Composer
from docx import Document

items = [
    (path, int(order))
    for path, order in (arg.rsplit(":", 1) for arg in sys.argv[1:-1])
]
out = sys.argv[-1]

master = Document(items[0][0])

for child in list(master.element.body):
    if not child.tag.endswith("}sectPr"):
        master.element.body.remove(child)

composer = Composer(master)

for path, order in sorted(items, key=lambda x: x[1]):
    composer.append(Document(path))

composer.save(sys.argv[-1])