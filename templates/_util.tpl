# _util.tpl
{{- define "util.SSCase" -}}
{{- $normalize := regexReplaceAll "[^[:alnum:]]" . "_" -}}
{{- $normalize = regexReplaceAll "_+" $normalize "_" }}
{{- trimAll "_" $normalize | snakecase | upper -}}
{{- end -}}

{{- define "util.leafKind" -}}
{{- $scalars := list "bool" "int" "int64" "float64" "string" -}}
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

  {{- range $k, $v := or (and (empty (include "util.leafKind" $target)) $target) (dict "" $target) -}}
    {{- if $targetIsSlice -}}
        {{- $k = first (keys $v) -}}
        {{- $v = get $v $k -}}
    {{- end -}}

    {{- if $leafKind := include "util.leafKind" $v -}}
- name: {{ or (cat $prefix "_" $k | include "util.SSCase") "_" }}
      {{- if eq $leafKind "valueFrom" -}}
        {{- printf "%s\n" (toYaml $v | nindent 2) -}}
      {{- else -}}
        {{- printf "\n  value: %#v\n" $v -}}
      {{- end -}}
    {{- end -}}
  {{ end }}
{{- end -}}
{{- end -}}
