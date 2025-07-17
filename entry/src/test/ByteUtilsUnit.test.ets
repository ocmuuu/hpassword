// @ts-nocheck
import { describe, it, expect } from '@ohos/hypium';
import { 
  stringToBytes, bytesToString, hexToBytes, bytesToHex, 
  bytesToBase64, base64ToBytes, arrayBufferEquals 
} from '../main/ets/lib/utils/byte-utils';

function strToUint8(str: string): Uint8Array {
  const arr = new Uint8Array(str.length);
  for (let i = 0; i < str.length; i++) {
    arr[i] = str.charCodeAt(i);
  }
  return arr;
}

export default function byteUtilsUnitTest() {
  describe('byte-utils functions', () => {
    it('string <-> bytes conversion', 0, () => {
      const str = 'Hello, 世界';
      const bytes = stringToBytes(str);
      const back = bytesToString(bytes);
      expect(back).assertEqual(str);
    });

    it('hex <-> bytes conversion', 0, () => {
      const hex = '48656c6c6f';
      const bytes = hexToBytes(hex);
      expect(bytesToHex(bytes)).assertEqual(hex);
    });

    it('base64 <-> bytes conversion', 0, () => {
      const b64 = 'SGVsbG8='; // "Hello" in base64
      const bytes = base64ToBytes(b64);
      const back = bytesToBase64(bytes);
      expect(back).assertEqual(b64);
    });

    it('arrayBufferEquals should work correctly', 0, () => {
      const a = strToUint8('abc').buffer;
      const b = strToUint8('abc').buffer;
      const c = strToUint8('abcd').buffer;
      expect(arrayBufferEquals(a, b)).assertEqual(true);
      expect(arrayBufferEquals(a, c)).assertEqual(false);
    });
  });
} 