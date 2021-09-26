//go:build !ignore_autogenerated
// +build !ignore_autogenerated

/*
Copyright 2021.

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

// Code generated by controller-gen. DO NOT EDIT.

package v1alpha1

import (
	runtime "k8s.io/apimachinery/pkg/runtime"
)

// DeepCopyInto is an autogenerated deepcopy function, copying the receiver, writing into out. in must be non-nil.
func (in *PreScaledCronJob) DeepCopyInto(out *PreScaledCronJob) {
	*out = *in
	out.TypeMeta = in.TypeMeta
	in.ObjectMeta.DeepCopyInto(&out.ObjectMeta)
	in.Spec.DeepCopyInto(&out.Spec)
	out.Status = in.Status
}

// DeepCopy is an autogenerated deepcopy function, copying the receiver, creating a new PreScaledCronJob.
func (in *PreScaledCronJob) DeepCopy() *PreScaledCronJob {
	if in == nil {
		return nil
	}
	out := new(PreScaledCronJob)
	in.DeepCopyInto(out)
	return out
}

// DeepCopyObject is an autogenerated deepcopy function, copying the receiver, creating a new runtime.Object.
func (in *PreScaledCronJob) DeepCopyObject() runtime.Object {
	if c := in.DeepCopy(); c != nil {
		return c
	}
	return nil
}

// DeepCopyInto is an autogenerated deepcopy function, copying the receiver, writing into out. in must be non-nil.
func (in *PreScaledCronJobList) DeepCopyInto(out *PreScaledCronJobList) {
	*out = *in
	out.TypeMeta = in.TypeMeta
	out.ListMeta = in.ListMeta
	if in.Items != nil {
		in, out := &in.Items, &out.Items
		*out = make([]PreScaledCronJob, len(*in))
		for i := range *in {
			(*in)[i].DeepCopyInto(&(*out)[i])
		}
	}
}

// DeepCopy is an autogenerated deepcopy function, copying the receiver, creating a new PreScaledCronJobList.
func (in *PreScaledCronJobList) DeepCopy() *PreScaledCronJobList {
	if in == nil {
		return nil
	}
	out := new(PreScaledCronJobList)
	in.DeepCopyInto(out)
	return out
}

// DeepCopyObject is an autogenerated deepcopy function, copying the receiver, creating a new runtime.Object.
func (in *PreScaledCronJobList) DeepCopyObject() runtime.Object {
	if c := in.DeepCopy(); c != nil {
		return c
	}
	return nil
}

// DeepCopyInto is an autogenerated deepcopy function, copying the receiver, writing into out. in must be non-nil.
func (in *PreScaledCronJobSpec) DeepCopyInto(out *PreScaledCronJobSpec) {
	*out = *in
	in.CronJob.DeepCopyInto(&out.CronJob)
}

// DeepCopy is an autogenerated deepcopy function, copying the receiver, creating a new PreScaledCronJobSpec.
func (in *PreScaledCronJobSpec) DeepCopy() *PreScaledCronJobSpec {
	if in == nil {
		return nil
	}
	out := new(PreScaledCronJobSpec)
	in.DeepCopyInto(out)
	return out
}

// DeepCopyInto is an autogenerated deepcopy function, copying the receiver, writing into out. in must be non-nil.
func (in *PreScaledCronJobStatus) DeepCopyInto(out *PreScaledCronJobStatus) {
	*out = *in
}

// DeepCopy is an autogenerated deepcopy function, copying the receiver, creating a new PreScaledCronJobStatus.
func (in *PreScaledCronJobStatus) DeepCopy() *PreScaledCronJobStatus {
	if in == nil {
		return nil
	}
	out := new(PreScaledCronJobStatus)
	in.DeepCopyInto(out)
	return out
}
