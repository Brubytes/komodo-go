/**
 * Test configuration for the default template
 *
 * devices: Which devices to test on
 *   - 'default': Representative subset (iphone-6.5, iphone-5.5, ipad-13, android-phone)
 *   - 'all': All 14 devices
 *   - [...]: Custom array of device IDs
 *
 * variants: Array of test cases with different options
 */
export default {
  devices: 'default',

  variants: [
    {
      name: 'light-top',
      theme: 'light',
      layout: 'top',
      headline: 'Feature Title',
      subheadline: 'Description text goes here'
    },
    {
      name: 'dark-top',
      theme: 'dark',
      layout: 'top',
      headline: 'Feature Title',
      subheadline: 'Description text goes here'
    },
    {
      name: 'light-bottom',
      theme: 'light',
      layout: 'bottom',
      headline: 'Feature Title',
      subheadline: 'Description text goes here'
    }
  ]
};
