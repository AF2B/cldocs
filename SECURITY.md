# Security

CLDocs publishes a static site; contributed examples are executed only by the
maintainers' build and by the pull request check, both on ephemeral GitHub runners
without secrets. The static rules in `src/community.lisp` are defence in depth, not a
sandbox: a maintainer must read every contributed file before merging.

To report a vulnerability, open a private security advisory on the repository, or
email the maintainer listed in `cldocs.asd`. Please do not file public issues for
security problems.
