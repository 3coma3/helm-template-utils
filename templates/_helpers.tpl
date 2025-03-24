{{/*
Description
  Normalizes strings into SCREAMING_SNAKE_CASE

Usage
  {{ include "helpers.SSCase" string }}

Supported conventions:
- camelCase, PascalCase, SCREAMING-KEBAB, Train-Case, camel.Snake.Dot,
  snake_case, camel_Snake, kebab-case, mixedCASEValue, snake_case

Behaviors
- converts non-alphanumeric, non underscore characters to underscores
- deduplicates underscores
- non alphanumeric delimiters have priority
*/}}
{{- define "util.SSCase" -}}
{{- $snake := regexReplaceAll "[^a-zA-Z0-9]" . "_" -}}
{{- $snake = regexReplaceAll "_+" $snake "_" -}}
{{- regexReplaceAll "([a-z0-9])([A-Z])" $snake "${1}_${2}" | upper -}}
{{- end -}}

{{/*
Description
  Formats single or nested values into lists of Kubernetes environment variables

Usage
- Format a key, no prefix is added to variable names
  {{ include "helpers.toEnv" someKey }}

- Format a key and add a custom prefix
  {{ include "helpers.toEnv" (list someKey "prefix") }}

- Format a subkey and use it as prefix
  {{ include "helpers.toEnv" (list parentKey "targetSubKey") }}

Behaviors
- supports scalars and maps for keys
  - scalars (string, bool, number) become quoted values
  - maps generate multiple entries
  - keys containing valueFrom are rendered properly
- supports mixed scalar and valueFrom maps
- silently skips:
  - undefined and missing keys
  - undefined, missing and non scalar subkeys (except valueFrom)
- uses util.SSCase internally, refer to that template for conversion rules
*/}}
{{- define "util.toEnv" -}}
{{- $target := dict -}}
{{- $prefix := "" -}}
{{- if kindIs "slice" . -}}
  {{- $parent := index . 0 -}}
  {{- $key := index . 1 -}}
  {{- $target = ((hasKey $parent $key) | ternary (get $parent $key) ($parent)) -}}
  {{- $prefix = (printf "%s_" (include "util.SSCase" $key)) }}
{{- else if kindIs "map" . -}}
  {{- $target = . -}}
{{- end -}}

{{- if $target -}}
  {{- $target = ((and (kindIs "map" $target) (not (hasKey $target "valueFrom"))) | ternary $target (set (dict) "" $target) ) -}}
  {{ range $k, $v := $target }}
    {{- if or (not (kindIs "map" $v)) (hasKey $v "valueFrom") -}}
- name: {{ (eq $k "") | ternary (trimSuffix "_" $prefix) (printf "%s%s" $prefix (include "util.SSCase" $k)) }}
      {{- (and (kindIs "map" $v) (hasKey $v "valueFrom")) | ternary
          (printf "%s\n" (toYaml $v | nindent 2))
          (printf "\n  value: %s\n" (quote $v))
      -}}
    {{- end -}}
  {{ end }}
{{- end -}}
{{- end -}}
