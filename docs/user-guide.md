# Gatling Operator User Guide

<!-- TOC -->

- [Gatling Operator User Guide](#gatling-operator-user-guide)
	- [Configuration Overview](#configuration-overview)
	- [Gatling Load Testing Configuration and Deployment](#gatling-load-testing-configuration-and-deployment)
		- [Create Custom Gatling Image to bundle Gatling Load Testing Files](#create-custom-gatling-image-to-bundle-gatling-load-testing-files)
		- [Add Gatling Load Testing Files in Gatling CR](#add-gatling-load-testing-files-in-gatling-cr)
		- [Read Gatling Load Testing Files from PersistentVolume](#read-gatling-load-testing-files-from-persistentVolume)
		- [Debug and Trace Gatling Load Testing](#debug-and-trace-gatling-load-testing)
		- [How to Pull Gatling Runtime Image from Private Registry](#how-to-pull-gatling-runtime-image-from-private-registry)
			- [Create an "image pull secret"](#create-an-image-pull-secret)
			- [Add ImagePullSecrets to your service account](#add-imagepullsecrets-to-your-service-account)
	- [Gatling Custom Resource Examples](#gatling-custom-resource-examples)
		- [Choose Execution Phases](#choose-execution-phases)
		- [Configure Gatling Runner Pod](#configure-gatling-runner-pod)
			- [Resource Allocation and Scheduling for Gatling Runner Pod](#resource-allocation-and-scheduling-for-gatling-runner-pod)
			- [Service Account for Gatling Runner Pod](#service-account-for-gatling-runner-pod)
		- [Configure Gatling Load Testing Scenario and How It's Executed](#configure-gatling-load-testing-scenario-and-how-its-executed)
			- [Start Time of Gatling Load Testing](#start-time-of-gatling-load-testing)
			- [Parallel Number of Gatling Load Testing](#parallel-number-of-gatling-load-testing)
		- [Configure Cloud Storage Provider](#configure-cloud-storage-provider)
			- [Set Amazon S3 as Cloud Storage](#set-amazon-s3-as-cloud-storage)
			- [Set Different from Amazon S3 Provider as Cloud Storage](#set-different-from-amazon-s3-provider-as-cloud-storage)
			- [Set Google Cloud Storage as Cloud Storage](#set-google-cloud-storage-as-cloud-storage)
			- [Set Azure Blob Storage as Cloud Storage](#set-azure-blob-storage-as-cloud-storage)
		- [Configure Notification Service Provider](#configure-notification-service-provider)
			- [Set Slack as Notification Service](#set-slack-as-notification-service)

<!-- /TOC -->

The Gatling Operator User Guide introduce how to configure and deploy Gatling load testing and lifecycle of a distributed Gatling load testing.

For the installation of Gatling Operator, please check [Quick Start Guide](quickstart-guide.md).

## Configuration Overview

Here are 2 major configurations you would make as a Gatling operator user:

- Gatling load testing
  - Gatling load testing runs in Gatling runner container which is created as a part of the lifecycle of distributed Gatling load testing. It involves Gatling load testing related files as well as Gatling base docker image. Please check [Gatling Load Testing Configuration and Deployment](#gatling-load-testing-configuration-and-deployment) for the details.
- Lifecycle of a distributed Gatling load testing
  - You define the desired state of a distributed Gatling load testing in `Gatling CR`, based on which Gatling Controller manages a lifecycle of the distributed Gatling load testing. Please check [Gatling Custom Resource Examples](#gatling-custom-resource-examples) for the details.

## Gatling Load Testing Configuration and Deployment

As described in Configuration Overview, there are 2 things that you need to consider in configuring Gatling load testing:

- `Gatling docker image` that includes Java Runtime and Gatling standalone bundle package at minimum
- `Gatling load testing related files` such as Gatling scenario (simulation), external resources, Gatling runtime configuration files, etc.

For `Gatling docker image`, you can use default image `ghcr.io/st-tech/gatling:latest`, or you can create custom image to use.

For `Gatling load testing related files`, you have 4 options:

- Create custom image to bundle Gatling load testing files with Java runtime and Gatling standalone bundle package
- Create custom image to bundle all Gatling related files with a gradle gatling plugin
- Add Gatling load testing files as multi-line definitions in `.spec.testScenatioSpec` part of `Gatling CR`
- Set up persistent volume in `.persistentVolume` and `.persistentVolumeClaim` in `Gatling CR` and load test files from the persistent volume in Gatling load test files.

### Create Custom Gatling Image to bundle Gatling Load Testing Files

As explained previously, you can use a default image `ghcr.io/st-tech/gatling:latest`.

Here are files included in the default Gatling docker image:

```bash
git clone https://github.com/st-tech/gatling-operator.git
cd gatling-operator
tree gatling

gatling
├── Dockerfile                        # Default Dockerfile
├── conf
│   ├── gatling.conf                  # Default Gatling runtime configuration
│   └── logback.xml                   # Default logback configuration
└── user-files
    ├── resources
    │   └── myresources.csv           # Default external resource file
    └── simulations
        └── MyBasicSimulation.scala   # Default simulation file (MyBasicSimulation)
```

Suppose that you want to customize Gatling docker image by adding new simulation file (`YourSimulation.scala`) and its relevant external resource file (`yourresources.csv`), you can do like this:

```bash
# Add your simulation file
add YourSimulation.scala gatling/user-files/simulations
# Add your external resource file
add yourresources.csv gatling/user-files/resources

# Build Docker image
cd gatling
docker build -t <your-registry>/gatling:<tag> .
# Push the image to your container registry
docker push <your-registry>/gatling:<tag>
```
📝 Ensure that you're logged into your docker container registry

Alternatively you can build and push the Gatling image by using `make` commands:

```bash
# Build Docker image
make sample-docker-build SAMPLE_IMG=<your-registry>/gatling:<tag>
# Push the image to your container registry
make sample-docker-push SAMPLE_IMG=<your-registry>/gatling:<tag>
```

📝 You can see all pre-defined commands by executing `make help` or just checking [Makefile](https://github.com/st-tech/gatling-operator/blob/main/Makefile)

After the image is pushed to the registry, you can run the image like this to see how it works:

```bash
docker run -it "<your-registry>/gatling:<tag>" 
```

<details><summary>Sample output</summary>
<p>

```txt
GATLING_HOME is set to /opt/gatling
Choose a simulation number:
     [0] MyBasicSimulation
     [1] YourSimulation
1
Select run description (optional)

Simulation YourSimulation started...

================================================================================
2022-02-13 23:21:28                                           5s elapsed        
---- Requests ------------------------------------------------------------------
> Global                                                   (OK=10     KO=0     )
> request_1                                                (OK=5      KO=0     )
> request_1 Redirect 1                                     (OK=5      KO=0     )
                                                                                                                             
---- Scenario Name -------------------------------------------------------------
[-------------------------------------                                     ]  0%
          waiting: 5      / active: 5      / done: 0                                                                         
================================================================================

...omit...

================================================================================
2022-02-13 23:21:46                                          22s elapsed
---- Requests ------------------------------------------------------------------
> Global                                                   (OK=60     KO=0     )
> request_1                                                (OK=10     KO=0     )
> request_1 Redirect 1                                     (OK=10     KO=0     )
> request_2                                                (OK=10     KO=0     )
> request_3                                                (OK=10     KO=0     )
> request_4                                                (OK=10     KO=0     )
> request_4 Redirect 1                                     (OK=10     KO=0     )

---- Scenario Name -------------------------------------------------------------
[##########################################################################]100%
          waiting: 0      / active: 0      / done: 10    
================================================================================

Simulation MyBasicSimulation completed in 22 seconds
Parsing log file(s)...
Parsing log file(s) done
Generating reports...
```

</p>
</details>

Finally, specify the image in `.spec.podSpec.gatlingImage` of Gatling CR to use it in your distributed load testing.

```yaml
apiVersion: gatling-operator.tech.zozo.com/v1alpha1
kind: Gatling
metadata:
  name: gatling-sample01
spec:
  podSpec:
    serviceAccountName: "gatling-operator-worker"
    gatlingImage: <your-registry>/gatling:<tag>
...omit...
```

### Create Custom Gatling Image with Gradle Gatling plugin

Example project can be found [here](https://github.com/gatling/gatling-gradle-plugin-demo-kotlin).

Let's start with cloning the repo:
```bash
git clone git@github.com:gatling/gatling-gradle-plugin-demo-kotlin.git
cd gatling-gradle-plugin-demo-kotlin
```

In order to run this example on Gatling Operator, we have to build a custom docker image with both gradle and gatling baked in.

Let's create a `Dockerfile` in the root directory of the `gatling-gradle-plugin-demo-kotlin` project:
```bash
FROM azul/zulu-openjdk:21-latest

# dependency versions
ENV GATLING_VERSION 3.10.5
ENV GRADLE_VERSION 8.7

# install gatling
RUN mkdir /opt/gatling && \
  apt-get update && apt-get upgrade -y && apt-get install -y wget unzip &&  \
  mkdir -p /tmp/downloads && \
  wget -q -O /tmp/downloads/gatling-$GATLING_VERSION.zip \
  https://repo1.maven.org/maven2/io/gatling/highcharts/gatling-charts-highcharts-bundle/$GATLING_VERSION/gatling-charts-highcharts-bundle-$GATLING_VERSION-bundle.zip && \
  mkdir -p /tmp/archive && cd /tmp/archive && \
  unzip /tmp/downloads/gatling-$GATLING_VERSION.zip && \
  mv /tmp/archive/gatling-charts-highcharts-bundle-$GATLING_VERSION/* /opt/gatling/ && \
  rm -rf /opt/gatling/user-files/simulations/computerdatabase /tmp/*

# install gradle
RUN mkdir /opt/gradle && \
    wget -q -O /tmp/gradle-$GRADLE_VERSION.zip https://services.gradle.org/distributions/gradle-$GRADLE_VERSION-bin.zip && \
    unzip -d /opt/gradle /tmp/gradle-$GRADLE_VERSION.zip && \
    rm -rf /tmp/*

# change context to gatling directory
WORKDIR  /opt/gatling

# copy gradle files to gatling directory
COPY . .

# set environment variables
ENV PATH /opt/gatling/bin:/opt/gradle/gradle-$GRADLE_VERSION/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV GATLING_HOME /opt/gatling

ENTRYPOINT ["gatling.sh"]
```

Now we have to build the custom image:
```bash
# Build Docker image
docker build -t <your-registry>/gatling:<tag> .
# Push the image to your container registry
docker push <your-registry>/gatling:<tag>
```

Finally, specify the image in `.spec.podSpec.gatlingImage` of Gatling CR and change the value of property `testScenarioSpec.simulationsFormat` to use it in your distributed load testing.

```yaml
apiVersion: gatling-operator.tech.zozo.com/v1alpha1
kind: Gatling
metadata:
  name: gatling-gradle
spec:
  podSpec:
    serviceAccountName: "gatling-operator-worker"
    gatlingImage: <your-registry>/gatling:<tag>
  testScenarioSpec:
    simulationsFormat: gradle
...omit...
```

### Add Gatling Load Testing Files in Gatling CR

As explained previously, instead of bundling Gatling load testing files in the Gatling docker image, you can add them as multi-line definitions in `.spec.testScenatioSpec` of `Gatling CR`, based on which Gatling Controller automatically creates `ConfigMap` resources and injects Gatling runner Pod with the files.

You can add a Gatling simulation file (scala), an external resource file, and Gatling runtime config file (gatling.conf) respectively in `.spec.testScenarioSpec.simulationData`, `.spec.testScenarioSpec.resourceData`, and `.spec.testScenarioSpec.gatlingConf` like this:

```yaml
apiVersion: gatling-operator.tech.zozo.com/v1alpha1
kind: Gatling
metadata:
  name: gatling-sample
spec:
  testScenarioSpec:
    simulationData:
      MyBasicSimulation.scala: |
        # Add Gatling simulation file (scala) as multi-line
    resourceData:
      sample.csv: |
        # Add external resource file as multi-line 
    gatlingConf:
      gatling.conf: |
        # Add gatling.conf as multi-line
```

For a full sample manifest, please check [this](../config/samples/gatling-operator_v1alpha1_gatling02.yaml).

📝 **Caution**: Please be noted that the data stored in a ConfigMap cannot exceed 1 MiB (ref [this](https://kubernetes.io/docs/concepts/configuration/configmap/)). If you need to store files that are larger than this limit, you may want to consider create Custom Gatling Image to bundle them in the container.

### Read Gatling Load Testing Files from PersistentVolume

You can place Gatling load testing files in a [Kubernetes persistent volume](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) and read them from there. When you configure the required settings in `.spec.persistentVolume` and `.spec.persistentVolumeClaim`, Gatling Controller automatically creates the `PersistentVolume` and `PersistentVolumeClaim` resources in the cluster.

If you're configuring Amazon EFS as a persistent volume, like this:
```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com

---

apiVersion: gatling-operator.tech.zozo.com/v1alpha1
kind: Gatling
metadata:
  name: gatling-sample
spec:
  podSpec:
    volumes:
      - name: efs-vol
        persistentVolumeClaim:
          claimName: efs-pvc
  persistentVolume:
    name: efs-pv
    spec:
      capacity:
        storage: 1Gi
      accessModes:
        - ReadWriteMany
      storageClassName: efs-sc
      csi:
        driver: efs.csi.aws.com
        volumeHandle: fs-xxxxxx
  persistentVolumeClaim:
    name: efs-pvc
    spec:
      accessModes:
        - ReadWriteMany
      storageClassName: efs-sc
      resources:
        requests:
          storage: 1Gi
  testScenarioSpec:
    volumeMounts:
      - name: efs-vol
        mountPath: /opt/gatling/user-files
```

Assuming that `StorageClass` resources is created in advance, and if `PersistentVolume` resources are also created in advance, configuring only `podSec.volumes` and `testScenarioSpec.volumeMounts` settings will be sufficient for operation.

### Debug and Trace Gatling Load Testing

As you can see in the section of [Create Custom Gatling Image to bundle Gatling Load Testing Files](#create-custom-gatling-image-to-bundle-gatling-load-testing-files), you can check the logging output of each Gatling load testing via container log. But if you want to know more details on what's going on in Gatling load testing, you can leverage `logback.xml`.
You can debug Gatling with `logback.xml` which is supposed to be located in the Gatling conf directory (see [gatling/conf/logback.xml](https://github.com/st-tech/gatling-operator/blob/main/gatling/conf/logback.xml)).

For example, here is default logback configuration which allows to print debugging information to the console.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>

	<appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
		<encoder>
			<pattern>%d{HH:mm:ss.SSS} [%-5level] %logger{15} - %msg%n%rEx</pattern>
		</encoder>
		<immediateFlush>false</immediateFlush>
	</appender>

	<root level="WARN">
		<appender-ref ref="CONSOLE" />
	</root>

</configuration>
```

You add the following tag in order to log all HTTP requests and responses.

```xml
<logger name="io.gatling.http.engine.response" level="TRACE" />
```
To know more on logback configuration in Gatling, please check [the Gatling official guide](https://gatling.io/docs/gatling/guides/debugging/).

Once you finish updating `logback.xml`, you rebuild the Gatling image and push it to your registry, so you can use the image in your Gatling load testing.


### How to Pull Gatling Runtime Image from Private Registry

Currently Adding `imagePullSecret` definition to Gatling CR isn't supported. But there is a workaround to pull the image from private registry. 

Here is a procedure:

#### Create an "image pull secret"

First of all, create an "image pull secret" in the namespace to which you deploy your Gatling CR. Suppose you want to deploy the Gatling CR named `gatling-sample01'` on `default` namespace, create an "image pull secret" like this:

```bash
PASS=xxxxxx
NAMESPACE=default
kubectl create secret docker-registry mysecret --docker-server=<registry server name> --docker-username=<registry-accout-name> --docker-password=$PASS --docker-email=your@mail.com -n $NAMESPACE
```

As a result, the image pull secret named `mysecret` will be created on `default` namespace

#### Add ImagePullSecrets to your service account

Secondly, add imagePullSecrets to your service account. Suppose you define the service account named `gatling-operator-worker` in your Gatling CR, modify the `gatling-operator-worker` service account for the namespace to use the secret as an imagePullSecret like this:

```bash
NAMESPACE=default
kubectl patch serviceaccount gatling-operator-worker -p "{\"imagePullSecrets\": [{\"name\": \"mysecret\"}]}" -n $NAMESPACE
```

Now you're ready to deploy your galting CR where private image is defined.

```yaml
apiVersion: gatling-operator.tech.zozo.com/v1alpha1
kind: Gatling
metadata:
  name: gatling-sample01
spec:
  generateReport: false
  generateLocalReport: false
  notifyReport: false
  cleanupAfterJobDone: true
  podSpec:
    serviceAccountName: "gatling-operator-worker"
    gatlingImage: myPriveteRepo.io/foo:latest
```

Here are the relevant pages:
- https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ 
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#add-imagepullsecrets-to-a-service-account

## Gatling Custom Resource Examples

You can configure the various features and parameters of the distributed Gatling load testing using Gatling CR.

Gatling CR largely defines the following five:

```yaml
apiVersion: gatling-operator.tech.zozo.com/v1alpha1
kind: Gatling
metadata:
  name: gatling-sample
spec:

  ## (1) Flags for execution phases
  generateReport: true
  notifyReport: true
  cleanupAfterJobDone: true

  ## (2) Spec for Gatling Runner Pod
  podSpec:
  ## (3) Spec for Cloud Storage Provider to store Gatling reports
  cloudStorageSpec:
  ## (4) Spec for Notification Service Provider to notify Gatling load testing result 
  notificationServiceSpec:
  ## (5) Spec for Gatling load testing scenario and how it's executed
  testScenarioSpec:
```

Please check the rest of the section and [Gatling CRD Reference](../docs/api.md) for more details on the Gatling CR configuration.

### Choose Execution Phases

You can choose if each of the following phases in distributed Gatling load testing to execute by setting their relevant flags:

```yaml
apiVersion: gatling-operator.tech.zozo.com/v1alpha1
kind: Gatling
metadata:
  name: gatling-sample
spec:
  generateReport: true
  generateLocalReport: true
  notifyReport: true
  cleanupAfterJobDone: true
```

- `.spec.generateReport`: It's an optional flag of generating an aggregated Gatling report and defaults to false. You must configure `.spec.cloudStorageSpec` as well if the flag is set to true.
- `.spec.generateLocalReport`: It's an optional flag of generating Gatling report at each Pod and defaults to false.
- `.spec.notifyReport`: It's an optional flag of notifying Gatling report and defaults to false. You must configure `.spec.notificationServiceSpec` as well if the flag is set to true.
- `.spec.cleanupAfterJobDone`: It's an optional flag of cleanup Gatling resources after the job done and defaults to false. Please set the flag to true if you want to dig into logs of each Pod even after the job done.

### Configure Gatling Runner Pod

You can configure various attributions of Gatling runner Pod in `.spec.podSpec`.

#### Resource Allocation and Scheduling for Gatling Runner Pod

You can set CPU and RAM resource allocation for the Pod. Also you can set affinity (such as Node affinity) and tolerations to be used by the scheduler to decide where the Pod can be placed in the cluster like this:

```yaml
apiVersion: gatling-operator.tech.zozo.com/v1alpha1
kind: Gatling
metadata:
  name: gatling-sample01
spec:
  podSpec:
    serviceAccountName: gatling-operator-worker
    gatlingImage: ghcr.io/st-tech/gatling:latest
    rcloneImage: rclone/rclone
    resources:
      limits:
        cpu: "500m"
        memory: "500Mi"
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: kubernetes.io/os
                  operator: In
                  values:
                    - linux
    tolerations:
      - key: "node-type"
        operator: "Equal"
        value: "non-kube-system"
        effect: "NoSchedule"
```

You also can set container images for Gatling load testing and rclone respectively in `.spec.podSpec.gatlingImage` and `.spec.podSpec.rcloneImage`.

- `.spec.podSpec.gatlingImage`: It's an optional field for Gatling load testing container image and defaults to `ghcr.io/st-tech/gatling:latest`. You can add your custom image here.
- `.spec.podSpec.rcloneImage`: It's an optional field for [rclone](https://rclone.org/) container image and defaults to `rclone/rclone:latest`. The rclone is used for uploading Gatling report files to and downloading them from Cloud Storages. You can add your custom image here.

#### Service Account for Gatling Runner Pod

You must set service account for the Pod in `.spec.serviceAccountName` and configure its permission as it's necessary for the Gatling runner Pod (actually `gatling-waiter` container in the Pod) to adjust the timing of load testing start.

Suppose you want to set a service account named `gatling-operator-worker` in `.spec.serviceAccountName` like the example above and deploy the Gatling CR into the default namespace (`default`), you must apply the following permissions into the same namespace (`default`).

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gatling-operator-worker
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
subjects:
  - kind: ServiceAccount
    name: gatling-operator-worker
    apiGroup: ""
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: ""
```

Please check an [example manifest for service account permissions](../config/samples/gatling-worker-service-account.yaml) too.

### Configure Gatling Load Testing Scenario and How It's Executed

You can configure Gatling load testing scenario and how it's executed in `.spec.testScenatioSpec`.

#### Start Time of Gatling Load Testing

In `.spec.testScenarioSpec.startTime` you can set start time for Gatling load testing to start running. You're supposed to set the time in UTC and in a format of `%Y-%m-%d %H:%M:%S`.

```yaml
apiVersion: gatling-operator.tech.zozo.com/v1alpha1
kind: Gatling
metadata:
  name: gatling-sample
spec:
  testScenarioSpec:
    startTime: 2022-01-01 12:00:00
```

#### Parallel Number of Gatling Load Testing

You can set parallel number of Gatling load testing in `.spec.testScenarioSpec.parallelism`. The Gatling Controller use the value to set the parallelism of Gatling Runner Job.

```yaml
apiVersion: gatling-operator.tech.zozo.com/v1alpha1
kind: Gatling
metadata:
  name: gatling-sample
spec:
  testScenarioSpec:
    parallelism: 4
```

### Configure Cloud Storage Provider

In `.spec.cloudStorageSpec` you can configure Cloud Storage Provider for storing Gatling reports. Here are main fields to set in `.spec.cloudStorageSpec`:

- `.spec.cloudStorageSpec.provider`: It's a required field for the cloud storage provider to use. Supported values on the field are `aws` (for [Amazon S3](https://aws.amazon.com/s3/)), `gcp` (for [Google Cloud Storage](https://cloud.google.com/products/storage)), or `azure` (for [Azure Blob Storage](https://azure.microsoft.com/en-us/services/storage/blobs/)).
- `.spec.cloudStorageSpec.bucket`: It's a required field for the name of storage bucket.
- `.spec.cloudStorageSpec.region`: It's an optional field for the name of region that the cloud storage belong to.

#### Set Amazon S3 as Cloud Storage

Suppose that you want to store Gatling reports to a bucket named `gatling-operator-reports` of Amazon S3 located in `ap-northeast-1` region, you configure each fields in `.spec.cloudStorageSpec` like this:

```yaml
apiVersion: gatling-operator.tech.zozo.com/v1alpha1
kind: Gatling
metadata:
  name: gatling-sample
spec:
  cloudStorageSpec:
    provider: "aws"
    bucket: "gatling-operator-reports"
    region: "ap-northeast-1"
```

However, this is not enough. You must supply Gatling Pod (both Gatling Runner Pod and Gatling Reporter Pod) with AWS credentials to access Amazon S3. Strictly speaking, [rclone](https://rclone.org/) container in Gatling Pod interacts with Amazon S3, thus you need to supply rclone with AWS credentials.

There are multiple authentication methods that can be tried.

(1) Setting S3 Access Key ID and Secret Access Key with the following environment variables

- Access Key ID: `AWS_ACCESS_KEY_ID` or `AWS_ACCESS_KEY`
- Secret Access Key: `AWS_SECRET_ACCESS_KEY` or `AWS_SECRET_KEY`

```yaml
  cloudStorageSpec:
    provider: "aws"
    bucket: "gatling-operator-reports"
    region: "ap-northeast-1"
    env:
      - name: AWS_ACCESS_KEY_ID
        value: xxxxxxxxxxxxxxx
      - name: AWS_SECRET_ACCESS_KEY
        valueFrom:
          secretKeyRef:
            name: aws-credential-secrets
            key: AWS_SECRET_ACCESS_KEY
```

(2) Attaching an IAM role to Node Group on which EKS Pod runs or a Kubernetes service account that is attached to EKS Pod (This is only for AWS)

Here is an IAM policy to attach for Gatling Pod to interact with Amazon S3 bucket:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:DeleteObject",
                "s3:GetObject",
                "s3:PutObject",
                "s3:PutObjectAcl"
            ],
            "Resource": [
              "arn:aws:s3:::BUCKET_NAME/*",
              "arn:aws:s3:::BUCKET_NAME"
            ]
        }
    ]
}
```

- Replace `BUCKET_NAME` above with your bucket name
- To know more about the ways to supply rclone with a set of AWS credentials, please check [this](https://rclone.org/s3/#configuration).

#### Set Different from Amazon S3 Provider as Cloud Storage

This section provides guidance on setting up any cloud storage provider that supports the S3 API.
In this example suppose you want to store Gatling reports to a bucket named `gatling-operator-reports` in OHV's S3 provider, specifically in the `de` region. 
You configure each fields in `.spec.cloudStorageSpec` and set `RCLONE_S3_ENDPOINT` env like this:

```yaml
apiVersion: gatling-operator.tech.zozo.com/v1alpha1
kind: Gatling
metadata:
  name: gatling-sample
spec:
  cloudStorageSpec:
    provider: "s3"
    bucket: "gatling-operator-reports"
    region: "de"
    env:
      - name: RCLONE_S3_ENDPOINT
        value: https://s3.de.io.cloud.ovh.net
...omit...
```

However, this is not enough. You must supply Gatling Pod (both Gatling Runner Pod and Gatling Reporter Pod) with credentials to access S3 bucket. Strictly speaking, [rclone](https://rclone.org/) container in Gatling Pod interacts with S3 bucket, thus you need to supply rclone with credentials.

Below is shown how to set S3 credentials via environment variables:

```yaml
...omit...
  cloudStorageSpec:
    provider: "s3"
    bucket: "gatling-operator-reports"
    region: "de"
    env:
      - name: RCLONE_S3_PROVIDER
        value: Other
      - name: RCLONE_S3_ACCESS_KEY_ID
        valueFrom:
          secretKeyRef:
            name: s3-keys
            key: S3_ACCESS_KEY
      - name: RCLONE_S3_SECRET_ACCESS_KEY
        valueFrom:
        secretKeyRef:
          name: s3-keys
          key: S3_SECRET_ACCESS
      - name: RCLONE_S3_ENDPOINT
        value: https://s3.de.io.cloud.ovh.net
      - name: RCLONE_S3_REGION
        value: de
...omit...
```

There are multiple ways to authenticate for more please check [this](https://rclone.org/s3/#configuration).

#### Set Google Cloud Storage as Cloud Storage

Suppose that you want to store Gatling reports to a bucket named `gatling-operator-reports` of Google Cloud Storage, you configure each fields in `.spec.cloudStorageSpec` like this:

```yaml
apiVersion: gatling-operator.tech.zozo.com/v1alpha1
kind: Gatling
metadata:
  name: gatling-sample
spec:
  cloudStorageSpec:
    provider: "gcp"
    bucket: "gatling-operator-reports"
```

Please make sure to supply Gatling Pod (both Gatling Runner Pod and Gatling Reporter Pod) with access permissions to the bucket.

#### Set Azure Blob Storage as Cloud Storage

Suppose that you want to store Gatling reports to a container named `gatling-operator-reports` of Azure Blob Storage, you can configure `.spec.cloudStorageSpec` to make it happen with multiple authentication methods.

(1) Setting Azure Blob Account and Key with the following environment variables

- Azure Blob Storage Account Name: `AZUREBLOB_ACCOUNT`
- Azure Blob Storage Key: `AZUREBLOB_KEY`

```yaml
  cloudStorageSpec:
    provider: "azure"
    bucket: "gatling-operator-reports"
    env:
      - name: AZUREBLOB_ACCOUNT
        value: <Azure Blob Storage Acccout Name>
      - name: AZUREBLOB_KEY
        valueFrom:
          secretKeyRef:
            name: azure-credentail-secrets
            key: AZUREBLOB_KEY
```

Please leave blank `AZUREBLOB_KEY` if you use SAS URL

(2) Setting Azure Blob Account and SAS (Shared Access Signatures) URL with the following environment variable

- Azure Blob Storage Account Name: `AZUREBLOB_ACCOUNT`
- SAS (Shared Access Signatures) URL: `AZUREBLOB_SAS_URL`

An account level SAS URL or container level SAS URL can be obtained from the Azure portal or the Azure Storage Explorer. Please make sure that `Read`, `Write` and `List` permissions are given to the SAS. Please check [Create SAS tokens for storage containers](https://docs.microsoft.com/en-us/azure/applied-ai-services/form-recognizer/create-sas-tokens) for more details.

```yaml
  cloudStorageSpec:
    provider: "azure"
    bucket: "gatling-operator-reports"
    env:
      - name: AZUREBLOB_ACCOUNT
        value: <Azure Blob Storage Acccout Name>
      - name: AZUREBLOB_SAS_URL
        value: "https://<account-name>.blob.core.windows.net/gatling-operator-reports?<sas-token-params>"
```

### Configure Notification Service Provider

In `.spec.notificationServiceSpec` you can configure Notification Service Provider to which you post webhook message in order to notify Gatling load testing result. Here are main fields to set in `.spec.notificationServiceSpec`.

- `.spec.notificationServiceSpec.provider`: It's a required field for the notification service provider to use. Supported value on the field is currently `slack` (for [Slack](https://slack.com/)) only.
- `.spec.cloudStorageSpec.secretName`: It's a required field for the name of Kubernetes Secret that contains all key/value sets needed for posting webhook message to the provider.

#### Set Slack as Notification Service

Suppose that you want to notify Gatling load testing result via Slack and you store credential info (Slack webhook URL) in Kubernetes Secret named `gatling-notification-slack-secrets`, you configure each fields in `.spec.notificationServiceSpec` like this:

```yaml
apiVersion: gatling-operator.tech.zozo.com/v1alpha1
kind: Gatling
metadata:
  name: gatling-sample
spec:
  notificationServiceSpec:
    provider: "slack"
    secretName: "gatling-notification-slack-secrets"
```

In the Secret you need to set Slack webhook URL value (in base64 encoded string) for a Slack channel to which you want to deliver the message. The key name for the Slack webhook URL must be `incoming-webhook-url`.

```yaml
apiVersion: v1
data:
  incoming-webhook-url: <base64 encoded Webhook-URL string>
kind: Secret
metadata:
  name: gatling-notification-slack-secrets
type: Opaque
```
Please check an [example manifest for the Secret](https://github.com/st-tech/gatling-operator/blob/main/config/samples/gatling-notification-slack-secrets.yaml) too.
