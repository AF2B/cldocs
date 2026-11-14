# CLDocs

Community reference for Common Lisp: one page per symbol with signature,
docstring, community examples and cross-references. Inspired by ClojureDocs.

Status: M0 (skeleton). See the project plan for milestones.

## Check

```bash
sbcl --non-interactive --load scripts/check.lisp
```

Fails on any `WARNING` or `STYLE-WARNING` and on any test failure.

## Legal

The Common Lisp HyperSpec is copyrighted by LispWorks Ltd. CLDocs links to it
and never copies its text or images.
