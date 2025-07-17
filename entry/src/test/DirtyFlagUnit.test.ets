// @ts-nocheck
import { describe, it, expect } from '@ohos/hypium';
import DirtyFlag from '../main/ets/utils/DirtyFlag';

export default function dirtyFlagUnitTest() {
  describe('DirtyFlag', () => {
    it('should toggle correctly', 0, () => {
      DirtyFlag.dirty = false;
      expect(DirtyFlag.dirty).assertEqual(false);
      DirtyFlag.dirty = true;
      expect(DirtyFlag.dirty).assertEqual(true);
    });
  });
} 