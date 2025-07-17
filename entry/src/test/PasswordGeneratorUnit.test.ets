// @ts-nocheck
import { describe, it, expect, beforeAll } from '@ohos/hypium';
import { PasswordGenerator } from '../main/ets/utils/PasswordGenerator';

// 为测试环境提供 $r 资源函数桩，避免运行时异常
interface ResourceStub { id: string }

interface GlobalWithR {
  $r?: (key: string) => ResourceStub;
}

beforeAll(() => {
  const g = globalThis as GlobalWithR;
  if (typeof g.$r !== 'function') {
    g.$r = (key: string): ResourceStub => ({ id: String(key) });
  }
});

const ambiguous = '0O1lI5S2Z';

export default function passwordGeneratorUnitTest() {
  describe('PasswordGenerator', () => {
    it('generate default length', 0, () => {
      const pwd = PasswordGenerator.generate();
      expect(pwd.length).assertEqual(16);
    });

    it('generate length and charset type 1', 0, () => {
      const len = 20;
      const pwd = PasswordGenerator.generate(len, 1);
      expect(pwd.length).assertEqual(len);
      expect(/^[A-Za-z0-9]+$/.test(pwd)).assertEqual(true);
    });

    it('digits only for type 5', 0, () => {
      const pwd = PasswordGenerator.generate(12, 5);
      expect(/^[0-9]+$/.test(pwd)).assertEqual(true);
    });

    it('hex chars only for type 6', 0, () => {
      const pwd = PasswordGenerator.generate(12, 6);
      expect(/^[0-9A-F]+$/.test(pwd)).assertEqual(true);
    });

    it('no ambiguous chars for type 4', 0, () => {
      const pwd = PasswordGenerator.generate(50, 4);
      for (const ch of ambiguous) {
        expect(pwd.includes(ch)).assertEqual(false);
      }
    });

    it('generatePasswordList length calculation', 0, () => {
      const list = PasswordGenerator.generatePasswordList(5, [8], 2);
      expect(list.length).assertEqual(2);
      for (const pwd of list) {
        expect(pwd.length).assertEqual(8);
      }
    });

    it('buildRenderFields returns correct length', 0, () => {
      const fields = PasswordGenerator.buildRenderFields(1);
      expect(fields.length).assertEqual(15); // 5 lengths * 3 per length
    });

    it('generate length 0 returns empty string', 0, () => {
      expect(PasswordGenerator.generate(0).length).assertEqual(0);
    });
  });
} 