### **Note:** Refer below steps to install BAS 1.1 only on NON-PRODUCTION setup

***Pre-requistes:***

Below tools should be installed on your terminal before you start script execution:

1. OC
2. jq

**Steps:**

1. Download scripts in your current directory from
   <https://github.com/rhm-samples/behavior-analytics-services/tree/bas-11-support/Installation%20Scripts>

2. The cr.properties has the variables to create the deployment. Update the cr.properties file

   ```execute
   vi cr.properties
   ```

   It is mandatory to change the fields under section- "Change the values of these properties"

   | Properties            | Description                                                |
   | --------------------- | ---------------------------------------------------------- |
   | projectName           | Openshfit project where the BAS Operator will be installed |
   | storageClassKafka     | Storage class of type ReadWriteOnce                        |
   | storageClassZookeeper | Storage class of type ReadWriteOnce                        |
   | storageClassDB        | Storage class of type ReadWriteOnce                        |
   | storageClassArchive   | Storage class of type ReadWriteMany                        |
   | dbuser                | User name to be set for Database                           |
   | dbpassword            | Password to be set for Database                            |
   | grafanauser           | User name to be set for Grafana                            |
   | grafanapassword       | Password to be set for Grafana                             |

​       The remaining fields can be updated or kept default.

| Properties                   | Description                                                                                                                                |
| :--------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| storageSizeKafka             | Size (in G) of the storage to be attached to Kafka                                                                                         |
| storageSizeZookeeper         | Size (in G) of the storage to be attached to Zookeeper                                                                                     |
| storageSizeDB                | Size (in G) of the storage to be attached to Database                                                                                      |
| storageSizeArchive           | Size (in G) of the storage to be attached for saving DB archives                                                                           |
| eventSchedulerFrequency      | Frequency at which events will be forwarded to proxy in Cron format. It accepts values in Cron format (<https://en.wikipedia.org/wiki/Cron>) |
| prometheusSchedulerFrequency | Frequency in Cronjob format to pull metrics from Prometheus. It accepts values in Cron format (<https://en.wikipedia.org/wiki/Cron>)         |
| envType                      | Type of environment. Can be **prod** (HA) or **lite** (non HA)                                                                             |
| ibmproxyurl                  | URL of IBM Proxy                                                                                                                           |
| airgappedEnabled             | Set value to "true" if airgapped setup is to be enabled otherwise keep the default value "false"                                           |
| imagePullSecret              | Secret to pull container images from registry                                                                                              |

    Save the file ":wq"

3. Make scripts executable.

    ```
     chmod +x BAS_installation.sh bas-script-functions.bash 
    ```

4. Login to your Openshift from terminal.

   Copy the oc login command

   Paste it on the terminal.

   ```bash
   oc login --token=<token> --server=<Openshift cluster>
   ```

5. Create a CatalogSource using CLI:

    ```
    cat <<EOF>catalogsource.yaml
    apiVersion: operators.coreos.com/v1alpha1
    kind: CatalogSource
    metadata:
      name: bas-11-source
      namespace: openshift-marketplace
    spec:
      sourceType: grpc
      image: quay.io/growthstack/bas-operator:bas-index-1.1.0-private
      displayName: BAS-1.1.0
      publisher: Red Hat Partner
      updateStrategy:
        registryPoll:
          interval: 5m
    EOF
    ```

    Execute this command.

    ```
    oc create -f catalogsource.yaml 
    ```

#### Note - Wait for 5 minutes and ensure that the operator Behavior Analytics Services is availabe in OperatorHub before executing below steps

6. Execute the script BAS_installation.sh

   ```execute
   ./BAS_installation.sh
   ```

   It takes approximately 35 mins for the deployment to complete

7. On successful completion, the script will print the **API KEY**, **BAS Endpoint URL** and **Grafana URL** on the console.

8. Additionally a log file "bas-installation.log" is generated for debug purpose.
