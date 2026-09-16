# Tracker capabilities live in tracker config

Shared skills name tracker-neutral concepts; the configured tracker file translates them
into that tracker's nouns, identifiers, relationships, and limits. In particular,
`to-spec` and `to-tickets` say **parent item**, while each
`docs/agents/issue-tracker.md` defines whether that means a GitHub tracking issue, a
GitLab epic or parent issue, a Shortcut epic under an objective, or a local feature
directory.

This keeps capabilities instead of flattening every tracker to the least capable one.
Shortcut can still use its native hierarchy and carry its description limit, while
GitHub can use native sub-issues and local markdown needs no synthetic parent
object. The cost is a required section in every tracker template, which is the right
coupling: a tracker integration must declare how it implements concepts that shared skills
consume.
