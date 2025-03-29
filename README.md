# Helm template utilities

Reusable helper templates for Kubernetes manifests



---

## Templates

### 📦 `util.SSCase`

**Description**

Normalizes strings into SCREAMING_SNAKE_CASE (useful for `EnvVar` name formatting)

**Usage**

```yaml
{{ include "util.SSCase" string }}
```

**Behaviors**

- Converts all non-alphanumeric characters to underscores (`_`)
- Deduplicates and trims leading and trailing underscores
- Filters the result through `snakecase` and `uppercase`




### 📦 `util.toEnv`

**Description**

Maps values to Kubernetes `EnvVar` fields

**Usage**

```yaml
# Format a key, no prefix is added to variable names
{{ include "util.toEnv" target }}

# Format a key and add a custom prefix to variable names
{{ include "util.toEnv" (list target "custom prefix") }}

# Format a key and use its name as prefix 
{{ include "util.toEnv" (list target "targetSubkey") }}
```

**Behaviors**

- Supports scalar, valueFrom, list and map targets:
  - scalars become single values
  - list and maps generate multiple entries
  - valueFrom entries are rendered properly
  - light typechecking on valueFrom (only check they have a single subkey)
  - supports collections with mixed scalar/valueFrom entries
- Silently filters out:
  - undefined and missing keys
  - container subkeys except valueFrom (it's not recursive)
  - malformed valueFrom entries

- Optional prefixing for generated variable names:
  - A second argument will always be used as the prefix
  - If the prefix exists as a subkey in the target, it will *become* the target for processing
- Uses [`util.SSCase`](#utilsscase) for name and prefix formatting

**Future enhancements**

- configurable strictness
- extra/optional typechecks on valueFrom
- regex filters for keys or values




### 📦 `util.leafKind`

**Description** 

This is used as a `toEnv`  helper that checks the kind of its context and returns it as string for *leaf* values (scalars and `valueFrom`), or nil otherwise.

- A scalar ( `bool`, `int`, `int64` ,`float64` or `string`) will render its kind
- A *well-formed* `valueFrom` will render the string "valueFrom"

"Well-formed" means for now a trivial check that we have a map with a single subkey named "valueFrom", no comprehensive guarantees are issued.



---

## Testing and examples

See the test chart in `test/` for examples. The assertions should cover every possible case, but if you spot omissions, be welcome to open an issue about it.

Run the test template with:

```bash
make test
```
Run the helm-unittest templates with:
```bash
make unittest
```
