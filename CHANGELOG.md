# Changelog

All notable changes to this project will be documented in this file.

## 0.2.1 - 2025-08-05

### Added

- Custom error messages for primitive types

### Changed

- `number/2` now returns proper error message

## 0.2.0 - 2025-08-05

### Added

- `mfa` to `refine` and `transform` functions
- accumulator errors to `refine` and `transform` functions
- `array` type
- `length`, `min` and `max` validators for arrays

### Changed

- errors are now returned as a list of `%Zoi.Error{}` structs
