{{/*
Description
  Normalizes strings into SCREAMING_SNAKE_CASE

Usage
  {{ include "util.SSCase" string }}

Behaviors
- converts non-alphanumeric to (deduplicated) underscores
- filters through snakecase | upper
*/}}
{{- define "util.SSCase" -}}
{{- $normalize := regexReplaceAll "[^[:alnum:]]" . "_" -}}
{{- $normalize = regexReplaceAll "_+" $normalize "_" }}
{{- trimAll "_" $normalize | snakecase | upper -}}
{{- end -}}

{{/*
Description
  Maps values to Kubernetes EnvVar fields

Usage
- Format a key, no prefix is added to variable names
  {{ include "util.toEnv" targetKey }}

- Format a key and add a custom prefix to variable names
  {{ include "util.toEnv" (list targetKey "prefix") }}

- Format a key and use its name as prefix
  {{ include "util.toEnv" (list parentKey "targetSubkey") }}

Behaviors
- Supports scalar and map targets
  - scalars (string, bool, number) become quoted values
  - maps generate multiple entries
  - entries containing valueFrom are rendered properly
  - supports mixed scalar/valueFrom maps

- Silently skips:
  - undefined and missing keys
  - types other than scalars and maps
  - mapped subkeys except valueFrom (it's not recursive)

- Uses util.SSCase internally, refer to that template for conversion rules
*/}}
{{- define "util.toEnv" -}}
{{- $target := . -}}
{{- $prefix := "" -}}

{{/* check edge case of passing a single argument pointing to a list of two
elements where the first contains the second as a subkey?
maybe not worth it and leave it as "feature" */}}

{{- if (and (kindIs "slice" $target) (eq (len $target) 2)) -}}

  {{/* determine target and prefix from argument */}}
  {{- $parent := index $target 0 -}}
  {{- $key := index $target 1 -}}
  {{- if and (kindIs "map" $parent) (hasKey $parent $key) -}}
    {{- $target = (get $parent $key) -}}
  {{- else -}}
    {{- $target = $parent -}}
  {{- end -}}
  {{- $prefix = (printf "%s_" (include "util.SSCase" $key)) }}
{{- end -}}

{{- if $target -}}
  {{- $scalars := list "string" "bool" "int" "float64" -}}

  {{- if or (has (kindOf $target) $scalars) (and (kindIs "map" $target) (eq (len (keys $target)) 1) (hasKey $target "valueFrom")) -}}
    {{- $target = set (dict) "" $target -}}
  {{- end -}}

  {{ range $k, $v := $target -}}
    {{- if kindIs "slice" $target -}}
        {{- $k = index (keys $v) 0 -}}
        {{- $v = get $v $k -}}
    {{- end -}}

    {{- $kind := kindOf $v -}}

    {{- if or (has $kind $scalars) (and (eq $kind "map") (eq (len (keys $v)) 1) (hasKey $v "valueFrom")) -}}

- name: {{ (eq $k "") | ternary (trimSuffix "_" $prefix | default "_") (printf "%s%s" $prefix (include "util.SSCase" $k)) }}
      {{- and (eq $kind "map") (hasKey $v "valueFrom") | ternary
          (printf "%s\n" (toYaml $v | nindent 2))
          (printf "\n  value: %s\n" (quote $v))
      -}}
    {{- end -}}
  {{ end }}
{{- end -}}
{{- end -}}
