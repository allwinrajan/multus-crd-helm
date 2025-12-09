# 🛠️ Multus CNI Helm Chart

This repository provides a Helm chart to deploy **Multus CNI** including:
- CRDs for NetworkAttachmentDefinitions
- Multus DaemonSet
- ConfigMap and RBAC
- Default CNI configuration support

This Helm chart can be deployed to any Kubernetes cluster where a secondary CNI is required (e.g., macvlan).

---

## 📌 Features

- Installs Multus as a secondary CNI
- Includes CRDs automatically
- Configurable CNI runtime (bridge, macvlan, delegated CNI)
- Works on cloud or bare-metal Kubernetes

---

## 🚀 Installation

### 1) Add Helm Repository

```bash
helm repo add multus https://allwinrajan.github.io/multus-crd-helm-tested/
```

### 2) Update Helm Repositories

```bash
helm repo update
```

### 3) Install Multus

```bash
helm install multus multus/multus-cni -n kube-system --create-namespace
```

### 4) Verify Installation

```bash
kubectl get pods -n kube-system | grep multus
```

### 5) Verify CRDs

```bash
kubectl get crd | grep k8s.cni.cncf.io
```

---

## 🧹 Uninstall

```bash
helm uninstall multus -n kube-system
```

---

## 🏗️ Development Workflow (How This Repo Was Created)

### 🔍 Lint Chart

```bash
helm lint .
```

### 📦 Package Chart

```bash
helm package .
```

### 🌐 Generate/Update Helm Repo Index

```bash
helm repo index . --url https://allwinrajan.github.io/multus-crd-helm-tested/
```

### 🗂️ Publish to GitHub Pages (`gh-pages` branch)

```bash
git checkout -B gh-pages
git rm -rf templates values.yaml Chart.yaml crds 1-time-setup.sh
git add .
git commit -m "Publish Helm Chart Repository"
git push -u origin gh-pages
```

### 🔧 Enable GitHub Pages

GitHub → **Settings** → **Pages** → Select Branch: `gh-pages`

Now your Helm Repository is hosted at:

```
https://allwinrajan.github.io/multus-crd-helm-tested/
```

---

## 📎 Repository Structure

```
📦 multus-crd-helm-tested/
 ├── multus-cni-0.1.0.tgz     # Packaged Helm chart
 ├── index.yaml               # Helm repository index
 └── (no templates or values here, only in source repo)
```

---

## 💡 Notes

- ONLY `index.yaml` + `.tgz` packages should be inside `gh-pages` branch.
- The source code (Chart.yaml, templates, values) must be maintained in the `main` branch.

---

## 🧠 Want Automation?

If you'd like to automate packaging + publishing via GitHub Actions, create an issue or request automation.

---

### 👨‍💻 Author

**Allwin Rajan**  
Open-source Kubernetes & DevOps Practitioner  
📌 GitHub: https://github.com/allwinrajan
