/*
 * 为 MainPage 提供数据查询与转换的独立工具类，降低页面代码复杂度。
 */

import { KdbxQuery } from './KdbxQuery'
import { EntryConverter, EntryItem } from './EntryConverter'
import { TemplateManager } from '../templates/index'
import { PasswordGenerator } from './PasswordGenerator'

export interface SidebarItem {
  id: string
  title: string
  icon: Resource
  type: 'special' | 'group' | 'recycle' | 'divider'
  count?: number
  parentId?: string
}

export interface SidebarItemsResult {
  fixedItems: SidebarItem[]
  scrollableItems: SidebarItem[]
  allItems: SidebarItem[]
}

export class MainPageDataService {
  /**
   * 生成侧边栏项目
   */
  static async buildSidebarItems(kdbxQuery: KdbxQuery): Promise<SidebarItemsResult> {
    const fixedItems: SidebarItem[] = []
    const scrollableItems: SidebarItem[] = []

    // 固定的特殊项目
    fixedItems.push({ id: 'starred', title: '加星', icon: $r('app.media.star'), type: 'special' })
    fixedItems.push({ id: 'random_password', title: '随机密码', icon: $r('app.media.random'), type: 'special' })
    fixedItems.push({ id: 'all_entries', title: '所有条目', icon: $r('app.media.all'), type: 'special' })
    fixedItems.push({ id: 'divider_fixed', title: '', icon: $r('app.media.startIcon'), type: 'divider' })

    // 动态组
    if (kdbxQuery) {
      const groupsResult = await kdbxQuery.getAllGroups()
      if (groupsResult.success && groupsResult.data) {
        const systemTemplateNames = TemplateManager.getSystemTemplateNames()
        let recycleBinGroup: SidebarItem | null = null

        for (const group of groupsResult.data) {
          const isRecycleBin = group.name === 'Recycle Bin'
          const groupName = group.name || '未命名'

          if (isRecycleBin) {
            recycleBinGroup = { id: group.uuid.id, title: '回收站', icon: $r('app.media.trash'), type: 'recycle' }
            continue
          }

          // 系统模板分组只有在有条目时才显示
          const isSystemTemplate = systemTemplateNames.includes(groupName)
          let shouldShow = true
          if (isSystemTemplate) {
            const groupResult = await kdbxQuery.getEntriesByGroup(group.uuid.id)
            const hasEntries = !!(groupResult.success && groupResult.data && groupResult.data.length > 0)
            shouldShow = hasEntries
          }

          if (shouldShow) {
            scrollableItems.push({
              id: group.uuid.id,
              title: groupName,
              icon: EntryConverter.getTemplateIcon(groupName),
              type: 'group'
            })
          }
        }

        if (recycleBinGroup) {
          scrollableItems.push(recycleBinGroup)
        }
      }
    }

    const allItems = [...fixedItems, ...scrollableItems]
    return { fixedItems, scrollableItems, allItems }
  }

  /**
   * 根据侧边栏选中项加载条目
   */
  static async fetchEntriesForSidebar(
    kdbxQuery: KdbxQuery,
    sidebarItems: SidebarItem[],
    sidebarId: string
  ): Promise<EntryItem[]> {
    if (!kdbxQuery) {
      return []
    }

    let entriesRaw: ESObject[] = []
    const selectedItem = sidebarItems.find(item => item.id === sidebarId)
    const isRecycleBin = selectedItem?.type === 'recycle'

    if (sidebarId === 'all_entries') {
      const allResult = await kdbxQuery.getAllEntries()
      if (allResult.success && allResult.data) {
        entriesRaw = allResult.data.filter((entry: ESObject): boolean => {
          const parentGroup: ESObject | null = entry.parentGroup as ESObject | null
          return parentGroup !== null && (parentGroup.name as string) !== 'Recycle Bin'
        })
      }
    } else if (sidebarId === 'starred') {
      const starredResult = await kdbxQuery.getStarredEntries()
      entriesRaw = starredResult.success && starredResult.data ? starredResult.data : []
    } else if (isRecycleBin) {
      const recycleResult = await kdbxQuery.getRecycleBinEntries()
      entriesRaw = recycleResult.success && recycleResult.data ? recycleResult.data : []
    } else if (sidebarId === 'random_password') {
      // 随机密码条目直接返回
      return PasswordGenerator.getRandomPasswordEntryItems(16)
    } else {
      const groupResult = await kdbxQuery.getEntriesByGroup(sidebarId)
      entriesRaw = groupResult.success && groupResult.data ? groupResult.data : []
    }

    const mappedItems: EntryItem[] = entriesRaw
      .map((entryRaw: ESObject) => EntryConverter.convertKdbxEntryToEntryItem(entryRaw as ESObject))
      .filter(item => item !== null) as EntryItem[]

    return mappedItems
  }
} 