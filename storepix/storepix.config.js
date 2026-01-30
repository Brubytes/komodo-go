// storepix configuration for Komodo Go
// Documentation: https://github.com/Madnex/storepix
// Template: default - Gradient background with decorative blur effects

export default {
  // Template to use (from ./templates/)
  template: 'default',

  // Output settings
  output: {
    dir: './output',
    format: 'png',
  },

  // Device sizes to generate
  // iPhone:
  //   'iphone-6.9'  - iPhone 16 Pro Max, 16 Plus, 15 Pro Max (REQUIRED for App Store)
  //   'iphone-6.7'  - iPhone 15 Pro Max
  //   'iphone-6.5'  - iPhone 14 Plus, 13 Pro Max, 12 Pro Max (fallback if no 6.9)
  //   'iphone-6.3'  - iPhone 16 Pro, 16, 15 Pro, 15, 14 Pro
  //   'iphone-6.1'  - iPhone 16e, 14, 13, 12, 11, X
  //   'iphone-5.5'  - iPhone 8 Plus, 7 Plus, 6S Plus (home button)
  //   'iphone-4.7'  - iPhone SE, 8, 7, 6S (home button)
  // iPad:
  //   'ipad-13'     - iPad Pro 13", iPad Air M3/M2 (REQUIRED for iPad apps)
  //   'ipad-12.9'   - iPad Pro 12.9" (older)
  //   'ipad-11'     - iPad Pro 11", iPad Air, iPad mini
  // Android:
  //   'android-phone', 'android-tablet-7', 'android-tablet-10', 'android-wear'
  devices: ['iphone-6.5'],

  // Theme customization (injected as CSS variables)
  // Komodo brand colors
  theme: {
    primary: '#014226', // Komodo primary green
    font: 'Inter',
  },

  // Status bar injection (adds realistic status bar to screenshots)
  // Note: Use screenshots WITHOUT a visible status bar for best results.
  // statusBar: {
  //   enabled: true,
  //   time: '9:41',
  //   battery: 100,
  //   showBatteryPercent: true,
  //   style: 'auto',
  // },

  // Your screenshots
  screenshots: [
    {
      id: '01_home',
      source: './screenshots/iPhone/dark_01_home_dashboard.png',
      headline: 'Your Infrastructure',
      subheadline: 'at a glance',
      theme: 'dark',
      layout: 'top',
    },
    {
      id: '02_servers',
      source: './screenshots/iPhone/dark_02_servers_list.png',
      headline: 'Monitor',
      subheadline: 'your servers',
      theme: 'dark',
      layout: 'bottom',
    },
    {
      id: '03_server_detail',
      source: './screenshots/iPhone/dark_03_server_detail.png',
      headline: 'Deep Dive',
      subheadline: 'into metrics',
      theme: 'dark',
      layout: 'top',
    },
    {
      id: '04_containers',
      source: './screenshots/iPhone/light_04_containers.png',
      headline: 'Manage',
      subheadline: 'containers',
      theme: 'light',
      layout: 'bottom',
    },
    {
      id: '05_resources',
      source: './screenshots/iPhone/light_05_resources.png',
      headline: 'All Resources',
      subheadline: 'one overview',
      theme: 'light',
      layout: 'top',
    },
    {
      id: '06_settings',
      source: './screenshots/iPhone/light_06_settings.png',
      headline: 'Configure',
      subheadline: 'your way',
      theme: 'light',
      layout: 'bottom',
    },
  ],

  // Optional: Localization
  // Uncomment and customize to generate multiple languages
  // locales: {
  //   en: {
  //     '01_home': { headline: 'Your Infrastructure', subheadline: 'at a glance' },
  //   },
  //   de: {
  //     '01_home': { headline: 'Deine Infrastruktur', subheadline: 'auf einen Blick' },
  //   },
  // },
};
