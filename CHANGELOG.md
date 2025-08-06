# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

### Added

- `Zoi.map/3` type

## 0.2.2 - 2025-08-06

### Added

- Guides for using `Zoi` in Phoenix controllers
- New `Zoi.tuple/2` type
- New `Zoi.any/1` type
- New `Zoi.nullable/2` type

### Changed

- Improved error messages for all validations and types
- `Zoi.treefy_errors/1` now returns a more human-readable structure
- `Zoi.optional/2` cannot accept `nil` as a value anymore. Use `Zoi.nullable/2` instead.
- `Zoi.optional/2` inside `Zoi.object/2` now handles optional fields correctly

## 0.2.1 - 2025-08-06

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
