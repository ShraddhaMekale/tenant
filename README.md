# TenantHub Platform Engineering Tasks

This repository contains the deliverables for the TenantHub Platform Engineering take-home assignment.

## Task 1 — Tenant Provisioning

### Idempotency of the Workflow
If the GitHub Actions workflow is run twice for the same tenant (e.g., `acme-corp`), the behavior will be idempotent:
1.  **Terraform:** Terraform maintains state. When it runs a second time, it will check the existing resources (Cloud SQL Database and User) against the desired state defined in the configuration. Since they already exist and match the configuration, Terraform will determine that no changes are necessary and will not recreate or modify them.
2.  **Kubernetes Manifests:** The manifests generated and applied to the cluster (Namespace, ServiceAccount, Role, RoleBinding) are declarative. If applied again, Kubernetes will compare the applied manifests to the current state. Since they are identical, no updates will be made.
3.  **GitHub Action:** The `peter-evans/create-pull-request` action checks if a branch and PR already exist. If a PR is already open for the changes, it will update the existing branch (which will have no new diffs in this case).

### Extending to 50 Tenants Without Editing the Workflow
To scale this to 50 tenants without editing the workflow itself:
1.  **Matrix Builds / Dynamic Generation:** Modify the GitHub Action to read the `tenants.yaml` file, parse it (e.g., using `yq` or a custom script), and dynamically generate a matrix of jobs for each tenant that needs provisioning. This allows parallel execution.
2.  **Terraform Iteration (`for_each`):** Alternatively, shift the loop from the CI/CD pipeline down into Terraform. The `main.tf` can use `for_each` to iterate over a list of tenants parsed directly from `tenants.yaml` (using `yamldecode()`). The CI/CD pipeline would just run a single `terraform apply`. The workflow currently just parses a placeholder; in a real scenario, passing the whole parsed list or letting Terraform parse it is best.
3.  **Helm / Kustomize for K8s:** Similar to Terraform, use a tool like Helm to template the K8s manifests. The CI pipeline would loop through the tenants and output a rendered template for each, or ArgoCD/Flux could pull from the repository and generate the K8s resources dynamically based on the tenants configuration.

## Task 2 — Secret Isolation & Security

### Why Scope IAM Binding to a Single Secret?
Scoping the GCP IAM binding (`roles/secretmanager.secretAccessor`) to a single secret rather than project-wide prevents **lateral movement (privilege escalation) in the event of a compromised tenant workload**. If an attacker compromises a pod running in the `acme-corp` namespace, they can leverage the attached Workload Identity service account. If the binding were project-wide, the attacker could list and read all secrets in the GCP Secret Manager, exposing every other tenant's credentials. By scoping it only to `tenant-acme-corp-credentials`, the breach is contained strictly to `acme-corp`'s data, preserving the isolation of all other tenants.

### Why is NetworkPolicy Alone Insufficient?
While NetworkPolicies are crucial for defining layer 3/4 network isolation (e.g., stopping an `acme-corp` pod from pinging a `globex` pod), they are insufficient on their own for true tenant isolation in a shared cluster. 
1. **Identity & Access (RBAC):** NetworkPolicies don't restrict API access. A pod with an overprivileged ServiceAccount could still query the Kubernetes API to read secrets, configmaps, or deploy malicious workloads into other namespaces. 
2. **Compute & Resource Exhaustion:** NetworkPolicies don't prevent noisy neighbor problems. A compromised or misconfigured tenant could consume all CPU/Memory on the nodes, causing outages for other tenants. Quotas, LimitRanges, and Node/Pod affinities are needed.
3. **Egress Subversion:** If multiple tenants share the same egress NAT or Cloud SQL Proxy endpoint internally, NetworkPolicies might not be granular enough to prevent one tenant from accessing another's database logic if authentication isn't strictly enforced at the database level as well.

## Task 3 — Infra Change Visibility

### Real Scenario for PR Diff Workflow
Imagine a scenario where an engineer intends to update the memory limits for an ArgoCD deployment in a Kustomize overlay (`overlays/prod/deployment-patch.yaml`), but accidentally removes the `name: argocd-server` reference in the patch, or misspells the namespace. 

Without a PR diff, the code might be merged, and when ArgoCD (or the CD tool) attempts to sync, it might apply the patch to the wrong deployment, or fail to apply entirely, leading to a silent failure or an unexpected overwrite of another critical service's resources. 

With the `kustomize build` PR diff workflow, the engineer and reviewers will immediately see in the GitHub comment that the generated output is attempting to modify/create an unintended resource (or failing to modify the intended one), catching the mistake visually before it is ever merged or synced to the cluster.
