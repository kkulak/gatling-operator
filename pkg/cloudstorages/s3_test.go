package cloudstorages

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("GetName", func() {
	var (
		provider      string
		expectedValue string
	)
	BeforeEach(func() {
		provider = "aws"
		expectedValue = "aws"
	})
	Context("Provider is aws", func() {
		It("should get provider name = aws", func() {
			csp := &S3CloudStorageProvider{providerName: provider}
			Expect(csp.GetName()).To(Equal(expectedValue))
		})
	})
})

var _ = Describe("GetCloudStoragePath", func() {
	var (
		provider      string
		bucket        string
		gatlingName   string
		subDir        string
		expectedValue string
	)
	BeforeEach(func() {
		provider = "aws"
		bucket = "testBucket"
		gatlingName = "testGatling"
		subDir = "subDir"
		expectedValue = "s3:testBucket/testGatling/subDir"
	})
	Context("Provider is aws", func() {
		It("path is aws s3 bucket", func() {
			csp := &S3CloudStorageProvider{providerName: provider}
			Expect(csp.GetCloudStoragePath(bucket, gatlingName, subDir)).To(Equal(expectedValue))
		})
	})
})

var _ = Describe("GetCloudStorageReportURL", func() {
	var (
		provider    string
		bucket      string
		gatlingName string
		subDir      string
	)
	BeforeEach(func() {
		provider = "s3"
		bucket = "testBucket"
		gatlingName = "testGatling"
		subDir = "subDir"
	})
	Context("Provider is s3", func() {
		It("path is aws s3 bucket if RCLONE_S3_ENDPOINT not defined", func() {
			csp := &S3CloudStorageProvider{providerName: provider}
			Expect(csp.GetCloudStorageReportURL(bucket, gatlingName, subDir)).To(Equal("https://testBucket.s3.amazonaws.com/testGatling/subDir/index.html"))
		})

		It("path is S3 bucket with custom provider endpoint", func() {
			csp := &S3CloudStorageProvider{providerName: provider}
			csp.init([]EnvVars{
				{
					{
						Name:  "RCLONE_S3_ENDPOINT",
						Value: "https://s3.de.io.cloud.ovh.net",
					},
				},
			})
			Expect(csp.GetCloudStorageReportURL(bucket, gatlingName, subDir)).To(Equal("https://testBucket.s3.de.io.cloud.ovh.net/testGatling/subDir/index.html"))
		})
	})

})

var _ = Describe("GetGatlingTransferResultCommand", func() {
	var (
		provider             string
		resultsDirectoryPath string
		region               string
		storagePath          string
		expectedValue        string
	)
	BeforeEach(func() {
		provider = "aws"
		resultsDirectoryPath = "testResultsDirectoryPath"
		region = "ap-northeast-1"
		storagePath = "testStoragePath"
		expectedValue = `
RESULTS_DIR_PATH=testResultsDirectoryPath
rclone config create s3 s3 env_auth=true region ap-northeast-1
while true; do
  if [ -f "${RESULTS_DIR_PATH}/FAILED" ]; then
    echo "Skip transfering gatling results"
    break
  fi
  if [ -f "${RESULTS_DIR_PATH}/COMPLETED" ]; then
    for source in $(find ${RESULTS_DIR_PATH} -type f -name *.log)
    do
      rclone copyto ${source} --s3-no-check-bucket --s3-env-auth testStoragePath/${HOSTNAME}.log
    done
    break
  fi
  sleep 1;
done
`
	})
	Context("Provider is aws", func() {
		It("returns commands with s3 rclone config", func() {
			csp := &S3CloudStorageProvider{providerName: provider}
			Expect(csp.GetGatlingTransferResultCommand(resultsDirectoryPath, region, storagePath)).To(Equal(expectedValue))
		})
	})
})

var _ = Describe("GetGatlingAggregateResultCommand", func() {
	var (
		provider             string
		resultsDirectoryPath string
		region               string
		storagePath          string
		expectedValue        string
	)
	BeforeEach(func() {
		provider = "aws"
		resultsDirectoryPath = "testResultsDirectoryPath"
		region = "ap-northeast-1"
		storagePath = "testStoragePath"
		expectedValue = `
GATLING_AGGREGATE_DIR=testResultsDirectoryPath
rclone config create s3 s3 env_auth=true region ap-northeast-1
rclone copy --s3-no-check-bucket --s3-env-auth testStoragePath ${GATLING_AGGREGATE_DIR}
`
	})
	Context("Provider is aws", func() {
		It("returns commands with s3 rclone config", func() {
			csp := &S3CloudStorageProvider{providerName: provider}
			Expect(csp.GetGatlingAggregateResultCommand(resultsDirectoryPath, region, storagePath)).To(Equal(expectedValue))
		})
	})
})

var _ = Describe("GetGatlingTransferReportCommand", func() {
	var (
		provider             string
		resultsDirectoryPath string
		region               string
		storagePath          string
		expectedValue        string
	)
	BeforeEach(func() {
		provider = "aws"
		resultsDirectoryPath = "testResultsDirectoryPath"
		region = "ap-northeast-1"
		storagePath = "testStoragePath"
		expectedValue = `
GATLING_AGGREGATE_DIR=testResultsDirectoryPath
rclone config create s3 s3 env_auth=true region ap-northeast-1
rclone copy ${GATLING_AGGREGATE_DIR} --exclude "*.log" --s3-no-check-bucket --s3-env-auth testStoragePath
`
	})
	Context("Provider is aws", func() {
		It("returns commands with s3 rclone config", func() {
			csp := &S3CloudStorageProvider{providerName: provider}
			Expect(csp.GetGatlingTransferReportCommand(resultsDirectoryPath, region, storagePath)).To(Equal(expectedValue))
		})
	})
})
