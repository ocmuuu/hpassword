// @ts-nocheck
import { describe, it, expect } from '@ohos/hypium';
import { 
  KDF_ROUNDS_PRESETS, getSecurityLevelName, getSecurityLevelDescription, validateKdfRounds 
} from '../main/ets/utils/KdbxConstants';

export default function kdbxConstantsUnitTest() {
  describe('KdbxConstants helper functions', () => {
    it('getSecurityLevelName should match presets', 0, () => {
      for (const preset of KDF_ROUNDS_PRESETS) {
        expect(getSecurityLevelName(preset.rounds)).assertEqual(preset.name);
      }
      // custom rounds
      expect(getSecurityLevelName(12345)).assertEqual('自定义');
    });

    it('getSecurityLevelDescription should match presets', 0, () => {
      for (const preset of KDF_ROUNDS_PRESETS) {
        expect(getSecurityLevelDescription(preset.rounds)).assertEqual(preset.description);
      }
      const customRounds = 12345;
      expect(getSecurityLevelDescription(customRounds)).assertEqual(`自定义轮数: ${customRounds}`);
    });

    it('validateKdfRounds should validate range', 0, () => {
      expect(validateKdfRounds(0)).assertEqual(false);
      expect(validateKdfRounds(-1)).assertEqual(false);
      expect(validateKdfRounds(100)).assertEqual(true);
      expect(validateKdfRounds(10000001)).assertEqual(false);
    });
  });
} 