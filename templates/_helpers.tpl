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
{{- $args := . -}}
{{- $prefix := "" -}}
{{- $value := dict -}}

{{- if kindIs "slice" $args -}}
  {{- $parent := index $args 0 -}}
  {{- $key := index $args 1 -}}
  {{- if hasKey $parent $key -}}
    {{- $prefix = include "util.toSSCase" $key -}}
    {{- $value = get $parent $key -}}
  {{- else -}}
    {{- $prefix = $key -}}
    {{- $value = $parent -}}
  {{- end -}}
{{- else if kindIs "map" $args -}}
  {{- $value = $args -}}
{{- end -}}

{{- if $value -}}
  {{- if and (kindIs "map" $value) (not (hasKey $value "valueFrom")) -}}
    {{- range $k, $v := $value }}
{{- $name := (printf "%s_%s" $prefix (include "util.toSSCase" $k)) | trimPrefix "_" }}
{{- if and (kindIs "map" $v) (hasKey $v "valueFrom") }}
- name: {{ $name }}
  valueFrom:{{ toYaml (get $v "valueFrom") | nindent 2 | indent 2 }}
{{- else }}
- name: {{ $name }}
  value: {{ quote $v }}
{{- end }}
    {{- end }}
  {{- else }}
    {{- $name := include "util.toSSCase" $prefix -}}
    {{- if and (kindIs "map" $value) (hasKey $value "valueFrom") -}}
- name: {{ $name }}
  valueFrom:{{ toYaml (get $value "valueFrom") | nindent 2 | indent 2 }}
    {{- else -}}
- name: {{ $name }}
  value: {{ quote $value }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end -}}


