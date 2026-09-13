"""Expands {{FILE:...}} and {{SNIPPET:file:start:end}} in the template with the
verified stage sources, then writes codelab.md."""
import re, sys, pathlib
root = pathlib.Path(__file__).parent
stages = root / 'app' / 'stages'
t = (root / 'codelab.template.md').read_text()

def file_(m):
    return (stages / m.group(1)).read_text().rstrip('\n')

def snippet(m):
    src = (stages / m.group(1)).read_text().split('\n')
    start, end = m.group(2), m.group(3)
    i = next(k for k, l in enumerate(src) if start in l)
    j = next(k for k in range(i, len(src)) if end in src[k])
    block = src[i:j + 1]
    pad = min(len(l) - len(l.lstrip()) for l in block if l.strip())
    return '\n'.join(l[pad:] for l in block)

t = re.sub(r'\{\{FILE:([^}]+)\}\}', file_, t)
t = re.sub(r'\{\{SNIPPET:([^|}]+)\|([^|}]+)\|([^}]+)\}\}', snippet, t)
assert '{{' not in t
(root / 'codelab.md').write_text(t)
print('ok', len(t))
