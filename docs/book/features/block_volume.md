<!-- markdownlint-disable MD033 -->
<!-- markdownlint-disable MD034 -->
# vSphere CSI Driver - Block Volume

- [Dynamic Volume Provisioning](#dynamic_volume_provisioning)
  - [Dynamically Provision a Block Volume on Vanilla Kubernetes Cluster](#dynamic_volume_provisioning_vanilla)
  - [Dynamically provision a block volume in Tanzu Kubernetes Grid Service](#dynamic_volume_provisioning_tanzu)
  - [Dynamically provision a block volume in Supervisor Cluster](#dynamic_volume_provisioning_pacific)
  - [Comparison of Cluster Flavor and the corresponding Storage Class Parameters](#dynamic_volume_provisioning_comparison)
- [Static Volume Provisioning](#static_volume_provisioning)
  - [How does it work](#static_volume_provisioning_how)
  - [Use Cases of Static Provisioning](#static_volume_provisioning_use_case)
  - [Statically Provision a Block Volume in Vanilla Kubernetes Cluster](#static_volume_provisioning_vanilla)
  - [Statically Provision a Block Volume in vSphere with Kubernetes](#static_volume_provisioning_vsphere_with_k8s)
  - [Statically Provision a Block Volume in Tanzu Kubernetes Grid Service](#static_volume_provisioning_tkg)

## Volume Provisioning

There are two types of volume provisioning in a Kubernetes cluster:

1. Dynamic Volume Provisioning
2. Static Volume Provisioning

## Dynamic Volume Provisioning<a id="dynamic_volume_provisioning"></a>

Dynamic volume provisioning allows storage volumes to be created on-demand.

Without dynamic provisioning, cluster administrators have to manually make calls to their cloud or storage provider to
create new storage volumes and then create PersistentVolume objects to represent them in Kubernetes.

The dynamic provisioning feature eliminates the need for cluster administrators to pre-provision storage. Instead, it
automatically provisions storage when it is requested by users.

The implementation of dynamic volume provisioning is based on the API object `StorageClass` from the API group `storage.k8s.io`
A cluster administrator can define as many `StorageClass` objects as needed, each specifying a volume plugin
(a.k.a `provisioner`) that provisions a volume and a set of parameters to that `provisioner` when provisioning.
A cluster administrator can define and expose multiple flavors of storage (from the same or different storage systems)
within a cluster, each with a custom set of parameters.

Dynamic Volume Provisioning is supported both in Vanilla Kubernetes clusters and Supervisor clusters.

The details for provisioning volume using topology and use of `WaitForFirstConsumer` volumeBinding mode with dynamic
volume provisioning is described [here](volume_topology.md)

**NOTE:** The support for Volume topology is present only in Vanilla Kubernetes Block Volume driver today.

### Dynamically Provision a Block Volume on Vanilla Kubernetes Cluster<a id="dynamic_volume_provisioning_vanilla"></a>

This section describes the step by step instructions to provision a PersistentVolume dynamically on a `Vanilla Kubernetes` cluster

- Define a Storage Class as shown [here](https://github.com/kubernetes-sigs/vsphere-csi-driver/blob/master/example/vanilla-k8s-block-driver/example-sc.yaml)

    ```bash
    kind: StorageClass
    apiVersion: storage.k8s.io/v1
    metadata:
      name: example-vanilla-block-sc
      annotations:
        storageclass.kubernetes.io/is-default-class: "true"
    provisioner: csi.vsphere.vmware.com
    parameters:
      storagepolicyname: "vSAN Default Storage Policy"  #Optional Parameter
    # datastoreurl: "ds:///vmfs/volumes/vsan:52cdfa80721ff516-ea1e993113acfc77/" #Optional Parameter
    # csi.storage.k8s.io/fstype: "ext4" #Optional Parameter
    ```

- Import this `StorageClass` into `Vanilla Kubernetes` cluster:

    ```bash
        kubectl create -f example-sc.yaml
    ```

- Define a `PersistentVolumeClaim` request as shown in the spec [here](https://github.com/kubernetes-sigs/vsphere-csi-driver/blob/master/example/vanilla-k8s-block-driver/example-pvc.yaml)

- Import this `PersistentVolumeClaim` into `Vanilla Kubernetes` cluster:

    ```bash
        kubectl create -f example-pvc.yaml
    ```

- Verify the PersistentVolumeClaim was created:

  Check to see if the `PersistentVolumeClaim` we just imported was created and has a `PersistentVolume` attached to it.

  The `Status` section below should show `Bound` if it worked and the `Volume` field should be populated.

  A `PersistentVolume` is automatically created and is bound to this `PersistentVolumeClaim`.

    ```bash
      $ kubectl describe pvc example-vanilla-block-pvc
        Name:          example-vanilla-block-pvc
        Namespace:     default
        StorageClass:  example-vanilla-block-sc
        Status:        Bound
        Volume:        pvc-7ed39d8e-7896-11ea-a119-005056983fec
        Labels:        <none>
        Annotations:   pv.kubernetes.io/bind-completed: yes
                       pv.kubernetes.io/bound-by-controller: yes
                       volume.beta.kubernetes.io/storage-provisioner: csi.vsphere.vmware.com
        Finalizers:    [kubernetes.io/pvc-protection]
        Capacity:      5Gi
        Access Modes:  RWO
        VolumeMode:    Filesystem
        Mounted By:    <none>
        Events:
          Type    Reason                 Age                From                                                                                                 Message
          ----    ------                 ----               ----                                                                                                 -------
          Normal  Provisioning           50s                csi.vsphere.vmware.com_vsphere-csi-controller-7777666589-jpnqh_798e6967-2ce1-486f-9c21-43d9dea709ae  External provisioner is provisioning volume for claim "default/example-vanilla-block-pvc"
          Normal  ExternalProvisioning   20s (x3 over 50s)  persistentvolume-controller                                                                          waiting for a volume to be created, either by external provisioner "csi.vsphere.vmware.com" or manually created by system administrator
          Normal  ProvisioningSucceeded  8s                 csi.vsphere.vmware.com_vsphere-csi-controller-7777666589-jpnqh_798e6967-2ce1-486f-9c21-43d9dea709ae  Successfully provisioned volume pvc-7ed39d8e-7896-11ea-a119-005056983fec
    ```

    Here, `RWO` access mode indicates that the volume provisioned is a `Block` Volume. In the case of `File`
    volume, the accessMode will be either `ROX` or `RWX`.

- Verify a `PersistentVolume` was created

  Next, let's check if a `PersistentVolume` was successfully created for the `PersistentVolumeClaim` we defined above.

  If it has worked you should have a `PersistentVolume` show up in the output and you should see that the `VolumeHandle`
  key is populated, as is the case below

  The `Status` should say `Bound`. You can also see the `Claim` is set to the above `PersistentVolumeClaim` name `example-vanilla-block-pvc`

    ```bash
      $ kubectl describe pv pvc-7ed39d8e-7896-11ea-a119-005056983fec
        Name:            pvc-7ed39d8e-7896-11ea-a119-005056983fec
        Labels:          <none>
        Annotations:     pv.kubernetes.io/provisioned-by: csi.vsphere.vmware.com
        Finalizers:      [kubernetes.io/pv-protection]
        StorageClass:    example-vanilla-block-sc
        Status:          Bound
        Claim:           default/example-vanilla-block-pvc
        Reclaim Policy:  Delete
        Access Modes:    RWO
        VolumeMode:      Filesystem
        Capacity:        5Gi
        Node Affinity:   <none>
        Message:
        Source:
            Type:              CSI (a Container Storage Interface (CSI) volume source)
            Driver:            csi.vsphere.vmware.com
            VolumeHandle:      e4073a6d-642e-4dff-8f4a-b4e3a47c4bbd
            ReadOnly:          false
            VolumeAttributes:      storage.kubernetes.io/csiProvisionerIdentity=1586239648866-8081-csi.vsphere.vmware.com
                                   type=vSphere CNS Block Volume
        Events:                <none>
    ```

### Dynamically provision a block volume in Tanzu Kubernetes Grid Service<a id="dynamic_volume_provisioning_tanzu"></a>

In a Tanzu Kubernetes Grid Service, the `StorageClass` gets automatically created and is made available to it by the
underlying Supervisor cluster. An example storage class looks like -

```yaml
apiVersion: v1
items:
- apiVersion: storage.k8s.io/v1
  kind: StorageClass
  metadata:
    name: gc-storage-profile
  parameters:
    storagePolicyID: 78b3d5e0-ab3f-4003-85ae-77c1b691a001
  provisioner: csi.vsphere.vmware.com
  reclaimPolicy: Delete
  volumeBindingMode: Immediate
kind: List
metadata:
  resourceVersion: ""
  selfLink: ""
```

User only has to perform the following to dynamically provision a block volume:

- Specify the desired `StorageClass` name in the `PersistentVolumeClaim` spec
- Create a `PersistentVolumeClaim` in the namespace using the spec mentioned in the previous step
- Wait for CNS to create a `PersistentVolume`
- Verify if the status of `PersistentVolumeClaim` set to `Bound`

### Dynamically provision a block volume in Supervisor Cluster<a id="dynamic_volume_provisioning_pacific"></a>

In the case of `Supervisor` clusters, `StorageClass` creation happens automatically when a Storage Policy gets created.
Following is an example of a `StorageClass` generated by one of the default storage policies within the cluster:

```bash
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  creationTimestamp: "2020-04-14T22:17:41Z"
  name: wcpglobal-storage-profile
  resourceVersion: "3477831"
  selfLink: /apis/storage.k8s.io/v1/storageclasses/wcpglobal-storage-profile
  uid: 0f84a03f-8a45-4116-8877-5ad0af28409c
parameters:
  storagePolicyID: 97aaf339-98c8-46d6-8c75-de49ea67f15d
provisioner: csi.vsphere.vmware.com
reclaimPolicy: Delete
volumeBindingMode: Immediate
```

The user has to do the following to provision a `PersistentVolume`:

- Create a new storage policy or add an existing storage policy of interest to the current namespace
- Specify the `StoragePolicy` name (which got created by the storage policy) in the `PersistentVolumeClaim` spec
- Create a `PersistentVolumeClaim` in the namespace using the spec mentioned in the previous step
- Wait for CNS to create a `PersistentVolume`
- Verify if the status of `PersistentVolumeClaim` set to `Bound`

### Comparison of Cluster Flavor and the corresponding Storage Class Parameters<a id="dynamic_volume_provisioning_comparison"></a>

   <table>
    <thead>
    <tr>
    <th>Cluster Flavor</th>
    <th>Storage Class Parameters</th>
    </tr>
    </thead>
    <tbody>
    <tr>
    <td>Vanilla</td>
    <td><em>storagepolicyname</em>, <em>datastoreURL</em>, <em>csi.storage.k8s.io/fstype</em></td>
    </tr>
    <tr>
    <td>Supervisor</td>
    <td><em>storagePolicyID</em></td>
    </tr>
    <tr>
    <td>Tanzu Kubernetes Grid</td>
    <td><em>storagePolicyID</em></td>
    </tr>
    </tbody>
   </table>

## Static Volume Provisioning<a id="static_volume_provisioning"></a>

If you have an existing persistent storage device in your VC, you can use static provisioning to make the storage
instance available to your cluster.

### How does it work<a id="static_volume_provisioning_how"></a>

Static provisioning is a feature that is native to Kubernetes and that allows cluster administrators to make existing
storage devices available to a cluster.

As a cluster administrator, you must know the details of the storage device, its supported configurations, and mount options.

To make existing storage available to a cluster user, you must manually create the storage device, a `PeristentVolume`,
and a `PersistentVolumeClaim`.
Because the PV and the storage device already exists, there is no need to specify a storage class name in the PVC spec.
There are many ways to create static PV and PVC binding. Example: Label matching, Volume Size matching etc

Static Volume Provisioning is supported only in Vanilla Kubernetes clusters but not in Supervisor clusters

### Use Cases of Static Provisioning<a id="static_volume_provisioning_use_case"></a>

Following are the common use cases for static volume provisioning:

- **Use an existing storage device:**
    You provisioned a persistent storage(FCD) directly in your VC and want to use this `FCD` in your cluster.

- **Make retained data available to the cluster:**
    You provisioned a volume with a `reclaimPolicy: retain` in the storage class by using dynamic provisioning.
    You removed the `PVC`, but the `PV`, the physical storage in the VC, and the data still exist.
    You want to access the retained data from an app in your cluster.

- **Share persistent storage across namespaces in the same cluster:**
    You provisioned a `PV` in a namespace of your cluster. You want to use the same storage instance for an app pod
    that is deployed to a different namespace in your cluster.

- **Share persistent storage across clusters in the same zone:**
    You provisioned a `PV` for your cluster. To share the same persistent storage instance with other clusters in
    the same zone, you must manually create the `PV` and matching `PVC` in the other cluster.

**NOTE:**
Sharing persistent storage across clusters is available only if the cluster and the storage instance are located in
the same zone.

### Statically Provision a Block Volume in Vanilla Kubernetes Cluster<a id="static_volume_provisioning_vanilla"></a>

This section describes the step by step instructions to provision a PersistentVolume statically on a `Vanilla Kubernetes`
cluster. Make sure to mention `pv.kubernetes.io/provisioned-by: csi.vsphere.vmware.com` in the PV annotation.

- Define a PVC and a PV as shown below

    ```yaml
        apiVersion: v1
        kind: PersistentVolume
        metadata:
          name: static-pv-name
          annotations:
            pv.kubernetes.io/provisioned-by: csi.vsphere.vmware.com
          labels:
            fcd-id: 0c75d40e-7576-4fe7-8aaa-a92946e2805d # This label is used as selector to bind with volume claim.
                                                         # This can we any unique key-value to identify PV.
        spec:
          capacity:
            storage: 2Gi
          accessModes:
            - ReadWriteOnce
          persistentVolumeReclaimPolicy: Delete
          csi:
            driver: "csi.vsphere.vmware.com"
            volumeAttributes:
              type: "vSphere CNS Block Volume"
            "volumeHandle": "0c75d40e-7576-4fe7-8aaa-a92946e2805d" # First Class Disk (Improved Virtual Disk) ID
        ---
        kind: PersistentVolumeClaim
        apiVersion: v1
        metadata:
          name: static-pvc-name
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 2Gi
          selector:
            matchLabels:
              fcd-id: 0c75d40e-7576-4fe7-8aaa-a92946e2805d # This label is used as selector to find matching PV with specified key and value.
          storageClassName: ""
        ---
    ```

- Import this PV and PVC into Vanilla Kubernetes cluster

    ```bash
        kubectl create -f static.yaml
    ```

- Verify the PVC creation
    Check to see if the `PVC` we just imported was created and the `PersistentVolume` got attached to it. The `Status`
    section below should show `Bound` if it worked and the `Volume` field should be populated.

    ```bash
        $ kubectl describe pvc static-pvc-name
        Name:          static-pvc-name
        Namespace:     default
        StorageClass:
        Status:        Bound
        Volume:        static-pv-name
        Labels:        <none>
        Annotations:   pv.kubernetes.io/bind-completed: yes
                       pv.kubernetes.io/bound-by-controller: yes
        Finalizers:    [kubernetes.io/pvc-protection]
        Capacity:      2Gi
        Access Modes:  RWO
        VolumeMode:    Filesystem
        Mounted By:    <none>
        Events:        <none>
    ```

- Verify the PV was created
    Let's check if the `PV` was successfully attached to the `PVC` we defined above. If it has worked you should have
    a `PV` show up in the output, and you should see that the `VolumeHandle` key is populated, as is the case below.
    The `Status` should say `Bound`. You can also see the `Claim` is set to the above `PVC` name:  `static-pvc-name`

    ```bash
        $ kubectl describe pv static-pv-name
        Name:            static-pv-name
        Labels:          fcd-id=0c75d40e-7576-4fe7-8aaa-a92946e2805d
        Annotations:     pv.kubernetes.io/bound-by-controller: yes
                         pv.kubernetes.io/provisioned-by: csi.vsphere.vmware.com
        Finalizers:      [kubernetes.io/pv-protection]
        StorageClass:
        Status:          Bound
        Claim:           default/static-pvc-name
        Reclaim Policy:  Delete
        Access Modes:    RWO
        VolumeMode:      Filesystem
        Capacity:        2Gi
        Node Affinity:   <none>
        Message:
        Source:
            Type:              CSI (a Container Storage Interface (CSI) volume source)
            Driver:            csi.vsphere.vmware.com
            VolumeHandle:      0c75d40e-7576-4fe7-8aaa-a92946e2805d
            ReadOnly:          false
            VolumeAttributes:      type=vSphere CNS Block Volume
        Events:                <none>
    ```

### Statically Provision a Block Volume in vSphere with Kubernetes<a id="static_volume_provisioning_vsphere_with_k8s"></a>

vSphere 7.0 did not support static volume provisioning in vSphere with Kubernetes aka supervisor cluster. Static volume provisioning is a process where an existing volume on the storage is made available in the Kubernetes cluster. There are use cases where we want to import existing volumes into supervisor cluster.

A new CnsRegisterVolume API is introduced in vSphere 7.0 Update1 release in vSphere with Kubernetes that allows importing an existing CNS volume or First Class Disk (FCD) or vmdk into a supervisor namespace. CnsRegisterVolume API objects are namespaced objects and once created successfully it would create a PVC in that namespace and a PV bound to that PVC.

**NOTE:** Please note that CnsRegisterVolume API instances cannot be created by normal SV devop users.

1. Import CNS volume or First Class Disk (FCD) into Supervisor Cluster.

    ```yaml
      apiVersion: cns.vmware.com/v1alpha1
      kind: CnsRegisterVolume
      metadata:
        name: import-mongodb
      spec:
        pvcName: mongo-pvc
        volumeID: fe1efbd0-79f7-4a2f-a8a9-69852e62225a
        accessMode: ReadWriteOnce
    ```

    - `pvcName` is the name of the PVC that will be created in the namespace.
    - `volumeID` is the CNS volume Id or FCD Id that will be imported into the supervisor namespace. CNS volume Id is available on CNS UI.
    - `accessMode` indicates whether its a block or a file volume. Currently only block volume with `ReadWriteOnce` is supported.

2. Import VMDK into Supervisor Cluster.

    ```yaml
      apiVersion: cns.vmware.com/v1alpha1
      kind: CnsRegisterVolume
      metadata:
        name: import-mongodb
      spec:
        pvcName: mongo-pvc
        diskURLPath: https://10.161.1.195/folder/testdisk2.vmdk?dcPath=test-vpx-1586388419-26155-wcp.wcp-sanity&dsName=nfs0-1
    ```

    - `diskURLPath` this field would identify the URL path to an existing disk that will be used to import into supervisor namespace.
    Format: `https://<vc_ip>/folder/<vm_vmdk_path>?dcPath=<datacenterPath>&dsName=<datastoreName>`
    - `accessMode` will be defaulted to `ReadWriteOnce` in this case.

### Statically Provision a Block Volume in Tanzu Kubernetes Grid Service<a id="static_volume_provisioning_tkg"></a>

You can statically create a block volume in Tanzu Kubernetes Grid Service (TKGS) using an unused PersistentVolumeClaim (PVC) from the Supervisor cluster only if the latter satisfies the following conditions:

- It is present in the same Supervisor cluster namespace where the TKGS was created

- Not attached to a Pod in the Supervisor cluster or in any other TKGS

Using static provisioning, a PVC created by one TKGS can also be re-used in another TKGS when the volume is no longer needed in the former one. In order to do so, you need to modify the `Reclaim policy` of the PV in the old TKGS to `Retain` and then delete the corresponding PVC. Follow the steps below to statically create a PVC in the new TKGS using the information from the leftover underlying volume.

Steps to create a static PVC in a TKGS are as follows:

1. Note the name of the PVC in the supervisor cluster. If you are re-using a PVC from an old TKGS, then this value can also be retrieved from the `volumeHandle` of the old PV object in the TKGS.

2. Create a PersistentVolume with the `storageClassName` preferably set to the storage class name of your supervisor cluster PVC and the `volumeHandle` pointing to the value retrieved in step 1. If you are re-using a volume from another TKGS where it is no more required, delete the PVC and PV object from the old TKGS before creating a PV in the new TKGS.

    ```yaml
      apiVersion: v1
      kind: PersistentVolume
      metadata:
        name: static-tkg-block-pv
        annotations:
          pv.kubernetes.io/provisioned-by: csi.vsphere.vmware.com
      spec:
        storageClassName: gc-storage-profile
        capacity:
          storage: 2Gi
        accessModes:
          - ReadWriteOnce
        persistentVolumeReclaimPolicy: Delete
        claimRef:
          namespace: default
          name: static-tkg-block-pvc
        csi:
          driver: "csi.vsphere.vmware.com"
          volumeAttributes:
            type: "vSphere CNS Block Volume"
          volumeHandle: "supervisor-block-pvc-name"  # Mention the PVC name from Supervisor cluster here
    ```

3. Create a PVC to match the PV object created above. Also set the `storageClassName` to the same value as above.

    ```yaml
      kind: PersistentVolumeClaim
      apiVersion: v1
      metadata:
        name: static-tkg-block-pvc
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 2Gi
        storageClassName: gc-storage-profile
        volumeName: static-tkg-block-pv
    ```

4. Check if the PVC is bound to the PV we created on step 2.

    ```bash
    $ kubectl get pv,pvc
    NAME                                    CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                          STORAGECLASS         REASON   AGE
    persistentvolume/static-tkg-block-pv    2Gi        RWO            Delete           Bound    default/static-tkg-block-pvc   gc-storage-profile            10s

    NAME                                         STATUS   VOLUME                CAPACITY   ACCESS MODES   STORAGECLASS         AGE
    persistentvolumeclaim/static-tkg-block-pvc   Bound    static-tkg-block-pv   2Gi        RWO            gc-storage-profile   10s
    ```

Static provisioning is complete.
