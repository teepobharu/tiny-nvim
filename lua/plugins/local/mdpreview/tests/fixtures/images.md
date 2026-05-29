# Image Resolution — Test Fixture

Tests for S6 (image serving).

---

## Relative image — MD's own directory (S6.1)

Should render via `/asset?path=<fixtures_dir>/sample.png`:

![relative image](./sample.png)

---

## Relative image — no leading dot (S6.1)

![relative no-dot](sample.png)

---

## External image — fetched directly by browser (S6.4)

Should not be rewritten (passes through as-is):

![external](https://via.placeholder.com/120x40?text=external)

---

## GitLab /uploads — left as-is, broken by design (S6.5)

Not under any allowed root — shows broken image placeholder:

![gitlab upload](/uploads/abc123/diagram.png)

---

## Absolute filesystem path image (S6.3)

Replace `<abs>` with a real image path under an allowed root to test:

<!-- ![abs](/abs/path/to/image.png) -->
