{{/*
Construct the base name for all resources in this chart.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "airflow.fullname" -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
The version of airflow being deployed.
- extracted from the image tag (only for images in airflow's official DockerHub repo)
- always in `XX.XX.XX` format (ignores any pre-release suffixes)
- empty if no version can be extracted
*/}}
{{- define "airflow.image.version" -}}
{{- if eq .Values.airflow.image.repository "apache/airflow" -}}
{{- regexFind `^[0-9]+\.[0-9]+\.[0-9]+` .Values.airflow.image.tag -}}
{{- end -}}
{{- end -}}

{{/*
Construct the `labels.app` for used by all resources in this chart.
*/}}
{{- define "airflow.labels.app" -}}
{{- printf "%s" .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Construct the `labels.chart` for used by all resources in this chart.
*/}}
{{- define "airflow.labels.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Construct the name of the airflow ServiceAccount.
*/}}
{{- define "airflow.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- .Values.serviceAccount.name | default (include "airflow.fullname" .) -}}
{{- else -}}
{{- .Values.serviceAccount.name | default "default" -}}
{{- end -}}
{{- end -}}

{{/*
A flag indicating if a celery-like executor is selected (empty if false)
*/}}
{{- define "airflow.executor.celery_like" -}}
{{- if or (eq .Values.airflow.executor "CeleryExecutor") (eq .Values.airflow.executor "CeleryKubernetesExecutor") -}}
true
{{- end -}}
{{- end -}}

{{/*
A flag indicating if a kubernetes-like executor is selected (empty if false)
*/}}
{{- define "airflow.executor.kubernetes_like" -}}
{{- if or (eq .Values.airflow.executor "KubernetesExecutor") (eq .Values.airflow.executor "CeleryKubernetesExecutor") -}}
true
{{- end -}}
{{- end -}}

{{/*
The scheme (HTTP, HTTPS) used by the webserver.
NOTE: this is used in the liveness/readiness probes of the webserver
*/}}
{{- define "airflow.web.scheme" -}}
{{- if and (.Values.airflow.config.AIRFLOW__WEBSERVER__WEB_SERVER_SSL_CERT) (.Values.airflow.config.AIRFLOW__WEBSERVER__WEB_SERVER_SSL_KEY) -}}
HTTPS
{{- else -}}
HTTP
{{- end -}}
{{- end -}}

{{/*
The app protocol used by the webserver.
NOTE: this sets the `appProtocol` of the Service port (only important for Istio users)
*/}}
{{- define "airflow.web.appProtocol" -}}
{{- if and (.Values.airflow.config.AIRFLOW__WEBSERVER__WEB_SERVER_SSL_CERT) (.Values.airflow.config.AIRFLOW__WEBSERVER__WEB_SERVER_SSL_KEY) -}}
https
{{- else -}}
http
{{- end -}}
{{- end -}}

{{/*
The path containing DAG files
*/}}
{{- define "airflow.dags.path" -}}
{{- if .Values.dags.gitSync.enabled -}}
{{- printf "%s/repo/%s" (.Values.dags.path | trimSuffix "/") (.Values.dags.gitSync.repoSubPath | trimAll "/") -}}
{{- else if .Values.dags.s3Sync.enabled -}}
{{- printf "%s/repo/%s" (.Values.dags.path | trimSuffix "/") (.Values.dags.s3Sync.repoSubPath | trimAll "/") -}}
{{- else -}}
{{- printf .Values.dags.path -}}
{{- end -}}
{{- end -}}

{{/*
Helper template which checks if `logs.path` is stored under any of the passed `volumeMounts`.
EXAMPLE USAGE: {{ include "airflow._has_logs_path" (dict "Values" .Values "volume_mounts" .Values.xxxx.extraVolumeMounts) }}
*/}}
{{- define "airflow._has_logs_path" -}}
{{- $has_logs_path := false -}}
{{- /* loop over `.volume_mounts`, checking if `mountPath` is a prefix of `logs.path` */ -}}
{{- range .volume_mounts -}}
  {{- if .mountPath }}
    {{- if hasPrefix (clean .mountPath) (clean $.Values.logs.path) -}}
    {{- $has_logs_path = true -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if $has_logs_path -}}
true
{{- end -}}
{{- end -}}

{{/*
If `logs.path` is stored under any of the global `airflow.extraVolumeMounts` mounts.
*/}}
{{- define "airflow.extraVolumeMounts.has_log_path" -}}
{{- include "airflow._has_logs_path" (dict "Values" .Values "volume_mounts" .Values.airflow.extraVolumeMounts) -}}
{{- end -}}

{{/*
If `logs.path` is stored under any of the `scheduler.extraVolumeMounts` mounts.
*/}}
{{- define "airflow.scheduler.extraVolumeMounts.has_log_path" -}}
{{- include "airflow._has_logs_path" (dict "Values" .Values "volume_mounts" .Values.scheduler.extraVolumeMounts) -}}
{{- end -}}

{{/*
If `logs.path` is stored under any of the `workers.extraVolumeMounts` mounts.
*/}}
{{- define "airflow.workers.extraVolumeMounts.has_log_path" -}}
{{- include "airflow._has_logs_path" (dict "Values" .Values "volume_mounts" .Values.workers.extraVolumeMounts) -}}
{{- end -}}

{{/*
If the airflow triggerer should be used.
*/}}
{{- define "airflow.triggerer.should_use" -}}
{{- if .Values.triggerer.enabled -}}
{{- if not .Values.airflow.legacyCommands -}}
{{- if include "airflow.image.version" . -}}
{{- if semverCompare ">=2.2.0" (include "airflow.image.version" .) -}}
true
{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
If PgBouncer should be used.
*/}}
{{- define "airflow.pgbouncer.should_use" -}}
{{- if .Values.pgbouncer.enabled -}}
{{- if or (.Values.postgresql.enabled) (eq .Values.externalDatabase.type "postgres") -}}
true
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Construct the `postgresql.fullname` of the postgresql sub-chat chart.
Used to discover the Service and Secret name created by the sub-chart.
*/}}
{{- define "airflow.postgresql.fullname" -}}
{{- if .Values.postgresql.fullnameOverride -}}
{{- .Values.postgresql.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "postgresql" .Values.postgresql.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Construct the `redis.fullname` of the redis sub-chat chart.
Used to discover the master Service and Secret name created by the sub-chart.
*/}}
{{- define "airflow.redis.fullname" -}}
{{- if .Values.redis.fullnameOverride -}}
{{- .Values.redis.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "redis" .Values.redis.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}
