# syntax=docker/dockerfile:1.3-labs
# Basded on Red Hat OpenShift Dev Spaces - Universal Developer Image https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz

# updateBaseImages.sh can't operate on SHA-based tags as they're not date-based or semver-sequential, and therefore cannot be ordered
FROM registry.access.redhat.com/ubi9/ubi:latest
LABEL maintainer="ahussey"

LABEL com.redhat.component="ubi"
LABEL name="ahussey/tekton-utils"
LABEL version="ubi9"

#label for EULA
LABEL com.redhat.license_terms="https://www.redhat.com/en/about/red-hat-end-user-license-agreements#UBI"

#labels for container catalog
LABEL summary="TekTon Utilities"
LABEL description="Container image with tools aimed to be used as part of TekTon workflows"
LABEL io.k8s.display-name="tekton-utils"
LABEL io.openshift.expose-services=""

USER 10001

# kube
ENV KUBECONFIG=/home/user/.kube/config

USER 0

# Define user directory for binaries
RUN mkdir -p /home/user/.local/bin && \
    chgrp -R 0 /home && chmod -R g=u /home
ENV PATH="/home/user/.local/bin:$PATH"

# Python
RUN dnf -y update && \
    dnf -y install python3.11 python3.11-devel python3.11-setuptools python3.11-pip nss_wrapper

RUN cd /usr/bin \
    && if [ ! -L python ]; then ln -s python3.11 python; fi \
    && if [ ! -L pydoc ]; then ln -s pydoc3.11 pydoc; fi \
    && if [ ! -L python-config ]; then ln -s python3.11-config python-config; fi \
    && if [ ! -L pip ]; then ln -s pip-3.11 pip; fi

RUN pip install pylint yq

# git completion
RUN echo "source /usr/share/bash-completion/completions/git" >> /home/user/.bashrc

# Cloud

# oc client and completion
ENV OC_VERSION=latest
RUN set -euxo pipefail && \
curl -L https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OC_VERSION}/openshift-client-linux.tar.gz | tar -C /usr/local/bin -xz && \
chmod +x /usr/local/bin/* && \
oc completion bash > /usr/share/bash-completion/completions/oc && \
echo "source /usr/share/bash-completion/completions/oc" >> /home/user/.bashrc

# Commented out, because container-roles is not currently available in RHEL9 via AppStream
# ## podman buildah skopeo
# RUN dnf -y module enable container-tools && \
#     dnf -y update && \
#     dnf -y reinstall shadow-utils && \
#     dnf -y install podman buildah skopeo fuse-overlayfs

# # Set up environment variables to note that this is
# # not starting with usernamespace and default to
# # isolate the filesystem with chroot.
# ENV _BUILDAH_STARTED_IN_USERNS="" BUILDAH_ISOLATION=chroot

# # Tweaks to make rootless buildah work
# RUN touch /etc/subgid /etc/subuid  && \
#     chmod g=u /etc/subgid /etc/subuid /etc/passwd  && \
#     echo user:10000:65536 > /etc/subuid  && \
#     echo user:10000:65536 > /etc/subgid

# # Adjust storage.conf to enable Fuse storage.
# RUN sed -i -e 's|^#mount_program|mount_program|g' -e '/additionalimage.*/a "/var/lib/shared",' /etc/containers/storage.conf
# RUN mkdir -p /var/lib/shared/overlay-images /var/lib/shared/overlay-layers; \
#     touch /var/lib/shared/overlay-images/images.lock; \
#     touch /var/lib/shared/overlay-layers/layers.lock

# # But use VFS since we were not able to make Fuse work yet...
# RUN mkdir -p "${HOME}"/.config/containers && \
#    (echo '[storage]';echo 'driver = "vfs"') > "${HOME}"/.config/containers/storage.conf

# # Install kubedock
# ENV KUBEDOCK_VERSION 0.13.0
# RUN curl -L https://github.com/joyrex2001/kubedock/releases/download/${KUBEDOCK_VERSION}/kubedock_${KUBEDOCK_VERSION}_linux_amd64.tar.gz | tar -C /usr/local/bin -xz \
#     && chmod +x /usr/local/bin/kubedock

# # Configure the podman wrapper
# COPY --chown=0:0 podman-wrapper.sh /usr/bin/podman.wrapper
# RUN mv /usr/bin/podman /usr/bin/podman.orig

## shellcheck
RUN set -euxo pipefail && \
dnf install -y xz && \
TEMP_DIR="$(mktemp -d)" && \
cd "${TEMP_DIR}" && \
SHELL_CHECK_VERSION="0.8.0" && \
SHELL_CHECK_ARCH="x86_64" && \
SHELL_CHECK_TGZ="shellcheck-v${SHELL_CHECK_VERSION}.linux.${SHELL_CHECK_ARCH}.tar.xz" && \
SHELL_CHECK_TGZ_URL="https://github.com/koalaman/shellcheck/releases/download/v${SHELL_CHECK_VERSION}/${SHELL_CHECK_TGZ}" && \
curl -sSLO "${SHELL_CHECK_TGZ_URL}" && \
tar -xvf "${SHELL_CHECK_TGZ}" && \
mv "${TEMP_DIR}"/shellcheck-v${SHELL_CHECK_VERSION}/shellcheck /bin/shellcheck && \
cd - && \
rm -rf "${TEMP_DIR}"

## helm
RUN set -euxo pipefail && \
TEMP_DIR="$(mktemp -d)" && \
cd "${TEMP_DIR}" && \
HELM_VERSION="3.7.0" && \
HELM_ARCH="linux-amd64" && \
HELM_TGZ="helm-v${HELM_VERSION}-${HELM_ARCH}.tar.gz" && \
HELM_TGZ_URL="https://get.helm.sh/${HELM_TGZ}" && \
curl -sSLO "${HELM_TGZ_URL}" && \
curl -sSLO "${HELM_TGZ_URL}.sha256sum" && \
sha256sum -c "${HELM_TGZ}.sha256sum" 2>&1 | grep OK && \
tar -zxvf "${HELM_TGZ}" && \
mv "${HELM_ARCH}"/helm /usr/local/bin/helm && \
cd - && \
rm -rf "${TEMP_DIR}"

## kustomize
RUN  set -euxo pipefail && \
TEMP_DIR="$(mktemp -d)" && \
cd "${TEMP_DIR}" && \
KUSTOMIZE_VERSION="5.1.1" && \
KUSTOMIZE_ARCH="linux_amd64" && \
KUSTOMIZE_TGZ="kustomize_v${KUSTOMIZE_VERSION}_${KUSTOMIZE_ARCH}.tar.gz" && \
KUSTOMIZE_TGZ_URL="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/${KUSTOMIZE_TGZ}" && \
KUSTOMIZE_CHEKSUMS_URL="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/checksums.txt" && \
curl -sSLO "${KUSTOMIZE_TGZ_URL}" && \
curl -sSLO "${KUSTOMIZE_CHEKSUMS_URL}" && \
sha256sum --ignore-missing -c "checksums.txt" 2>&1 | grep OK && \
tar -zxvf "${KUSTOMIZE_TGZ}" && \
mv kustomize /usr/local/bin/ && \
cd - && \
rm -rf "${TEMP_DIR}"

## tektoncd-cli
RUN set -euxo pipefail && \
TEMP_DIR="$(mktemp -d)" && \
cd "${TEMP_DIR}" && \
TKN_VERSION="0.32.0" && \
TKN_ARCH="Linux_x86_64" && \
TKN_TGZ="tkn_${TKN_VERSION}_${TKN_ARCH}.tar.gz" && \
TKN_TGZ_URL="https://github.com/tektoncd/cli/releases/download/v${TKN_VERSION}/${TKN_TGZ}" && \
TKN_CHEKSUMS_URL="https://github.com/tektoncd/cli/releases/download/v${TKN_VERSION}/checksums.txt" && \
curl -sSLO "${TKN_TGZ_URL}" && \
curl -sSLO "${TKN_CHEKSUMS_URL}" && \
sha256sum --ignore-missing -c "checksums.txt" 2>&1 | grep OK && \
tar -zxvf "${TKN_TGZ}" && \
mv tkn /usr/local/bin/ && \
cd - && \
rm -rf "${TEMP_DIR}"

# YQ
RUN set -euxo pipefail && \
TEMP_DIR="$(mktemp -d)" && \
cd "${TEMP_DIR}" && \
YQ_VERSION="4.35.1" && \
YQ_ARCH="linux_amd64" && \
YQ_URL="https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_${YQ_ARCH}" && \
#YQ_CHECKSUMS_URL="https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/checksums" && \
curl -sSLO "${YQ_URL}" && \
#curl -sSLO "${YQ_CHECKSUMS_URL}" && \
#sha256sum --ignore-missing -c ./checksums 2>&1 | grep OK && \
mv yq_${YQ_ARCH} /usr/local/bin/yq && \
chmod +x /usr/local/bin/yq && \
cd - && \
rm -rf "${TEMP_DIR}"

# Set permissions on /etc/passwd and /home to allow arbitrary users to write
RUN chgrp -R 0 /home && chmod -R g=u /etc/passwd /etc/group /home

# cleanup dnf cache
RUN dnf -y clean all --enablerepo='*'

COPY --chown=0:0 entrypoint.sh /

USER 10001