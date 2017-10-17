/*
Copyright 2015 All rights reserved.
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package s3

import (
	"fmt"
	"log"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/awserr"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/pkg/errors"
)

// Bucket is the s3 bucket type
type Bucket struct {
	Name string
}

// List will list all s3 buckets
func List() {

	log.Println("will list s3 buckets")
}

// Empty will remove all versioned objects from an s3 bucket
func (s Bucket) Empty() error {

	log.Printf("will empty all versioned objects from bucket: %v\n", s.Name)

	// step: aquire aws client and read creds

	// step: get a slice of all objects to delete
	vobj, err := getVersObj(s.Name)
	if err != nil {
		return errors.Wrap(err, "error while gathering versioned objects")
	}
	log.Printf("found %v objects\n", len(vobj))

	// fmt.Printf("%#v\n", vobj)
	// step: delete objects to empty bucket
	delVersObj(vobj, s.Name)

	return nil
}

// vKey serves as the type to gather all key:versionid pairs for versioned buckets
type vKey struct {
	key       string
	versionID string
}

// getVersObj retrieves all versioned objects from an s3 bucket
func getVersObj(bucketName string) ([]vKey, error) {
	log.Printf("finding  all versioned objects in bucket: %s", bucketName)
	// func s3GetListVersionedKeys(bucketName string, s3prop S3obj) ([]vKey, error) {
	var empty []vKey
	var vkeys []vKey

	sess := session.Must(
		session.NewSession(
			&aws.Config{
				Region: aws.String("eu-west-1"),
			},
		),
	)
	svc := s3.New(sess)
	params := &s3.ListObjectVersionsInput{
		Bucket:  aws.String(bucketName), // Required
		MaxKeys: aws.Int64(500),
	}
	resp, err := svc.ListObjectVersions(params)
	if err != nil {
		if aerr, ok := err.(awserr.Error); ok {
			log.Printf("code:%v\nerror:%v\nmessage:%v\noriginalErr:%v\n", aerr.Code(), aerr.Error(), aerr.Message(), aerr.OrigErr())
			switch aerr.Code() {
			case "NoSuckBucket":
				errm := fmt.Sprintf("An error (%v) has occured for bucket %v: when calling ListObjectVersions %v", aerr.Code(), bucketName, aerr.Message())
				return empty, errors.New(errm)
			case "BucketRegionError":
				errm := fmt.Sprintf("An error (%v) has occured for bucket %v: when calling ListObjectVersions %v", aerr.Code(), bucketName, aerr.Message())
				return empty, errors.New(errm)
			case "InvalidBucketName":
				errm := fmt.Sprintf("An error (%v) has occured for bucket %v: when calling ListObjectVersions %v. Please drop the s3:// prefix", aerr.Code(), bucketName, aerr.Message())
				return empty, errors.New(errm)
			default:
				errm := fmt.Sprintf("A generic s3BucketError (%v) has occured for bucket %v: when calling ListObjectVersions %v", aerr.Code(), bucketName, aerr.Message())
				return empty, errors.New(errm)
			}
		}
	}

	log.Printf("gathering all versioned keys in the bucket: %v", bucketName)
	for vk := range resp.Versions {
		var vke vKey
		vke.key = *resp.Versions[vk].Key
		vke.versionID = *resp.Versions[vk].VersionId
		vkeys = append(vkeys, vke)
	}

	log.Printf("gathering all delete markers in the bucket: %v", bucketName)
	for dm := range resp.DeleteMarkers {
		var dme vKey
		dme.key = *resp.DeleteMarkers[dm].Key
		dme.versionID = *resp.DeleteMarkers[dm].VersionId
		vkeys = append(vkeys, dme)
	}

	return vkeys, nil
}

// delVersObj deletes all versioned s3 objects from a bucket
func delVersObj(keys []vKey, bucketName string) error {

	var objects []*s3.ObjectIdentifier

	if len(keys) == 0 {
		log.Printf("nothing to delete, bucket %v contains %v objects", bucketName, len(keys))
		return nil
	}
	sess := session.Must(
		session.NewSession(
			&aws.Config{
				Region: aws.String("eu-west-1"),
			},
		),
	)
	svc := s3.New(sess)

	// construct the list of ObjectIdentifiers
	for k := range keys {
		var obj s3.ObjectIdentifier
		obj.Key = &keys[k].key
		obj.VersionId = &keys[k].versionID
		objects = append(objects, &obj)
	}
	// s3pkgCtxLogger.Debugf("bucket:%v with versioned list of objects to be deleted %#v", bucketName, objects)

	params := &s3.DeleteObjectsInput{
		Bucket: aws.String(bucketName), // Required
		Delete: &s3.Delete{ // Required
			Objects: objects,
			Quiet:   aws.Bool(true),
		},
	}

	log.Printf("will delete %v versioned objects", len(keys))
	_, errdo := svc.DeleteObjects(params)

	if errdo != nil {
		return errors.Wrap(errdo, "unable to delete objects from versioned bucket")
	}
	return nil
}
