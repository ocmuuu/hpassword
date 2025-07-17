// @ts-nocheck
import { describe, it, expect } from '@ohos/hypium';
import { EntryService } from '../main/ets/utils/EntryService';
import { FieldInfoHelper, RenderField } from '../main/ets/templates/FieldInfoHelper';
import { EntryItem } from '../main/ets/utils/EntryConverter';
import { SearchState } from '../main/ets/utils/SearchHelper';

// HarmonyOS Resource 类型简化占位
type Resource = object;

// Patch FieldInfoHelper.processSortedFields 以返回确定结果
interface FieldInfoHelperPatch {
  processSortedFields: (fields: Map<string, string>, group?: string) => RenderField[];
}

(FieldInfoHelper as FieldInfoHelperPatch).processSortedFields = (fields: Map<string, string>): RenderField[] => {
    const list: RenderField[] = [];
    fields.forEach((val, key) => {
      list.push({ key, label: key, value: val, type: 'text' });
    });
    return list;
  };

// 构造符合 EntryItem 接口的简易对象
function createEntry(fieldsObj: Record<string, string>): EntryItem {
  const map = new Map<string, string>();
  for (const entry of Object.entries(fieldsObj)) {
    const key = entry[0];
    const val = entry[1];
    map.set(key, val);
  }
  return {
    id: '',
    title: '',
    username: '',
    notes: '',
    url: '',
    icon: {} as Resource, // minimal stub
    lastModified: '',
    fields: map
  } as EntryItem;
}

export default function entryServiceUnitTest() {
  describe('EntryService', () => {
    it('isEntryStarred should recognize star markers', 0, () => {
      const starred = createEntry({ Starred: 'true' });
      expect(EntryService.isEntryStarred(starred)).assertEqual(true);
      const tagged = createEntry({ Tags: 'favorite,abc' });
      expect(EntryService.isEntryStarred(tagged)).assertEqual(true);
      const none = createEntry({ Tags: 'work' });
      expect(EntryService.isEntryStarred(none)).assertEqual(false);
    });

    it('getCurrentDisplayEntries returns search results if searching', 0, () => {
      const dummy: EntryItem = createEntry({});
      const searchState: SearchState = {
        query: 'a',
        isSearching: true,
        results: [dummy, dummy]
      };
      const list = EntryService.getCurrentDisplayEntries(searchState, [dummy, dummy, dummy]);
      expect(list.length).assertEqual(2);
      // 清除搜索后应返回默认列表
      const list2 = EntryService.getCurrentDisplayEntries({ query: '', isSearching: false, results: [] }, [dummy, dummy, dummy]);
      expect(list2.length).assertEqual(3);
    });

    it('buildRenderFields returns processed fields', 0, () => {
      const entry = createEntry({ Title: 'abc', Notes: 'note' });
      const res = EntryService.buildRenderFields(entry);
      expect(res.renderFields.length).assertEqual(2);
      expect(res.sortedKeys.includes('Title')).assertEqual(true);
    });
  });
} 