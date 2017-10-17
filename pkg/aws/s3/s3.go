package s3

import "fmt"

// S3Bucket is the type
type Bucket struct {
	Name string
}

// List will list all s3 buckets
func (s Bucket) List() {

	fmt.Println("will list s3 buckets")
}

// Empty will remove all versioned objects from an s3 bucket
func (s Bucket) Empty() {

	fmt.Println("will empty a versioned s3 bucket, removing all objects")
}
