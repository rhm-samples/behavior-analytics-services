## mTLS Update Script


Steps to Update mTLS secret:


1. Navigate to ~/mtls-update-script


```
cd mtls-update-script
```


2. Execute below command to login to OpenShift cluster. Ensure to use your token and OpenShift cluster URL


```
oc login --token=set_token --server=set_openshift_cluster_url
```

3.  Make script executable

```
chmod a+x update-mtls.sh script-functions.bash
```

4. Execute Script

>--ns target namespace name

```
./update-mtls.sh --ns <project/namespace name>
```

Example
```
./update-mtls.sh --ns bas-test
```
