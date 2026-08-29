# syntax=docker/dockerfile:1.7
# Keep PostgreSQL on the supported 16/bookworm line for reproducible demos.
FROM postgres:16-bookworm

# Initialization is performed by the standard image entrypoint. The database
# remains intentionally ephemeral in ACI through an emptyDir volume.
