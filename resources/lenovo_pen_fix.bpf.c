// SPDX-License-Identifier: GPL-2.0-only
/* Copyright (c) 2026 Antigravity
 */

#include "vmlinux.h"
#include "hid_bpf.h"
#include "hid_bpf_helpers.h"
#include <bpf/bpf_tracing.h>

#define BUS_I2C 0x18
#define HID_GROUP_WACOM 0x0101
#define VID_WACOM 0x056A
#define PID_WACOM_5363 0x5363

HID_BPF_CONFIG(
	HID_DEVICE(BUS_I2C, HID_GROUP_WACOM, VID_WACOM, PID_WACOM_5363),
	HID_DEVICE(BUS_I2C, HID_GROUP_ANY, VID_WACOM, PID_WACOM_5363)
);

SEC(HID_BPF_DEVICE_EVENT)
int BPF_PROG(lenovo_pen_fix_eraser, struct hid_bpf_ctx *hctx)
{
	__u8 *data = hid_bpf_get_data(hctx, 0 /* offset */, 10 /* size */);

	if (!data)
		return 0;

	/* Check for stylus report IDs (0x14 = 20, 0x0b = 11) */
	if (data[0] != 0x14 && data[0] != 0x0b)
		return 0;

	/*
	 * When lower barrel button (Button 1) is pressed on Lenovo Digital Pen 2,
	 * the pen firmware emits Eraser (bit 2 = 0x04) and/or Invert (bit 3 = 0x08).
	 * This causes wacom.ko to report BTN_TOOL_RUBBER instead of BTN_TOOL_PEN,
	 * dropping proximity and preventing standard button mapping.
	 *
	 * We transform Eraser/Invert into Secondary Barrel Switch (bit 4 = 0x10).
	 * wacom.ko will cleanly emit BTN_STYLUS2 while keeping BTN_TOOL_PEN active.
	 *
	 * Also, if either Button 1 or Button 2 is pressed, we clear Tip Switch (bit 0 = 0x01)
	 * and pressure (bytes 6-7). This prevents accidental Left Clicks / draw strokes
	 * while navigating (Orbit or Pan) when the pen tip touches or grazes the screen.
	 */
	if (data[1] & 0x0c) {
		data[1] &= ~0x0c; /* clear Eraser and Invert */
		data[1] |= 0x10;  /* set Secondary Barrel Switch (BTN_STYLUS2) */
		data[1] |= 0x20;  /* ensure In Range is set */
		data[1] &= ~0x01; /* clear Tip Switch */
		data[6] = 0;      /* clear pressure */
		data[7] = 0;
	} else if (data[1] & 0x02) {
		/* Upper barrel button (Button 2) is active (BTN_STYLUS) */
		data[1] &= ~0x01; /* clear Tip Switch */
		data[6] = 0;      /* clear pressure */
		data[7] = 0;
	}

	return 0;
}

HID_BPF_OPS(lenovo_pen_fix) = {
	.hid_device_event = (void *)lenovo_pen_fix_eraser,
};

SEC("syscall")
int probe(struct hid_bpf_probe_args *ctx)
{
	ctx->retval = 0;
	return 0;
}

char _license[] SEC("license") = "GPL";
