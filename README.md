# Helm template utilities

Reusable helper templates for Kubernetes manifests

---

## About

This library aims to simplify common tasks in Helm templating. While all the code operates on YAML data, most is specialized in working with **Helm Values**, which are expected to follow a certain YAML structure: a tree of key/values represented in Go (and thus Helm) as string-keyed maps, in other words: `map[string]interface{}`.

In this sense, when talking about scalar, list or map *values* in the context of this library, we mean the *value* part in a *key/value node* in the Helm Values Tree.

Take this `values.yaml` for example:

```yaml
# ❌ Valid YAML but not valid Helm values
# YAML: a plain scalar string
# Helm: error – expected a top-level map
"hello world"

# ✅ Typical scalar value in Helm (keyed)
# { key: "configurationKey1", value: true }
configurationKey1: true

# ✅ Nested map
# { key: "aMap", value: { "subKey1": "a string", "subKey2": 42 } }
aMap:
  subKey1: "a string"
  subKey2: 42

# ✅ Mixed list
# { key: "aList", value: [ { "subKey1": "a string" }, "other string" ] }
aList:
  - subKey1: "a string"
  - "other string"
```

We can see that while some YAML constructs like "top-level scalars" or lists of primitives could technically be valid YAML, they **don’t make practical sense in Helm values**, which are expected to be dictionaries or lists of dictionaries. The code by default will be forgiving and **silently ignore** entries that are not compatible (e.g., scalars when a map is expected, or malformed `valueFrom` entries). Keep this in mind to avoid surprises.

In future expansions, optional levels of strictness could be added that would make the library work more as a lightweight type checker to help with debugging or enforcing proper value structures. In the meantime, this library aims to "just work" with common real-world inputs.

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

- Accepts the following values:
  - scalars → generate a single `value` entry
  - maps → generate one `EnvVar` per key
  - lists *→* generate one `EnvVar` per entry
  - `valueFrom` *→* rendered properly and type checked via [`util.leafKind`](#-utilleafkind)
- Silently ignores:
  - undefined or `nil` targets
  - nested lists and maps, except proper `valueFrom` (ie: it's not recursive)
  - improper `valueFrom` maps
  - list entries that are not dicts (key/value maps)
- Optional prefixing for generated variable names:
  - a second `string` argument becomes a prefix for the generated names
  - if the prefix exists as a subkey in a target map, it is processed instead
- Uses [`util.SSCase`](#-utilsscase) for name and prefix formatting

**Example**

Input values:

```yaml
database:
  host: localhost
  port: 5432
```

Include:

```yaml
env: {{ include "util.toEnv" (list .Values.database "DB config") }}
```

Rendered output:

```yaml
- name: DB_CONFIG_HOST
  value: "localhost"
- name: DB_CONFIG_PORT
  value: "5432"
```

More examples can be found in the [`test chart`](test/) in this repo.

**Future enhancements**

- configurable strictness (enable extra leafKind typechecks, exit on undefined/malformed entries, etc)
- regex filters for keys or values




### 📦 `util.leafKind`

**Description** 

This is used as a [`toEnv`](#-utiltoenv) helper that checks the kind of its context and returns it as string for *leaf* values (scalars and `valueFrom`), or `nil` otherwise

**Usage**

```yaml
# use as a predicate
{{ if include "util.leafKind" target }} ...

# use as a predicate and save the result in a single pass
{{ if $kind := include "util.leafKind" target }} ...
```

**Behaviors**

- A scalar ( `bool`, `int`, `int64` ,`float64` or `string`) will render its kind
- A *well-formed* `valueFrom` will render the string "valueFrom"

"Well-formed" means for now a trivial check that we have a map with a single subkey named "valueFrom", no comprehensive guarantees are issued.

**Future enhancements**

- optional extra typechecking on valueFrom




### 📦 `util.isKeyValue`

**Description** 

A simple predicate testing for maps with a single key (a dict)

**Usage**

```yaml
{{ if include "util.isKeyValue" target }} ...
```

**Behaviors**

- Renders `"true"` if the input is a map with exactly one key, otherwise it renders nothing



---

## Testing

The templates and assertions in the [`test chart`](test/) should cover every possible case, but if you spot omissions, be welcome to open an issue about it.

Run the test template with:

```bash
make test
```
To run the [helm-unittest](https://github.com/helm-unittest/helm-unittest) templates, install that plugin and run:
```bash
make unittest
```
