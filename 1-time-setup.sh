# Backup current chart
cd /home/administrator
mv multus-crd-helm multus-crd-helm.backup

# Create fresh chart structure
mkdir -p multus-crd-helm/{templates,crds}
cd multus-crd-helm

# Create Chart.yaml
cat > Chart.yaml << 'EOF'
apiVersion: v2
name: multus-cni
description: Install Multus CNI + CRD + CNI config
type: application
version: 0.1.0
appVersion: v3.9.2
EOF

# Create values.yaml
cat > values.yaml << 'EOF'
image:
  repository: ghcr.io/k8snetworkplumbingwg/multus-cni
  tag: v3.9.2
  pullPolicy: IfNotPresent

serviceAccount:
  name: multus-cni

multusCniConfFile: 00-multus.conf

resources: {}

tolerations:
  - operator: Exists

nodeSelector: {}

defaultCni: calico
EOF

# Create CRD
cat > crds/network-attachment-definition.yaml << 'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: network-attachment-definitions.k8s.cni.cncf.io
spec:
  group: k8s.cni.cncf.io
  names:
    kind: NetworkAttachmentDefinition
    plural: network-attachment-definitions
    singular: network-attachment-definition
    shortNames:
      - net-attach-def
  scope: Namespaced
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                config:
                  type: string
EOF

# Create ServiceAccount
cat > templates/serviceaccount.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .Values.serviceAccount.name }}
  namespace: kube-system
EOF

# Create RBAC
cat > templates/rbac.yaml << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: multus-cni
rules:
  - apiGroups: [""]
    resources:
      - pods
      - pods/status
    verbs:
      - get
      - list
      - watch
      - update
  - apiGroups: [""]
    resources:
      - nodes
    verbs:
      - get
      - list
  - apiGroups: ["k8s.cni.cncf.io"]
    resources:
      - network-attachment-definitions
    verbs:
      - get
      - list
      - watch
  - apiGroups: [""]
    resources:
      - events
    verbs:
      - create
      - patch
      - update
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: multus-cni
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: multus-cni
subjects:
  - kind: ServiceAccount
    name: {{ .Values.serviceAccount.name }}
    namespace: kube-system
EOF

# Create ConfigMap
cat > templates/configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: multus-cni-config
  namespace: kube-system
data:
  cni-conf.json: |
    {
      "name": "multus-cni-network",
      "type": "multus",
      "kubeconfig": "/etc/cni/net.d/multus.d/multus.kubeconfig",
      "delegates": [
        {
          "type": "{{ .Values.defaultCni }}"
        }
      ]
    }
EOF

# Create DaemonSet
cat > templates/daemonset.yaml << 'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube-multus-ds
  namespace: kube-system
  labels:
    app: multus-cni
spec:
  selector:
    matchLabels:
      app: multus-cni
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: multus-cni
    spec:
      hostNetwork: true
      serviceAccountName: {{ .Values.serviceAccount.name }}
      tolerations:
{{ toYaml .Values.tolerations | indent 8 }}
      nodeSelector:
{{ toYaml .Values.nodeSelector | indent 8 }}
      volumes:
        - name: cni-bin-dir
          hostPath:
            path: /opt/cni/bin
        - name: cni-conf-dir
          hostPath:
            path: /etc/cni/net.d
        - name: multus-kubeconfig
          hostPath:
            path: /etc/cni/net.d/multus.d
            type: DirectoryOrCreate
        - name: multus-cfg
          configMap:
            name: multus-cni-config
        - name: multus-workdir
          emptyDir: {}
      initContainers:
        - name: extract-multus-binary
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          command:
            - /bin/sh
            - -c
            - |
              echo "[INIT] Searching for multus binary..."
              BIN=""
              for p in /usr/local/bin/multus /usr/src/multus-cni/bin/multus /bin/multus; do
                if [ -f "$p" ]; then BIN=$p; break; fi
              done
              if [ -z "$BIN" ]; then echo "[ERROR] NO MULTUS BINARY FOUND" && exit 1; fi
              echo "[INIT] Found multus at $BIN"
              cp $BIN /workdir/multus
              chmod +x /workdir/multus
              echo "[SUCCESS] Copy done"
          volumeMounts:
            - name: multus-workdir
              mountPath: /workdir
        - name: install-multus-binary
          image: busybox
          command:
            - /bin/sh
            - -c
            - |
              mkdir -p /host/opt/cni/bin/
              cp /workdir/multus /host/opt/cni/bin/
              chmod +x /host/opt/cni/bin/multus
              echo "[SUCCESS] Installed multus to host"
          volumeMounts:
            - name: multus-workdir
              mountPath: /workdir
            - name: cni-bin-dir
              mountPath: /host/opt/cni/bin
        - name: write-multus-conf
          image: busybox
          command:
            - /bin/sh
            - -c
            - |
              echo "[INIT] Writing Multus top config..."
              cat /multus-cfg/cni-conf.json > /host/etc/cni/net.d/{{ .Values.multusCniConfFile }}
              echo "[SUCCESS] Config written"
          volumeMounts:
            - name: cni-conf-dir
              mountPath: /host/etc/cni/net.d
            - name: multus-cfg
              mountPath: /multus-cfg
      containers:
        - name: kube-multus
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          command:
            - /entrypoint.sh
          args:
            - "--multus-conf-file=auto"
            - "--multus-autoconfig-dir=/host/etc/cni/net.d"
            - "--cni-version=0.3.1"
          resources:
{{ toYaml .Values.resources | indent 12 }}
          securityContext:
            privileged: true
          volumeMounts:
            - name: cni-bin-dir
              mountPath: /host/opt/cni/bin
            - name: cni-conf-dir
              mountPath: /host/etc/cni/net.d
            - name: multus-kubeconfig
              mountPath: /etc/cni/net.d/multus.d
EOF

# Verify structure
echo "=== Chart structure ==="
tree . || find . -type f

# Lint the chart
helm lint .

# Install
helm install multus . -n kube-system --create-namespace

# Watch the installation
kubectl -n kube-system get pods -l app=multus-cni -w