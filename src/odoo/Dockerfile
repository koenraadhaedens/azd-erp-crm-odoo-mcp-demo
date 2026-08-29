# syntax=docker/dockerfile:1.7
# Mirror this pinned base into acrdefcontainer.azurecr.io/odoo.
FROM odoo:18.0

# The stock image contains bash, Python, and the odoo CLI required by the
# ACI bootstrap and web-container commands. Add custom modules under
# /mnt/extra-addons in this build context when the demo needs them.
USER root

COPY --chmod=0755 run-with-bootstrap-volume.sh /usr/local/bin/run-with-bootstrap-volume

# The wrapper fixes ownership of the mounted emptyDir and then drops privileges
# to the stock image's non-root Odoo account before starting the application.
ENTRYPOINT ["/usr/local/bin/run-with-bootstrap-volume"]
CMD ["odoo"]
