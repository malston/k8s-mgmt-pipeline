# Kubernetes Management Pipeline

The `k8s-mgmt-pipeline` automates the provisioning of clusters and other resources that are required to configure a cluster.  that are processed against a directory of files containing the configuration to manage clusters, namespaces, service accounts, roles, pod security policies and more. It's most common to run the CLI as part of a CI pipeline to ensure management of Kubernetes clusters are kept secure and automated for the purpose of auditing and preventing unintended configuration drift.

There are 2 types of commands: commands that execute against the Kubernetes API and commands that execute against the Pivotal Container Service (PKS) API.

You can configure the PKS plan you want to use by specifying the plan's name in the `cluster.yml` file. A cluster yaml file looks like this:

```yaml
name: my-cluster
plan: test
num-nodes: 1
external-hostname: cluster.test.example.com
network-profile: test-network-profile
```

The `external-hostname` sets the address from which to access Kubernetes API. The `network-profile` is used in NSX-T environments to set the network profile name used to create a network profile if it doesn't exist.

## Plan Requirements

The `plan` determines what features are enabled on the cluster as well as the total number of master and worker nodes to provision. The `num-nodes` can be specifed in cluster yaml file to override the plan's worker node size. The plan also determines what set of flags are passed in to the `kube-apiserver` process such as `--allow-privileged` and `--enable-admission-plugins` for example.

### Configure Compute Resources for System Daemons

* Kubelet system-reserved
  * Reserve Compute Resources for System Daemons. Enter a comma separated list of parameters e.g. `memory=250Mi`, `cpu=150m`

* Kubelet eviction-hard
  * Hard eviction thresholds set for worker kubelet to kill pods when the set thresholds are reached. e.g. `memory.available=100Mi`, `nodefs.available=10%`, `nodefs.inodesFree=5%`

### Configure Admission Control Plugins

An [admission controller](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/) is a piece of code that intercepts requests to the Kubernetes API server prior to persistence of the object, but after the request is authenticated and authorized.

## Cluster Requirements

### Create and Configure Cluster

* Configure RBAC for Users/Groups in a Cluster

* Configure Pod Security Policies

* Update/Resize Cluster

## Namespace Requirements

By default, a Kubernetes cluster will instantiate a default namespace when provisioning the cluster to hold the default set of Pods, Services, and Deployments used by the cluster. Best practice is to subdivide a cluster into multiple namespaces where each team, organization, or application gets its own namespace. You may also want to give each developer a separate namespace ensuring that one developer cannot accidentally delete another developers work. Namespaces can also serve as scopes for the deployment of services so that one application's front-end service doesn't interfere with another app's front-end service.

### Create and Configure Namespace

#### Configure RBAC for Users/Groups in a Namespace

Before you can assign a user to a namespace, you have to onboard that user to the Kubernetes cluster itself. To achieve this, there are two options. You can use certificate based authentication to create a new certificate for the user and give them a `kubeconfig` file which they can use to login or you can configure your cluster to use an external identity system (for example Active Directory) to access their cluster.

In general, using an external identity system is a best practice since it doesn't require that you maintain two different sources of identity, but in some cases this isn't possible and certificates need to be used. Fortunately, you can use the Kubernetes certificate API for creating and managing such certificates.

After the certificate has been added to the `kubeconfig` file you will need to apply Kubernetes RBAC for the user to grant them privileges to a namespace otherwise the user has no access privileges.

* Configure Default Memory Requests and Limits for a Namespace

* Configure Default CPU Requests and Limits for a Namespace

* Configure Minimum and Maximum Memory Constraints for a Namespace

* Configure Minimum and Maximum CPU Constraints for a Namespace

* Configure Memory and CPU Quotas for a Namespace

## Flow

Issue a command like `create-namespaces`.

* Loop through files under the config directory and find all the namespace folders and open each `namespace.yml` file.
* Create a new namespace based on contents of `namespace.yml`.
