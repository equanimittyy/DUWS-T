# Jost*

`Jost-var.ttf` is Jost* v3.710, Copyright 2020 The Jost Project Authors
(<https://github.com/indestructible-type/Jost>), under the SIL Open Font Licence 1.1.
Full terms in [`OFL.txt`](OFL.txt); the same declaration is embedded in the font's own
name table (IDs 0, 13, 14).

It is vendored because the promo build scripts need a Futura-class face and Futura BT
is not redistributable. At the wordmark template's spec Jost* reproduces its cap height
and inked width to within 0.3%, so the geometry constants in those scripts assume this
face — substituting another invalidates them.

The OFL is independent of the mission's own GPLv3 (`src/LICENSE.md`). It
permits bundling under any licence provided the font keeps its copyright notice and
licence, stays under the OFL, and is never sold on its own. No Reserved Font Name is
declared, so a renamed derivative is unconstrained.
