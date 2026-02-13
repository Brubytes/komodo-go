// Dedicated Storepix config for Google Play feature graphic (1024x500)
// Uses the "feature-graphic" template and generates a single output image.

export default {
  template: 'feature-graphic',

  output: {
    // Keep this separate from the normal screenshot output.
    dir: './output/feature-graphic',
    format: 'png',
  },

  // NOTE: Storepix 0.4.0 doesn't currently accept `android-feature-graphic` in
  // `devices` inside the config file (it gets ignored). Generate via:
  //   storepix generate -c ./storepix/storepix.feature-graphic.config.js \
  //     --device android-feature-graphic --template feature-graphic

  // Injected as CSS variables in the template.
  theme: {
    primary: '#014226',
    font: 'Inter',
  },

  screenshots: [
    {
      id: 'feature-graphic',
      // Storepix currently expects a source image entry to render an output,
      // even though the feature-graphic template doesn't use it.
      source: './screenshots/iPhone/dark_01_home_dashboard.png',
      headline: 'Komodo Go',
      subheadline: 'Your infrastructure at a glance',
      logo: './assets/komodo-go-logo.png',
      theme: 'dark',
    },
  ],
};
