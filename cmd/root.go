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
