# _util.tpl

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
- Supports scalar, valueFrom, list and map targets
  - scalars (string, bool, number) become quoted values
  - list and maps generate multiple entries
  - valueFrom entries are rendered properly
  - supports mixed scalar/valueFrom maps
  - light typechecking on valueFrom (only check they have a single subkey)

- Silently skips:
  - undefined and missing keys
  - container subkeys except valueFrom (it's not recursive)
  - malformed valueFrom entries

- Uses util.SSCase internally, refer to that template for conversion rules
*/}}


{{- define "util.leafKind" -}}
{{- $scalars := list "string" "bool" "int" "float64" -}}
{{- $kind := kindOf . -}}
{{- if has $kind $scalars -}}
{{- $kind -}}
{{- else if and (eq $kind "map") (eq (len (keys .)) 1) (hasKey . "valueFrom") -}}
valueFrom
{{- end -}}
{{- end -}}

{{- define "util.toEnv" -}}
{{- $target := . -}}
{{- $prefix := "" -}}

{{/* check edge case of accidentally passing a value that looks like this? */}}
{{- if and (kindIs "slice" .) (eq (len .) 2) (kindIs "string" (last .)) -}}
  {{- $target = first . -}}
  {{- $prefix = last . -}}

  {{- if kindIs "map" $target -}}
    {{- $target = or (get $target $prefix) $target -}}
  {{- end -}}
{{- end -}}


{{- if not (kindIs "invalid" $target) -}}
  {{- $targetIsSlice := kindIs "slice" $target -}}

  {{- range $k, $v := empty (include "util.leafKind" $target) | ternary $target (dict "" $target) -}}
    {{- if $targetIsSlice -}}
        {{- $k = first (keys $v) -}}
        {{- $v = get $v $k -}}
    {{- end -}}

    {{- $leafKind := include "util.leafKind" $v -}}
    {{- if $leafKind -}}
- name: {{ (printf "%s_%s" $prefix $k) | include "util.SSCase" | default "_" }}
      {{- eq $leafKind "valueFrom" | ternary
          (printf "%s\n" (toYaml $v | nindent 2))
          (printf "\n  value: %s\n" (quote $v))
      -}}
    {{- end -}}
  {{ end }}
{{- end -}}
{{- end -}}
