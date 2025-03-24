{{/*
Description
  Formats a string into SCREAMING_SNAKE_CASE

Usage
  {{ include "helpers.cCToSs" camelString }}

Behaviors:
- converts camelCase, PascalCase and snake_case to SCREAMING_SNAKE_CASE
- preserves underscores (without duplication), and numbers
*/}}
{{- define "util.toSSCase" -}}
{{- $name := . -}}
{{- $snake := regexReplaceAll "([a-z0-9])([A-Z])" $name "${1}_${2}" -}}
{{- upper $snake -}}
{{- end -}}

{{/*
Description
  Formats single or nested values into lists of Kubernetes environment variables

Usage
- Format a key
  {{ include "helpers.toEnv" someKey }}
- Format key ("auto-prefix")
  {{ include "helpers.toEnv" (list parentKey "existingChildKey") }}
- Format key (custom prefix)
  {{ include "helpers.toEnv" (list parentKey "nonExistingChildKey") }}

Behaviors
- supports scalars and maps
  - scalars (string, bool, number) become quoted values
  - maps generate multiple env var entries
  - keys containing valueFrom are rendered properly
- supports mixed scalar and valueFrom maps
- skips undefined or missing keys silently
- uses toSSCase internally, refer to that template for conversion rules

Prefixing behavior
- with one argument, keys are mapped one to one to variable names
- a second argument will be used as prefix for the names
- if the second argument exists as a key in the parent, that key is processed
  else the parent itself is processed
*/}}
{{- define "util.toEnv" -}}
{{- $prefix := "" -}}
{{- $target := dict -}}

{{- if kindIs "slice" . -}}
  {{- $parent := index . 0 -}}
  {{- $key := index . 1 -}}

  {{- $prefix = (printf "%s_" (include "util.toSSCase" $key)) }}
  {{- $target = ((hasKey $parent $key) | ternary (get $parent $key) ($parent)) -}}
{{- else if kindIs "map" . -}}
  {{- $target = . -}}
{{- end -}}

{{- if $target -}}
  {{- $target = ((and (kindIs "map" $target) (not (hasKey $target "valueFrom"))) | ternary $target (set (dict) "" $target) ) -}}
  {{ range $k, $v := $target }}- name: {{ (eq $k "") | ternary (trimSuffix "_" $prefix) (printf "%s%s" $prefix (include "util.toSSCase" $k)) }}
      {{- (and (kindIs "map" $v) (hasKey $v "valueFrom")) | ternary
          (printf "%s\n" (toYaml $v | nindent 2))
          (printf "\n  value: %s\n" (quote $v))
      -}}
  {{ end }}
{{- end -}}
{{- end -}}
