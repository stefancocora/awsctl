package cmd

import (
	"log"

	"github.com/spf13/cobra"
	"github.com/stefancocora/awsctl/pkg/aws/s3"
)

// s3 is the main EC2 subcommand under the root cmd
var s3Cmd = &cobra.Command{
	Use:   "s3",
	Short: "CRUD operations on AWS s3 buckets",
	Long: `Create Read Update Delete operations on s3 buckets
             Example:
             awsctl s3 ls                              # list all s3 buckets

             s3 requires a subcommand, e.g. awsctl s3 ls
             `,
	RunE: nil,
}

var s3LsPtr string
var s3LsCmd = &cobra.Command{
	Use:   "ls",
	Short: "List s3 buckets",
	Long: `List s3 buckets

             Example:
             awsctl s3 ls                               # list all ec2 key pairs

  `,
	RunE: func(cmd *cobra.Command, args []string) error {
		currCmd := cmd.Name()
		log.Printf("current cli flag: %v", currCmd)

		bk := s3.Bucket{
			Name: s3LsPtr,
		}
		bk.List()
		return nil
	},
}

var s3EmptyPtr string
var s3EmptyCmd = &cobra.Command{
	Use:   "do",
	Short: "Delete objects in an s3 bucket",
	Long: `Empties an s3 bucket deleting all objects from that bucket

             Example:
             awsctl s3 do -b abc123                # empties bucket abc123

  `,
	RunE: func(cmd *cobra.Command, args []string) error {
		currCmd := cmd.Name()
		log.Printf("current cli flag: %v", currCmd)

		bk := s3.Bucket{
			Name: s3EmptyPtr,
		}
		bk.Empty()
		return nil
	},
}

func init() {

	// flags and subcommands setup
	RootCmd.AddCommand(s3Cmd)
	s3Cmd.AddCommand(s3LsCmd)
	s3Cmd.AddCommand(s3EmptyCmd)

}
