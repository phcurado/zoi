# Changelog

All notable changes to this project will be documented in this file.

## 0.5.6 - 2025-09-05

### Added

- `Zoi.parse!/3` function that raises an error if parsing fails
- `Zoi.type_spec/2` function that returns the Elixir type spec for a given Zoi schema, implemented for all types

## 0.5.5 - 2025-09-03

### Added

- `Zoi.keyword/2` type

### Changed

- `Zoi.struct/2` now works with the new `Zoi.keyword/2` type
- Improved `Zoi.transform/2` documentation

## 0.5.4 - 2025-08-29

### Added

- Guide for converting keys from maps
- Guide for generating schema from JSON structure

## 0.5.3 - 2025-08-29

### Changed

- Fix `transform` and `refinement` types

## 0.5.2 - 2025-08-28

### Added

- `Zoi.prettify_errors/2` added docs
- `Zoi.extend/3` type

### Changed

- `Zoi.map/3` now parses key and value types correctly
- Fix encapsulated types ignoring refinements and transforms when parsing

## 0.5.1 - 2025-08-17

### Changed

- `Zoi.prettify_errors/1` don't return `\n` at the end of the string anymore

## 0.5.0 - 2025-08-17

### Added

- `Zoi.atom/1` type
- `Zoi.string_boolean/1` type
- `Zoi.union/2` custom error messages
- `Zoi.intersection/2` custom error messages
- `Zoi.to_struct/2` transform

### Changed

- `Zoi.boolean/1` does not coerce values besides "true" and "false" anymore. For coercion of other values, use `Zoi.string_boolean/1` type.

## 0.4.0 - 2025-08-14

### Added

- `Zoi.Context` module to provide context when parsing data

### Changed

- `Zoi.object/2` will not automatically parse objects with inputs that differ from the string/atom keys map format. For example:

```elixir
schema = Zoi.object(%{
  name: Zoi.string(),
  age: Zoi.integer()
})
Zoi.object(schema, %{"name" => "John", "age" => 30})
{:error, _errors}
```

To make this API work, you can pass `coerce: true` option to `Zoi.object/2`. This will make the object parser to check from the `Map` input if the keys are strings or atoms and fetch it's values automatically.

```elixir
schema = Zoi.object(%{
  name: Zoi.string(),
  age: Zoi.integer()
})
Zoi.object(schema, %{"name" => "John", "age" => 30}, coerce: true)
{:ok, %{name: "John", age: 30}}
```

## 0.3.4 - 2025-08-09

### Added

- `Zoi.min/2`, `Zoi.max/2`, `Zoi.gt/2`, `Zoi.gte/2`, `Zoi.lt/2`, `Zoi.lte/2` refinements for `Zoi.time/1` type
- `Zoi.min/2`, `Zoi.max/2`, `Zoi.gt/2`, `Zoi.gte/2`, `Zoi.lt/2`, `Zoi.lte/2` refinements for `Zoi.date/1` type
- `Zoi.min/2`, `Zoi.max/2`, `Zoi.gt/2`, `Zoi.gte/2`, `Zoi.lt/2`, `Zoi.lte/2` refinements for `Zoi.datetime/1` type
- `Zoi.min/2`, `Zoi.max/2`, `Zoi.gt/2`, `Zoi.gte/2`, `Zoi.lt/2`, `Zoi.lte/2` refinements for `Zoi.naive_datetime/1` type

## 0.3.3 - 2025-08-09

### Added

- `Zoi.time/1` type
- `Zoi.date/1` type
- `Zoi.datetime/1` type
- `Zoi.naive_datetime/1` type

## 0.3.2 - 2025-08-09

### Added

- `Zoi.decimal/1` type
- `Zoi.min/2`, `Zoi.max/2`, `Zoi.gt/2`, `Zoi.gte/2`, `Zoi.lt/2`, `Zoi.lte/2` refinements for `Zoi.decimal/1` type

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

- `Zoi.number/2` now returns proper error message

## 0.2.0 - 2025-08-05

### Added

- `mfa` to `Zoi.refine/2` and `Zoi.transform/2` functions
- accumulator errors to `Zoi.refine/2` and `Zoi.transform/2` functions
- `Zoi.array/2` type
- `Zoi.length/2`, `Zoi.min/2` and `Zoi.max/2` validators for arrays

### Changed

- errors are now returned as a list of `%Zoi.Error{}` structs
