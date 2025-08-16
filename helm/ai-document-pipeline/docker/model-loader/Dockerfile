# Model loader image with curl and jq
FROM registry.access.redhat.com/ubi8/ubi:latest

# Install required tools
RUN yum install -y curl jq && \
    yum clean all && \
    rm -rf /var/cache/yum

# Create non-root user
RUN useradd -u 1001 -g 0 -M -s /bin/bash loader

# Run as non-root user for security
USER 1001

# Default command
CMD ["/bin/bash"]
