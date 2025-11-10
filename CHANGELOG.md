# Changelog

All notable changes to this project will be documented in this file.

## 0.10.3 - 2025-11-10

### Added

- wrap `Zoi.Type.t()` into `Zoi.schema()` type
- Group guides on hexdocs

## 0.10.2 - 2025-11-10

### Added

- `Zoi.Schema.traverse/2` for recursively walking and transforming schema structures. This function applies a transformation to all nested fields while leaving the root schema unchanged, making it easy to apply operations like coercion, nullish, or defaults across an entire schema tree.
- `Zoi.coerce/1` helper function to enable type coercion on schemas that support it.

### Changed

- `Zoi.transform/2` and `Zoi.refine/2` are now chained in the order they were added, allowing more flexible validation and transformation flows.

## 0.10.1 - 2025-11-09

### Added

- `Zoi.describe/1` now supports `Zoi.struct/2` type.

## 0.10.0 - 2025-11-09

### Added

- `Zoi.Form` module with `prepare/1` and `parse/2` functions for seamless Phoenix form integration.
- `Phoenix.HTML.FormData` protocol implementation for `Zoi.Context`, enabling Phoenix form rendering without losing the original params.
- Partial parsing data is now preserved inside `%Zoi.Context{}` (and surfaced through forms) even when validation fails, allowing Phoenix forms to keep previously valid entries.
- Keyword schemas defined with another schema as the value now keep the successfully parsed entries even if a sibling entry fails validation.
- `Zoi.Form.prepare/1` now forces coercion on every nested field so Phoenix form strings are cast into their target types automatically.
- `Zoi.Form.parse/2` automatically normalizes LiveView's map-based array format (with numeric string keys) into regular lists in `ctx.input`, eliminating the need for manual conversion when manipulating array fields dynamically.
- Architecture diagram in main module documentation (`Zoi`) showing the parsing flow and validation pipeline with Mermaid visualization.

### Changed

- Achieved 100% test coverage across the entire codebase (previously 99.8%).

## 0.9.1 - 2025-11-06

### Added

- `Zoi.JSONSchema` now accepts `Zoi.decimal/1`, converting it to `type: "number"`.

## 0.9.0 - 2025-11-06

### Added

- `Zoi.array/2` now accepts `:coerce` option to force `Map` and `Tuple` types into an array.

### Changed

- `Zoi.type_spec/1` for object with string keys now returns generic `map()` type spec due to how Elixir handles this type internally.

## 0.9.0-rc.1 - 2025-11-04

### Added

- `Zoi.object/2` and `Zoi.keyword/2` now accept `:empty_values` option to define which values are considered empty when parsing objects and keyword lists. By default, this option is set to `[]`, meaning no values are considered empty. You can customize this option to include values like `nil`, empty strings (`""`), or any other value you want to treat as empty and it will return a `:required` error when those values are encountered for required fields.

## 0.9.0-rc.0 - 2025-11-04

### Changed

- All errors have been reworked to include more context on the error `code` and `issue`. Now errors will have the following structure (example):

```elixir
%Zoi.Error{
  code: :invalid_type,
  issue: {"invalid type: expected string", [expected: :string]},
  message: "invalid type: expected string",
  path: [:user, :name]
}
```

And it's also possible to have errors with dynamic messages:

```elixir
%Zoi.Error{
  code: :invalid_literal,
  message: "invalid literal: expected true",
  issue: {"invalid literal: expected %{expected}", [expected: true]},
  path: []
}
```

This will give more flexibility when handling errors programmatically, and better support with tools such as `Gettext` for localization.

- Removed `Zoi.gt/3` and `Zoi.lt/3` refinements for strings. Use `Zoi.min/3` and `Zoi.max/3` instead.
- Allow all refinements to accept custom error messages.
- `Zoi.url/2` now uses elixir's built-in `URI.parse/1` for URL validation.

## 0.8.4 - 2025-11-01

### Changed

- Fix nested `Zoi.keyword/2` error when parsing invalid values
- Fix `Zoi.Describe` when dealing with `Decimal` optional dependency

## 0.8.3 - 2025-10-31

### Added

- All types now implements the `Inspect` protocol. This should improve the ergonomics when working with Zoi types in IEx or when inspecting/debugging it's types.

## 0.8.2 - 2025-10-30

### Added

- `Zoi.non_negative/2` refinement for numbers to accept values from 0 and above
- `Zoi.describe/1` returns a structured documentation for keyword and object types

### Changed

- `Zoi.keyword/2` now can accept a schema in the first argument to validate the values of the keyword list
- `Zoi.keyword/2` type_spec now reflects correctly the keyword list definition

## 0.8.1 - 2025-10-27

### Changed

- Update readme with new metadata examples and reference to main api

## 0.8.0 - 2025-10-26

### Added

- `Zoi.nullish/2` type to accept `nil` or a value of a specific type
- `@spec` for all public functions
- `@typedoc` for all public types
- `Zoi.description/1` option to add description metadata to types for documentation purposes
- `Zoi.example/1` option to add example metadata to types for documentation purposes

### Changed

- `Zoi.to_json_schema/1` now reads `description`, `example` opts from types to include them in the generated JSON Schema

## 0.7.4 - 2025-10-25

### Changed

- `Zoi.regex/3` fix regex compilation, now the `regex.opts` are properly handled

## 0.7.3 - 2025-10-20

### Added

- `Zoi.email/1` now accepts `pattern` option to customize the email regex

### Changed

- `Zoi.enum/2` now accepts `coerce` option to coerce values to the key or to the value

## 0.7.2 - 2025-10-13

### Added

- Fixed example in `guides/using_zoi_to_generate_openapi_specs.md`

## 0.7.1 - 2025-10-12

### Added

- `Zoi.to_json_schema/1` support for metadata (e.g., example, description)
- `guides/quickstart_guide.md` added to the documentation

## 0.7.0 - 2025-10-10

### Added

- `Zoi.to_json_schema/1` function to convert `Zoi` schemas to JSON Schema format

### Changed

- `Zoi.array/2` fixed path in errors when parsing arrays
- `Zoi.regex/2` fixed regex compile errors when used in module attributes

## 0.6.6 - 2025-10-08

### Added

- `Zoi.metadata/1` - option to add metadata to types for documentation purposes

### Changed

- `Zoi.example/1` deprecated in favor of `Zoi.metadata/1`

## 0.6.5 - 2025-10-07

### Added

- `Zoi.example/1` option to add example values to types for documentation and testing purposes

## 0.6.4 - 2025-09-30

### Added

- `Zoi.downcase/1` refinement to validate if a string is in lowercase
- `Zoi.upcase/1` refinement to validate if a string is in uppercase
- `Zoi.hex/1` refinement to validate if a string is a valid hexadecimal

## 0.6.3 - 2025-09-27

### Added

- `keys` in `Zoi.object/2` data structure
- `Zoi.struct/2` type to parse structs and maps into structs
- `Zoi.Struct` module with helper functions to work with structs. This module offers two main functions:
  - `Zoi.Struct.enforce_keys/1`: List of keys that must be present in the struct
  - `Zoi.Struct.struct_keys/1`: List of keys and their default values to be used with `defstruct`

## 0.6.2 - 2025-09-26

### Added

- `Zoi.literal/2` type to accept only a specific literal value

### Changed

- Refactor all errors to be generated on type creation instead of parsing time

## 0.6.1 - 2025-09-08

### Added

- `Zoi.null/1` type to accept only `nil` values
- `Zoi.positive/1` refinement for numbers to accept only positive values
- `Zoi.negative/1` refinement for numbers to accept only negative values

## 0.6.0 - 2025-09-07

### Added

- `Zoi.required/2` type to enforce presence of a value in `keyword` and `object` types

### Changed

- `Zoi.object/2` now uses `mfa` to call inner `transform` function
- `Zoi.keyword/2` have all fields set as optional by default, use `Zoi.required/2` to enforce presence of a value

## 0.5.7 - 2025-09-06

### Changed

- `Zoi.parse!/3` Error message

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
