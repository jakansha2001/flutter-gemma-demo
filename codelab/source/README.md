# Codelab source

`codelab.template.md` is the file to edit. Code blocks are pulled in from the
Dart files under `app/stages/` (`{{FILE:...}}`, `{{SNIPPET:file|start|end}}`),
so the codelab always shows the exact code that was analyzed and tested.

Each stage folder is a complete `lib/` for that point in the codelab:
1 = text chat, 2 = vision, 3 = thinking, 4 = tools. Copy any one of them
into a project's `lib/` to run it.

Rebuild:

    python3 build_codelab.py              # template -> codelab.md
    claat export codelab.md               # github.com/googlecodelabs/tools
    python3 postprocess.py flutter-gemma-on-device/index.html
    cp flutter-gemma-on-device/index.html flutter-gemma-on-device/codelab.json ..

claat only ships an Intel macOS binary; on Apple Silicon run it with
`arch -x86_64 claat export codelab.md`.
