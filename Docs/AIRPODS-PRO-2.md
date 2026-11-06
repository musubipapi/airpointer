# AirPods Pro 2 USB-C: experimental pointing support

This is a partial compatibility experiment, not full Pro 2 support. A diagnostic
build enabled three-point calibration and cursor movement on one pair of AirPods
Pro 2 with a USB-C case. Physical taps did not click: Teach Tap stayed at 0/3.

## Observed hardware and failures

- AirPods Pro 2 USB-C, Bluetooth product ID `0x2024`, firmware `9A348`.
- Apple silicon Mac running macOS 27.0.1, build `26A434`.
- Upstream baseline: `a73cc79`.
- Requests to raw services 11 and 12 were acknowledged but produced no usable
  28-byte sensor reports, ending with `BASELINE_UNAVAILABLE`.
- The sensor catalog advertised `devmotion6` with service ID 16. Its reports
  continued with both earbuds inside and the lid closed.
- The charging case reported `MagSafe Charging Case (USB-C)` and failed the
  original `AirPods`-prefix check with `WRONG_CASE_MODEL`.

The case-name correction overlaps with
[PR #1](https://github.com/musubipapi/airpointer/pull/1). This experiment also
addresses the missing raw-motion stream, which is a separate failure.

## Motion fallback

The helper requests the sensor descriptors and selects only a parsed
`AccessoryService` named exactly `devmotion6`. The service ID is read from that
peer's catalog rather than fixed at 16. IDs above 127 are ignored because the
existing sensor-setting encoder uses a single varint byte for the ID.

If neither raw source has produced reports after the initial setup interval,
the helper subscribes at 20,000 microseconds (50 Hz). It accepts only the observed
56-byte format: report ID 1, layout 6 at byte 9, and both component-valid bits
at byte 11. The converted stream uses the existing accel/gyro consumers and
timestamp freshness checks. Once either source is active, its clock domain is
not mixed with the other source. Cleanup stops an attempted fallback subscription
before releasing the held case asset.

| Byte offset | Interpretation | Conversion to existing pipeline |
| --- | --- | --- |
| 1–8 | Little-endian timestamp, nanoseconds | Divide by 1,000 for microseconds |
| 26/28/30 | Signed 16-bit angular velocity, Q9 radians/second | Convert to 1e-5 degrees/second |
| 44/46/48 | Signed 16-bit acceleration vector, Q10 g | Convert to 1e-5 g |

These interpretations are empirical. Stationary acceleration magnitude was
approximately 1,024 in captured units, and the angular velocity agreed with the
derivative of the attitude fields. This does not establish the acceleration
vector's filtering or suitability for tap detection. The descriptor request is
documented as `SensorDataWX.request_all_descriptors` in
[apple-wireshark's RTBuddy schema](https://github.com/pabloaul/apple-wireshark/blob/main/plugins/rtbuddy/rtbuddy.proto).

## Validation and remaining work

- A diagnostic build using this decoder and case-name correction passed case
  verification, saved three-point screen calibration, and moved the cursor in a
  real user test with the lid closed.
- The submitted source removes temporary diagnostic capture and packet logging,
  and requires a parsed service name. It has offline coverage, but this cleaned
  version has not had a separate hardware retest.
- Offline checks cover packed units and signs, invalid lengths and layouts,
  startup validity, advertised service selection, duplicate timestamps, and
  isolation from the existing raw source.
- The existing recorded tap fixtures pass. They are upstream recordings, not
  successful taps recorded from this Pro 2 pair.
- Pro 2 taps remained at 0/3 in the live test. Tap detection requires further
  investigation; it must not be advertised as working.
- A Bluetooth-channel disconnect was also observed during calibration. Its
  cause remains unknown. Other firmware, the Lightning case, Pro 3 regressions,
  and long-session behavior have not been checked on hardware for this patch.

The contribution includes source and synthetic checks only. It does not include
device addresses, user-set names, serial numbers, or raw diagnostic recordings.
