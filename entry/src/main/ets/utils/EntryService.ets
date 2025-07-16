import { EntryItem } from './EntryConverter'
import { SearchState } from './SearchHelper'
import { FieldInfoHelper, RenderField } from '../templates/FieldInfoHelper'

export interface RenderFieldsResult {
  renderFields: RenderField[]
  sortedKeys: string[]
}

/**
 * 条目相关工具服务
 */
export class EntryService {
  /** 判断条目是否已加星 */
  static isEntryStarred(entry: EntryItem | null): boolean {
    if (!entry) return false
    const fields = entry.fields
    if (!fields) return false
    if (fields.get('Starred') === 'true') return true
    const tags = fields.get('Tags') || ''
    return tags.toLowerCase().includes('star') || tags.toLowerCase().includes('favorite')
  }

  /**
   * 根据搜索状态返回当前要显示的条目列表
   */
  static getCurrentDisplayEntries(searchState: SearchState, entryItems: EntryItem[]): EntryItem[] {
    if (searchState.isSearching) {
      return searchState.results
    }
    return entryItems
  }

  /**
   * 为 EntryItem 构建渲染字段及排序
   */
  static buildRenderFields(entry: EntryItem | null): RenderFieldsResult {
    if (!entry || !entry.fields) {
      return { renderFields: [], sortedKeys: [] } as RenderFieldsResult
    }
    const renderFields = FieldInfoHelper.processSortedFields(entry.fields, entry.groupName)
    const sortedKeys = renderFields.map(f => f.key)
    return { renderFields, sortedKeys } as RenderFieldsResult
  }
} 