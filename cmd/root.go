package cmd

import (
	"github.com/pkg/errors"

	"github.com/spf13/cobra"
)

// RootCmd represents the base command when called without any subcommands
var RootCmd = &cobra.Command{
	Use:   "awsctl",
	Short: "awsctl interacts with the aws api",
	Long: `awsctl interacts with the aws api
                giving the user useful output.
                ...

                Documentation is available at http://doesnotexist.yet`,
}

//Execute adds all child commands to the root command sets flags appropriately.
func Execute() error {
	if err := RootCmd.Execute(); err != nil {
		return errors.Wrap(err, "error received when running command ")
	}
	return nil
}

var debugPtr bool

func init() {

	// flags available to all commands and subcommands
	RootCmd.PersistentFlags().BoolVarP(&debugPtr, "debug", "d", false, "turn on debug output")

}
