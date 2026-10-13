import { describe, expect, it } from 'vitest';
import { verifyAttendanceImageBytes } from '../lib/files/image-validation';

function minimalJpeg(width: number, height: number) {
  return new Uint8Array([
    0xff,
    0xd8,
    0xff,
    0xc0,
    0x00,
    0x11,
    0x08,
    (height >> 8) & 0xff,
    height & 0xff,
    (width >> 8) & 0xff,
    width & 0xff,
    0x03,
    0x01,
    0x11,
    0x00,
    0x02,
    0x11,
    0x00,
    0x03,
    0x11,
    0x00,
    0xff,
    0xd9,
  ]);
}

describe('P10 attendance evidence content validation', () => {
  it('SEC-04 accepts a matching JPEG within the 1920px boundary', () => {
    const bytes = minimalJpeg(1280, 1920);
    expect(verifyAttendanceImageBytes(bytes, 'image/jpeg', bytes.length)).toEqual({
      mimeType: 'image/jpeg',
      width: 1280,
      height: 1920,
    });
  });

  it('SEC-04 rejects fake MIME and images beyond the processing boundary', () => {
    const normal = minimalJpeg(1280, 720);
    expect(verifyAttendanceImageBytes(normal, 'image/webp', normal.length)).toBeNull();
    const oversizedDimensions = minimalJpeg(2560, 1440);
    expect(
      verifyAttendanceImageBytes(oversizedDimensions, 'image/jpeg', oversizedDimensions.length),
    ).toBeNull();
  });

  it('SEC-04 rejects size metadata that does not match stored bytes', () => {
    const bytes = minimalJpeg(800, 600);
    expect(verifyAttendanceImageBytes(bytes, 'image/jpeg', bytes.length + 10)).toBeNull();
  });
});
