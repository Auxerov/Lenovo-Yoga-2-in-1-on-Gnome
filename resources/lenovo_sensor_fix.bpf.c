// SPDX-License-Identifier: GPL-2.0-only
/* Copyright (c) 2026 Antigravity
 *
 * Lenovo Yoga 7 2-in-1 AMD SFH Accelerometer Report Descriptor Fix
 * Fixes: "hid-sensor-hub 0020:1022:0001.0003: Event data for report 1 was too short (15 vs 14)"
 *
 * The AMD Sensor Fusion Hub (amd_sfh) hardware transmits 14 bytes for the
 * accelerometer report (1 byte state, 1 byte event, 4 bytes X, 4 bytes Y, 4 bytes Z).
 * However, the driver declared descriptor includes an extra 1-byte Shake/Motion
 * Detect input (Usage 0x0451) with Report Count 1, making rsize = 15.
 * Since bsize (14) < rsize (15), hid-core drops every single accelerometer report packet!
 *
 * This fixup sets Report Count for Usage 0x0451 from 1 to 0, reducing rsize to 14.
 * This makes bsize == rsize, enabling sensor events and GNOME screen auto-rotation.
 */

#include "vmlinux.h"
#include "hid_bpf.h"
#include "hid_bpf_helpers.h"
#include <bpf/bpf_tracing.h>

#define BUS_AMD_SFH		0x20
#define HID_GROUP_SENSOR_HUB	0x0003
#define VID_AMD			0x1022
#define PID_AMD_SFH		0x0001
#define ACCEL_RDESC_SIZE	358

HID_BPF_CONFIG(
	HID_DEVICE(BUS_AMD_SFH, HID_GROUP_SENSOR_HUB, VID_AMD, PID_AMD_SFH),
	HID_DEVICE(BUS_AMD_SFH, HID_GROUP_ANY, VID_AMD, PID_AMD_SFH)
);

SEC(HID_BPF_RDESC_FIXUP)
int BPF_PROG(hid_rdesc_fixup_amd_sfh_accel, struct hid_bpf_ctx *hctx)
{
	__u8 *data = hid_bpf_get_data(hctx, 0, HID_MAX_DESCRIPTOR_SIZE);

	if (!data)
		return 0; /* EPERM check */

	/* Check for Usage 0x0451 (Shake / Motion Detect) at offset 344 and Report Count 1 at 353-354 */
	if (data[344] == 0x0a && data[345] == 0x51 && data[346] == 0x04 &&
	    data[353] == 0x95 && data[354] == 0x01) {
		data[354] = 0x00; /* Set Report Count to 0 to exclude this byte from rsize calculation */
	}

	return 0;
}

HID_BPF_OPS(amd_sfh_accel_fix) = {
	.hid_rdesc_fixup = (void *)hid_rdesc_fixup_amd_sfh_accel,
};

SEC("syscall")
int probe(struct hid_bpf_probe_args *ctx)
{
	if (ctx->rdesc_size < ACCEL_RDESC_SIZE) {
		ctx->retval = -EINVAL;
		return 0;
	}

	ctx->retval = 0;
	return 0;
}

char _license[] SEC("license") = "GPL";
