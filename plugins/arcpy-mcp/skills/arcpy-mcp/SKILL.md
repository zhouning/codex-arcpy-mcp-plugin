---
name: arcpy-mcp
description: Use the private Windows ArcPy MCP server for GIS inspection, vector and raster processing, map export, and allowlisted CPU deep-learning inference from macOS Codex. Trigger for ArcPy, ArcGIS Pro geoprocessing, GIS dataset inspection, or ArcGIS map export tasks.
---

# ArcPy MCP Workflow

Use the `arcpy` MCP server for ArcGIS Pro work that cannot run locally on macOS.

## Safety Rules

- Never send a Windows absolute path, drive path, UNC path, parent traversal, or symlink target.
- Never request arbitrary Python execution, arbitrary ArcPy callables, shell commands, or an unlisted tool ID.
- Never print, store, commit, summarize, or place `ARCPY_MCP_TOKEN` in a command argument.
- Never print or persist a signed upload or download URL beyond the active transfer command.
- Represent server inputs and outputs only with artifact IDs and artifact-relative paths.
- Do not claim that a job succeeded until `get_job` reports `succeeded`.
- Treat CPU deep-learning inference as long-running and warn the user before submission.

## Check The Connection

1. Call `health_check` before the first ArcPy operation in a thread.
2. Stop if the service status is not healthy or the worker is unavailable.
3. Call `get_capabilities` before work that depends on Spatial Analyst, Image Analyst, or deep learning.
4. Stop if the ArcGIS product or required extension reported by the worker cannot run the request.

## Upload Data

1. Package a multi-file dataset such as a shapefile or file geodatabase as a ZIP. Keep a single raster, model, PDF, or GeoPackage as one file.
2. Compute the local byte size with `stat -f%z` and SHA-256 with `shasum -a 256`.
3. Call `create_upload` with the logical name, exact size, lowercase SHA-256, and media type.
4. Send bytes to the returned HTTPS URL with `curl --request PUT`, `--data-binary`, and an `Upload-Offset` header. Start a new upload at offset `0`.
5. After interruption, call `get_upload_status`, resume at its `committed_size`, and call `renew_upload` if the signed URL expired.
6. Call `complete_upload`; do not use the artifact until its state is `ready` and its verified SHA-256 matches the local value.
7. Do not pass the Bearer Token to signed artifact upload or download URLs.

## Select A Tool

1. Run `inspect_dataset` for every new dataset and poll the returned job with `get_job`.
2. Prefer a dedicated MCP tool such as `buffer_features` or `calculate_slope` when it exactly matches the request.
3. Otherwise call `search_tools` with the intended operation.
4. Call `describe_tool` for the selected allowlisted tool ID and construct only schema-approved parameters.
5. Use only artifact-relative paths returned by inspection or paths known to be inside the uploaded artifact.

## Run A Job

1. Call `submit_job` for a catalog tool, or call the appropriate dedicated tool.
2. Keep the returned job ID in the active thread context only.
3. Poll `get_job` after 2, 5, 10, and then 20 seconds; keep later intervals at 20 seconds or less.
4. Treat `succeeded`, `failed`, `timed_out`, `cancelled`, and `interrupted` as terminal states.
5. If the user asks to stop, call `cancel_job` once, then poll until the job reaches a terminal state.
6. On failure, call `get_job_log` and report the stable error code plus the final sanitized ArcPy messages.

## Download Results

1. Read result artifact IDs only from a succeeded job response.
2. Call `create_download` for each result artifact.
3. Download with `curl --fail --location --continue-at -` and the returned signed HTTPS URL.
4. Verify the downloaded file against the artifact `actual_sha256` with `shasum -a 256` before extracting or opening it.
5. Keep ZIP extraction inside the current macOS workspace and reject archive paths that escape it.

## Deep Learning

- Current execution mode is CPU deep-learning because the Windows host exposes no usable NVIDIA device.
- Do not submit `TrainDeepLearningModel`; model training is not exposed.
- Require a compatible ArcGIS Pro 3.7.1 DLPK or EMD model artifact for inference.
- Use only the allowlisted `dl.detect_objects`, `dl.classify_pixels`, `dl.classify_objects`, or `dl.detect_change` tools.
- Use the timeout reported by `describe_tool`; avoid cancelling during final output writing unless the user requests it.
