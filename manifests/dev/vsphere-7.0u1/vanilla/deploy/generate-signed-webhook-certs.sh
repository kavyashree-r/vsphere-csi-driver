#!/bin/bash
# Copyright 2020 The Kubernetes Authors.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#    http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# File originally from https://github.com/istio/istio/blob/release-0.7/install/kubernetes/webhook-create-signed-cert.sh
set -e

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<EOF
Usage: Generate certificate suitable for use with an webhook service.

This script uses k8s' CertificateSigningRequest API to a generate a
certificate signed by k8s CA suitable for use with sidecar-injector webhook
services. This requires permissions to create and approve CSR. See
https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster for
detailed explanation and additional instructions.

usage: ${0} [OPTIONS]
The following flags are required.
       --namespace        Namespace where webhook service and secret reside.
EOF
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case ${1} in
        --namespace)
            namespace="$2"
            shift
            ;;
        *)
            usage
            ;;
    esac
    shift
done

[ -z "${namespace}" ] && namespace=kube-system

service=vsphere-webhook-svc
secret=vsphere-webhook-certs


if [ ! -x "$(command -v openssl)" ]; then
    echo "openssl not found"
    exit 1
fi

if [ ! -x "$(command -v kubectl)" ]; then
    echo "kubectl not found"
    exit 1
fi

csrName=${service}.${namespace}
tmpdir=$(mktemp -d)
echo "creating certs in tmpdir ${tmpdir} "

cat <<EOF >> "${tmpdir}"/csr.conf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${service}
DNS.2 = ${service}.${namespace}
DNS.3 = ${service}.${namespace}.svc
EOF

openssl genrsa -out "${tmpdir}"/server-key.pem 2048
openssl req -new -key "${tmpdir}"/server-key.pem -subj "/O=C=US/ST=CA/L=Palo Alto/O=VMware/OU=CNS" -out "${tmpdir}"/server.csr -config "${tmpdir}"/csr.conf


# clean-up any previously created CSR for our service. Ignore errors if not present.
kubectl delete csr ${csrName} 2>/dev/null || true

# create  server cert/key CSR and  send to k8s API
cat <<EOF | kubectl create -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: ${csrName}
spec:
  groups:
  - system:authenticated
  request: $(base64 "${tmpdir}"/server.csr | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

# verify CSR has been created
while true; do
    if kubectl get csr "${csrName}"; then
        break
    fi
    echo "waiting for CertificateSigningRequest: ${csrName} to be available"
    sleep 1
done

# approve and fetch the signed certificate
kubectl certificate approve ${csrName}
# verify certificate has been signed
for _ in $(seq 10); do
    serverCert=$(kubectl get csr ${csrName} -o jsonpath='{.status.certificate}')
    if [[ ${serverCert} != '' ]]; then
        break
    fi
    echo "waiting for certificate request to complete"
    sleep 1
done
if [[ ${serverCert} == '' ]]; then
    echo "ERROR: After approving csr ${csrName}, the signed certificate did not appear on the resource. Giving up after 10 attempts." >&2
    exit 1
fi
echo "${serverCert}" | openssl base64 -d -A -out "${tmpdir}"/server-cert.pem

cat <<eof >"${tmpdir}"/webhook.config
[WebHookConfig]
port = "8443"
cert-file = "/etc/webhook/cert.pem"
key-file = "/etc/webhook/key.pem"

# FeatureStatesConfig holds the details about feature states configmap.
# Default feature states configmap name is set to "csi-feature-states"  and namespace is set to "kube-system"
# Provide the configmap name and namespace details only when feature states configmap is not in the default namespace
[FeatureStatesConfig]
name = "csi-feature-states"
namespace = "${namespace}"
eof


# create the secret with CA cert and server cert/key
kubectl create secret generic "${secret}" \
        --from-file=key.pem="${tmpdir}"/server-key.pem \
        --from-file=cert.pem="${tmpdir}"/server-cert.pem \
        --from-file=webhook.config="${tmpdir}"/webhook.config \
        --dry-run=client -o yaml |
    kubectl -n "${namespace}" apply -f -