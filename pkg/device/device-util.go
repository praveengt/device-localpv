/*
Copyright 2017 The Kubernetes Authors.

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

package device

import (
	"fmt"
	"os"

	apis "github.com/openebs/device-localpv/pkg/apis/openebs.io/device/v1alpha1"
)

// zfs related constants
const (
	DevPath = "/dev/"
)

// TODO @praveengt
func CreateVolume(vol *apis.DeviceVolume) error {

	return nil
}

// TODO @praveengt
func DestroyVolume(vol *apis.DeviceVolume) error {

}

// TODO @praveengt
func CheckVolumeExists(vol *apis.DeviceVolume) (bool, error) {
	devPath, err := GetVolumeDevPath(vol)
	if err != nil {
		return false, err
	}
	if _, err = os.Stat(devPath); err != nil {
		if os.IsNotExist(err) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

// GetVolumeDevPath return the dev path for volume
func GetVolumeDevPath(vol *apis.DeviceVolume) (string, error) {
	var deviceName string

	diskPaths, err := getDiskPathFromMetaPartition(vol)

	for _, diskPath := range diskPaths {
		deviceName, err = getPathFromPartitionName(diskPath, vol)
		if err != nil {
			// TODO
		}
		if len(deviceName) != 0 {
			break
		}
	}

	if len(deviceName) == 0 {
		return "", fmt.Errorf("no volume found")
	}

	return deviceName, err
}

// TODO @praveengt
// reads the information from partition and get all the disks which have the given name
// partitions
func getDiskPathFromMetaPartition(vol *apis.DeviceVolume) ([]string, error) {
	var disks []string

	return disks, nil
}

// TODO @praveengt
// reads all the partitions on the given disk and finds the partition with the given
// name
func getPathFromPartitionName(diskPath string, vol *apis.DeviceVolume) (string, error) {
	return "", nil
}
