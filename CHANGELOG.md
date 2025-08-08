# Changelog

All notable changes to this project will be documented in this file.

## 0.3.1 - 2025-08-08

### Added

- `Zoi.ISO.time/1` type
- `Zoi.ISO.date/1` type
- `Zoi.ISO.datetime/1` type
- `Zoi.ISO.to_time_struct/1` transform
- `Zoi.ISO.to_date_struct/1` transform
- `Zoi.ISO.to_datetime_struct/1` transform
- `Zoi.ISO.to_naive_datetime/1` transform
- `Zoi.prettify_errors/1` function to format errors in a human-readable way

## 0.3.0 - 2025-08-07

### Added

- `Zoi.email/0` format
- `Zoi.url/0` format
- `Zoi.uuid/1` format

### Changed

- Removed `Zoi.email/1`, now use `Zoi.email/0` that will automatically use the `Zoi.string/1` type
- All refinements now accept a `:message` option to customize the error message

## 0.2.3 - 2025-08-06

### Added

- `Zoi.map/3` type
- `Zoi.intersection/2` type
- `Zoi.gt/2` refinement
- `Zoi.gte/2` refinement
- `Zoi.lt/2` refinement
- `Zoi.lte/2` refinement

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
