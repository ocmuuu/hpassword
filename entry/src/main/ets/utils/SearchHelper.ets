import { SearchCriteria } from './KdbxTypes'
import { EntryConverter, EntryItem } from './EntryConverter'
import { KdbxQuery } from './KdbxQuery'
import { KdbxEntryManager } from './KdbxEntryManager'

/**
 * 搜索状态接口
 */
export interface SearchState {
  query: string
  isSearching: boolean
  results: EntryItem[]
}

/**
 * 搜索回调函数类型
 */
export type SearchCallback = (state: SearchState) => void

/**
 * 搜索助手工具类
 * 负责处理搜索相关的逻辑，包括防抖、搜索执行、状态管理等
 */
export class SearchHelper {
  private searchTimer: number | null = null
  private readonly SEARCH_DEBOUNCE_DELAY = 300  // 搜索防抖延迟300ms
  private searchQuery: string = ''
  private isSearching: boolean = false
  private filteredEntryItems: EntryItem[] = []
  private callback: SearchCallback | null = null

  /**
   * 设置搜索状态更新回调
   */
  setCallback(callback: SearchCallback) {
    this.callback = callback
  }

  /**
   * 获取当前搜索状态
   */
  getCurrentState(): SearchState {
    return {
      query: this.searchQuery,
      isSearching: this.isSearching,
      results: this.filteredEntryItems
    }
  }

  /**
   * 清除搜索计时器
   */
  private clearSearchTimer() {
    if (this.searchTimer !== null) {
      clearTimeout(this.searchTimer)
      this.searchTimer = null
    }
  }

  /**
   * 防抖搜索
   */
  debounceSearch(query: string, kdbxQuery: KdbxQuery, kdbxEntryManager?: KdbxEntryManager) {
    this.searchQuery = query
    
    // 清除之前的计时器
    this.clearSearchTimer()
    
    // 设置新的计时器
    this.searchTimer = setTimeout(() => {
      this.performSearch(query, kdbxQuery, kdbxEntryManager)
    }, this.SEARCH_DEBOUNCE_DELAY)
  }

  /**
   * 执行搜索
   */
  private performSearch(query: string, kdbxQuery: KdbxQuery, kdbxEntryManager?: KdbxEntryManager) {
    try {
      if (!query.trim()) {
        // 空搜索，清空状态
        this.isSearching = false
        this.filteredEntryItems = []
        this.notifyCallback()
        return
      }

      this.isSearching = true
      this.notifyCallback()

      // 构建搜索条件
      const searchCriteria: SearchCriteria = {
        query: query.trim(),
        searchInTitles: true,
        searchInUsernames: true,
        searchInUrls: true,
        searchInNotes: true,
        caseSensitive: false,
        useRegex: false
      }

      // 执行搜索
      const searchResult = kdbxQuery.searchEntries(searchCriteria)
      
      if (searchResult.success && searchResult.data) {
        // 将搜索结果转换为 EntryItem 格式
        const searchedItems: EntryItem[] = []
        
        for (const result of searchResult.data) {
          const entryItem = EntryConverter.convertKdbxEntryToEntryItem(result.entry, result.group, kdbxEntryManager)
          if (entryItem) {
            searchedItems.push(entryItem)
          }
        }

        this.filteredEntryItems = searchedItems
      } else {
        this.filteredEntryItems = []
      }

      this.notifyCallback()
    } catch (error) {
      console.error('SearchHelper', '搜索失败:', error)
      this.filteredEntryItems = []
      this.notifyCallback()
    }
  }

  /**
   * 清空搜索
   */
  clearSearch() {
    this.searchQuery = ''
    this.isSearching = false
    this.filteredEntryItems = []
    this.clearSearchTimer()
    this.notifyCallback()
  }

  /**
   * 检查文本是否包含搜索关键词（用于高亮显示）
   */
  containsSearchKeyword(text: string): boolean {
    if (!this.isSearching || !this.searchQuery.trim()) {
      return false
    }
    return text.toLowerCase().includes(this.searchQuery.toLowerCase())
  }

  /**
   * 获取当前显示的条目列表（搜索时显示搜索结果，否则显示传入的默认条目）
   */
  getCurrentDisplayEntries(defaultEntries: EntryItem[]): EntryItem[] {
    if (this.isSearching) {
      return this.filteredEntryItems
    }
    return defaultEntries
  }

  /**
   * 通知回调函数状态更新
   */
  private notifyCallback() {
    if (this.callback) {
      this.callback(this.getCurrentState())
    }
  }

  /**
   * 清理资源
   */
  destroy() {
    this.clearSearchTimer()
    this.callback = null
  }
} 