The original artwork is `Komodo-GO-Painted.svg`; `Komodo-GO-Outlines.svg` is
retained unchanged as an alternate source. Dark artwork uses ivory and lighter
green on charcoal. The app selects the logo using its active theme; native
launch screens and iOS dark icons follow the system appearance.

To regenerate (Inkscape on PATH, or its standard Windows installation):

```sh
python tool/generate_logo_assets.py
fvm dart run flutter_launcher_icons
fvm dart run flutter_native_splash:create
# Restore the web maskable icons' extra safe-area padding after generation.
python tool/generate_logo_assets.py
```

Square artwork occupies 94% of the source canvas, circular artwork 80%, and web
maskable artwork 65%. Android adaptive icons use a 21% foreground inset. Keep
this padding: square and circular system masks expose different areas.
