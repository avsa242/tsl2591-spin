# tsl2591-spin 
---------------

This is a P8X32A/Propeller driver object for the AMS TSL2591 Lux Sensor.

## Salient Features

* I2C connection up to 400kHz
* Read all sensor channels together, or individually
* Set interrupt thresholds (persistent and non-persistent)
* Set integration time
* Set gain multiplier
* Can sleep after interrupts

## Requirements

* 1 extra core/cog for the PASM I2C driver

## Limitations

* Very early in development - may malfunction or outright fail to build
* Luminosity is currently unverified

## TODO

- [x] Clean up the demo object
- [ ] Verify luminosity readings against certified/calibrated device
- [ ] Implement better/multiple LUX calculations
