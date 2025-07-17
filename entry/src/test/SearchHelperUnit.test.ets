// @ts-nocheck
import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { SearchHelper } from '../main/ets/utils/SearchHelper';
import { EntryItem } from '../main/ets/utils/EntryConverter';

interface Resource { bundleName?: string; moduleName?: string; id?: number }

// 构造简易 EntryItem
const dummyEntry: EntryItem = {
  id: '0',
  title: '',
  username: '',
  notes: '',
  url: '',
  icon: { id: 0 } as Resource,
  lastModified: ''
};

interface EmptyGroup {}

interface StubResult { entry: EntryItem; group: EmptyGroup }

function createKdbxQueryStub(resultsCount: number) {
  return {
    searchEntries: () => {
      const data: StubResult[] = [];
      for (let i = 0; i < resultsCount; i++) {
        data.push({ entry: dummyEntry, group: {} as EmptyGroup });
      }
      return { success: true, data };
    }
  };
}

interface HelperWithPerform {
  performSearch: (q: string, k: Record<string, never>) => void;
}

export default function searchHelperUnitTest() {
  describe('SearchHelper basic functions', () => {
    let helper: SearchHelper;

    beforeEach(() => {
      helper = new SearchHelper();
    });

    it('containsSearchKeyword logic', 0, () => {
      const kdbxStub = createKdbxQueryStub(0);
      (helper as HelperWithPerform)
        .performSearch('abc', kdbxStub);
      expect(helper.containsSearchKeyword('xxx')).assertEqual(false);
      expect(helper.containsSearchKeyword('abcdef')).assertEqual(true);
    });

    it('getCurrentDisplayEntries switches with searching', 0, () => {
      const defaultEntries: EntryItem[] = [dummyEntry, dummyEntry, dummyEntry];
      const kdbxStub = createKdbxQueryStub(2);
      (helper as HelperWithPerform)
        .performSearch('a', kdbxStub);
      const list = helper.getCurrentDisplayEntries(defaultEntries);
      expect(list.length).assertEqual(2);
      helper.clearSearch();
      const list2 = helper.getCurrentDisplayEntries(defaultEntries);
      expect(list2.length).assertEqual(3);
    });
  });
} 