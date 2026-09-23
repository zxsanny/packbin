# Ripple log — loop 2

- The six package descriptions list string, list, and dictionary values because AZ-1938, AZ-1939, and AZ-1940 added those fields to each packer.
- `.github/workflows/drivers/` imports each package for the AZ-1941 handoff. Those drivers are the test harness, not a seventh package.
- No other component imports the packers.
