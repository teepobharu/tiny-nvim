# Deep Nested File — Breadcrumb Fixture

Tests for S7 (breadcrumb) and S8 (file tree panel).

This file lives at `tests/fixtures/sub/deep.md` — three levels below the plugin root.

---

## Breadcrumb (S7)

When this file is open, the breadcrumb should show:

```
/ > … > tests > fixtures > sub > deep.md
```

- All segments except `deep.md` should be clickable
- Clicking `fixtures` should open the tree panel at that directory
- Clicking `sub` should open the tree panel at `fixtures/sub/`

---

## Tree panel from here (S8)

Click any breadcrumb segment to open the tree and navigate up or sideways.

---

## Back to parent (S7.3 / S8.3)

[Back to fixtures index](../index.md)
