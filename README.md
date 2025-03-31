# Helm template utilities

Reusable helper templates for Kubernetes manifests



---

## About

> This section explains the **terminology** we use to for data structures and how the template code deals with **type errors**. Feel free to [`skip directly to the helper reference`](#templates) and come back later as needed.



### Terminology

This library contains helpers that simplify common tasks in Helm templating. 

While all the code operates on YAML data, it focus on [**Helm Objects**](https://helm.sh/docs/chart_template_guide/builtin_objects/) (most frequently [Values](https://helm.sh/docs/chart_template_guide/values_files/)) - which are YAML trees of key/value mappings represented in Go -and thus Helm- as string-keyed maps. In other words: `map[string]interface{}`.

To disambiguate these and other entities with similar but not-quite-exactly-equal semantics across the different environments related to Helm, we'll strive for consistency in the words used throughout code and documentation:

| [helm-template-utils](https://github.com/3coma3/helm-template-utils) |                   [Helm](https://helm.sh)                    |      [Sprig](https://masterminds.github.io/sprig)      | [Go text/template](https://pkg.go.dev/text/template) |             [YAML](https://yaml.org/spec/1.2.2)              |     [JSON](https://www.rfc-editor.org/rfc/rfc8259.html)      |
| :----------------------------------------------------------: | :----------------------------------------------------------: | :----------------------------------------------------: | :--------------------------------------------------: | :----------------------------------------------------------: | :----------------------------------------------------------: |
|                          **value**                           |                            value                             |                         value                          |                        value                         |                            Value                             | [Value](https://www.rfc-editor.org/rfc/rfc8259.html#section-3) |
|                          **scalar**                          | **[scalar](https://helm.sh/docs/chart_template_guide/yaml_techniques/#scalar-types-in-yaml)** |                         scalar                         |                        scalar                        |        [Scalar](https://yaml.org/spec/1.2.2/#scalars)        |                            Scalar                            |
|                           **map**                            | **[map](https://helm.sh/docs/chart_template_guide/data_types/)** | [dict](https://masterminds.github.io/sprig/dicts.html) |                     struct, map                      |       [Mapping](https://yaml.org/spec/1.2.2/#mapping)        | [Object](https://www.rfc-editor.org/rfc/rfc8259.html#section-4) |
|                       **(map) member**                       |                      **key/value pair**                      |                     key/value pair                     |                    field, element                    |      Mapping [node](https://yaml.org/spec/1.2.2/#nodes)      |                            Member                            |
|                           **list**                           | **[list](https://helm.sh/docs/chart_template_guide/function_list/#lists-and-list-functions)**, [slice](https://helm.sh/docs/chart_template_guide/data_types/) | [list](https://masterminds.github.io/sprig/lists.html) |                        slice                         | [Block Sequence](https://yaml.org/spec/1.2.2/#block-sequences) | [Array](https://www.rfc-editor.org/rfc/rfc8259.html#section-5) |
|                       **(list) item**                        |                           **item**                           |                          item                          |                       element                        |  Block Sequence [node](https://yaml.org/spec/1.2.2/#nodes)   |                           Element                            |

- With **list** we refer to **Helm lists** (which are referred to also as slices in Helm's documentation)
- With **map** we refer to **Helm maps**
- With **key** we refer to the **key** in a **Helm key/value pair**

- With **value** we refer to the universal idea of a value, but often to the **value** in a **Helm key/value pair**



### Error handling

The takeaway:

*"not all valid YAML is valid Helm Values, and not all valid Helm Values are valid Kubernetes manifest data"*

Examples:

```yaml
---
# ✅ YAML: parses this as a single scalar value (string)
# ❌ Helm: the root node has to be a map
# ❓ K8S: can't be a whole manifest, but it can appear as data
"hello from root node"

---
# ❌ YAML: if the root node is a scalar, that's all the data the document will have 
# ❌ Helm: can't parse invalid YAML
# ❌ K8S: same as Helm
"hello from root"
"two root nodes? no way!"

---
# ✅ YAML: the root node can be a Scalar, Sequence or Mapping
# ❌ Helm: the root node has to be an explicit map
# ❓ K8S: can't be a whole manifest, but it can appear as data
- 1
  2
  3

---
# ✅ YAML ✅ Helm ✅ Kubernetes
# Scalar value in Helm (keyed, this is a Go map)
# { key: "configurationKey1", value: true }
configurationKey1: true

---
# ✅ YAML ✅ Helm ✅ Kubernetes
# Nested map, (top-level map with the value being a map itself)
# { key: "aMap", value: { "subKey1": "a string", "subKey2": 42 } }
aMap:
  subKey1: "a string"
  subKey2: 42

---
# ✅ YAML ✅ Helm ❌ Kubernetes
# Mixed list, (top-level map with the value being a list with one map entry and one plain string)
# { key: "aList", value: [ { "subKey1": "a string" }, "other string" ] }
aList:
  - subKey1: "a string"
  - "other string"
```

We see that some values that are valid YAML won’t work as Helm values. In addition, some values that are valid in YAML and Helm **may still be considered invalid or unsupported by this library** when generating content for Kubernetes manifests.

For example, if you filter the last YAML document above into [`toEnv`](#-utiltoenv), the plain string will be ignored, because it lacks a key and cannot be mapped to a valid `EnvVar`. Keep this in mind to avoid surprises.

In future expansions, optional levels of strictness might be added that would have some helpers work more as lightweight static checkers, to help with debugging or enforcing guarantees on the input. In the current state the code is intended to "just work" with common real-world input, and behaves more like a filter than a checker, skipping over data that it can't validate.



---

## Templates

### 📦 `util.SSCase`

Normalizes strings into SCREAMING_SNAKE_CASE (useful for `EnvVar` name formatting)

#### Usage

```yaml
{{ include "util.SSCase" string }}
```

#### Behaviors

- Converts all non-alphanumeric characters to underscores (`_`)
- Deduplicates and trims leading and trailing underscores
- Filters the result through `snakecase` and `uppercase`




### 📦 `util.toEnv`

Maps values to Kubernetes `EnvVar` fields

#### Usage

```yaml
# Process target values, no prefix is added to variable names
{{ include "util.toEnv" targetKey }}

# Process target values and add a custom prefix to variable names
{{ include "util.toEnv" (list targetKey "custom prefix") }}

# Process target values and use target key as prefix 
{{ include "util.toEnv" (list targetParentKey "targetSubkey") }}
```

#### Behaviors

##### Accepted target values

|              Target values               |                           Outcome                            |
| :--------------------------------------: | :----------------------------------------------------------: |
|                  scalar                  |                  renders one  `EnvVar` item                  |
|                   map                    |             renders one `EnvVar` item per member             |
|                   list                   |          renders one `EnvVar` item per target item           |
|                valueFrom                 | type checked via [`util.leafKind`](#-utilleafkind) and rendered as one item |
|         undefined or nil targets         |                       silently ignored                       |
|    list items other than 1-member map    |                       silently ignored                       |
|         improper valueFrom maps          |                       silently ignored                       |
| nested lists and maps (except valueFrom) |                       silently ignored                       |

##### Optional prefixing for generated variable names

- A second `string` argument becomes a prefix for the generated names
- If the prefix exists as a member key in the target map, that member becomes the target for processing. This is a shorthand notation to avoid passing the same key twice when wanting to use it as the prefix.

##### Name and prefix normalization

- Uses [`util.SSCase`](#-utilsscase) for name and prefix formatting

#### Example use

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

More examples can be found in the [`test chart`](tests/) in this repo.

#### Future enhancements

- configurable strictness (enable extra [`leafKind`](#-utilleafkind) typechecks, exit on undefined or malformed entries, etc)
- regex filters for keys or values




### 📦 `util.leafKind`

This is used as a [`toEnv`](#-utiltoenv) helper that checks the kind of its context and returns it as string for *leaf* values (scalars and `valueFrom`), or `nil` otherwise

#### Usage

```yaml
# use as a predicate
{{ if include "util.leafKind" target }} ...

# use as a predicate and save the result in a single pass
{{ if $kind := include "util.leafKind" target }} ...
```

#### Behaviors

- A scalar ( `bool`, `int`, `int64` ,`float64` or `string`) will render its kind
- A *well-formed* `valueFrom` will render the string `"valueFrom"`

"Well-formed" means for now a trivial check that we have a map with a single `valueFrom` member, no comprehensive guarantees are issued.

#### Future enhancements

- optional extra checks on `valueFrom`




### 📦 `util.isKeyValue`

A simple predicate testing for maps with a single member

#### Usage

```yaml
{{ if include "util.isKeyValue" target }} ...
```

#### Behaviors

- Renders `"true"` if the input is a map with exactly one key, otherwise it renders nothing



---

## Testing

The templates and assertions in the [`test chart`](tests/) should cover every possible case, but if you spot omissions be welcome to open an issue about it.

Run the test template with:

```bash
make test
```
To run the [helm-unittest](https://github.com/helm-unittest/helm-unittest) templates, install that plugin and run:
```bash
make unittest
```