import { hilog } from '@kit.PerformanceAnalysisKit';
import { Kdbx, KdbxEntry, KdbxGroup, ProtectedValue } from '../lib';
import { 
  SearchCriteria, 
  SearchResult, 
  EntryFilter, 
  GroupFilter,
  OperationResult,
  DatabaseStats,
  LogParams
} from './KdbxTypes';
import { 
  getEntryDisplayText, 
  calculateGroupStats,
  getGroupPath,
  findEntryInGroup,
  findGroupInGroup,
  logOperation,
  logError 
} from './KdbxUtils';

const TAG = 'KdbxQuery';

/**
 * KDBX数据库查询操作类
 */
export class KdbxQuery {
  private database: Kdbx | null = null;

  /**
   * 构造函数
   */
  constructor(database?: Kdbx) {
    this.database = database || null;
  }

  /**
   * 设置数据库实例
   */
  setDatabase(database: Kdbx): void {
    this.database = database;
  }

  /**
   * 搜索条目
   */
  searchEntries(criteria: SearchCriteria): OperationResult<SearchResult[]> {
    try {
      if (!this.database) {
        return {
          success: false,
          error: '数据库未设置',
          errorCode: 'DATABASE_NOT_SET'
        };
      }

      logOperation('searchEntries', { query: criteria.query });

      const results: SearchResult[] = [];
      const rootGroup = this.database.getDefaultGroup();
      
      if (!rootGroup) {
        return {
          success: false,
          error: '根组不存在',
          errorCode: 'ROOT_GROUP_NOT_FOUND'
        };
      }

      this.searchInGroup(rootGroup, criteria, results);

      hilog.info(0, TAG, '搜索完成，找到 %{public}d 个结果', results.length);

      return {
        success: true,
        data: results
      };

    } catch (error) {
      logError('searchEntries', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'SEARCH_ERROR'
      };
    }
  }

  /**
   * 获取所有条目
   */
  getAllEntries(): OperationResult<KdbxEntry[]> {
    try {
      if (!this.database) {
        return {
          success: false,
          error: '数据库未设置',
          errorCode: 'DATABASE_NOT_SET'
        };
      }

      const entries: KdbxEntry[] = [];
      const rootGroup = this.database.getDefaultGroup();
      
      if (!rootGroup) {
        return {
          success: false,
          error: '根组不存在',
          errorCode: 'ROOT_GROUP_NOT_FOUND'
        };
      }

      this.collectEntriesFromGroup(rootGroup, entries);

      return {
        success: true,
        data: entries
      };

    } catch (error) {
      logError('getAllEntries', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'GET_ENTRIES_ERROR'
      };
    }
  }

  /**
   * 根据过滤器获取条目
   */
  getFilteredEntries(filter: EntryFilter): OperationResult<KdbxEntry[]> {
    try {
      const allEntriesResult = this.getAllEntries();
      if (!allEntriesResult.success || !allEntriesResult.data) {
        return allEntriesResult;
      }

      const filteredEntries = allEntriesResult.data.filter(entry => 
        this.matchesEntryFilter(entry, filter)
      );

      return {
        success: true,
        data: filteredEntries
      };

    } catch (error) {
      logError('getFilteredEntries', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'FILTER_ENTRIES_ERROR'
      };
    }
  }

  /**
   * 获取所有组（只返回根组的子组，不包括根组本身）
   */
  getAllGroups(): OperationResult<KdbxGroup[]> {
    try {
      if (!this.database) {
        return {
          success: false,
          error: '数据库未设置',
          errorCode: 'DATABASE_NOT_SET'
        };
      }

      const groups: KdbxGroup[] = [];
      const rootGroup = this.database.getDefaultGroup();
      
      if (!rootGroup) {
        return {
          success: false,
          error: '根组不存在',
          errorCode: 'ROOT_GROUP_NOT_FOUND'
        };
      }

      // 只收集根组的子组，不包括根组本身
      for (let i = 0; i < rootGroup.groups.length; i++) {
        const childGroup = rootGroup.groups[i];
        this.collectGroupsFromGroup(childGroup, groups);
      }

      return {
        success: true,
        data: groups
      };

    } catch (error) {
      logError('getAllGroups', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'GET_GROUPS_ERROR'
      };
    }
  }

  /**
   * 根据过滤器获取组
   */
  getFilteredGroups(filter: GroupFilter): OperationResult<KdbxGroup[]> {
    try {
      const allGroupsResult = this.getAllGroups();
      if (!allGroupsResult.success || !allGroupsResult.data) {
        return allGroupsResult;
      }

      const filteredGroups = allGroupsResult.data.filter(group => 
        this.matchesGroupFilter(group, filter)
      );

      return {
        success: true,
        data: filteredGroups
      };

    } catch (error) {
      logError('getFilteredGroups', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'FILTER_GROUPS_ERROR'
      };
    }
  }

  /**
   * 根据ID查找条目
   */
  findEntryById(entryId: string): OperationResult<KdbxEntry> {
    try {
      if (!this.database) {
        return {
          success: false,
          error: '数据库未设置',
          errorCode: 'DATABASE_NOT_SET'
        };
      }

      const rootGroup = this.database.getDefaultGroup();
      if (!rootGroup) {
        return {
          success: false,
          error: '根组不存在',
          errorCode: 'ROOT_GROUP_NOT_FOUND'
        };
      }

      const entry = findEntryInGroup(rootGroup, entryId);
      if (!entry) {
        return {
          success: false,
          error: '条目不存在',
          errorCode: 'ENTRY_NOT_FOUND'
        };
      }

      return {
        success: true,
        data: entry
      };

    } catch (error) {
      logError('findEntryById', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'FIND_ENTRY_ERROR'
      };
    }
  }

  /**
   * 根据ID查找组
   */
  findGroupById(groupId: string): OperationResult<KdbxGroup> {
    try {
      if (!this.database) {
        return {
          success: false,
          error: '数据库未设置',
          errorCode: 'DATABASE_NOT_SET'
        };
      }

      const rootGroup = this.database.getDefaultGroup();
      if (!rootGroup) {
        return {
          success: false,
          error: '根组不存在',
          errorCode: 'ROOT_GROUP_NOT_FOUND'
        };
      }

      const group = findGroupInGroup(rootGroup, groupId);
      if (!group) {
        return {
          success: false,
          error: '组不存在',
          errorCode: 'GROUP_NOT_FOUND'
        };
      }

      return {
        success: true,
        data: group
      };

    } catch (error) {
      logError('findGroupById', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'FIND_GROUP_ERROR'
      };
    }
  }

  /**
   * 获取数据库统计信息
   */
  getDatabaseStats(): OperationResult<DatabaseStats> {
    try {
      if (!this.database) {
        return {
          success: false,
          error: '数据库未设置',
          errorCode: 'DATABASE_NOT_SET'
        };
      }

      const rootGroup = this.database.getDefaultGroup();
      if (!rootGroup) {
        return {
          success: false,
          error: '根组不存在',
          errorCode: 'ROOT_GROUP_NOT_FOUND'
        };
      }

      const stats = calculateGroupStats(rootGroup);

      return {
        success: true,
        data: stats
      };

    } catch (error) {
      logError('getDatabaseStats', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'STATS_ERROR'
      };
    }
  }

  /**
   * 获取加星条目（收藏条目）
   */
  getStarredEntries(): OperationResult<KdbxEntry[]> {
    try {
      const allEntriesResult = this.getAllEntries();
      if (!allEntriesResult.success || !allEntriesResult.data) {
        return allEntriesResult;
      }

      // 过滤出有标记的条目（通过自定义字段或标签判断）
      const starredEntries = allEntriesResult.data.filter(entry => {
        // 检查是否有星标标记（可以通过标签或自定义字段）
        if (entry.tags && entry.tags.length > 0) {
          return entry.tags.some(tag => tag.toLowerCase().includes('star') || tag.toLowerCase().includes('favorite'));
        }
        
        // 检查自定义字段
        const customFields = entry.fields;
        for (const entry of customFields.entries()) {
          const key = entry[0];
          const value = entry[1];
          if (key.toLowerCase().includes('star') || key.toLowerCase().includes('favorite')) {
            const fieldValue = (value && typeof value === 'object' && (value as ESObject).getText) ? (value as ESObject).getText() as string : value;
            if (fieldValue && fieldValue.toString().toLowerCase() === 'true') {
              return true;
            }
          }
        }
        
        return false;
      });

      return {
        success: true,
        data: starredEntries
      };

    } catch (error) {
      logError('getStarredEntries', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'GET_STARRED_ENTRIES_ERROR'
      };
    }
  }

  /**
   * 获取最近修改的条目（最近30天）
   */
  getRecentlyModifiedEntries(daysBack: number = 30): OperationResult<KdbxEntry[]> {
    try {
      const allEntriesResult = this.getAllEntries();
      if (!allEntriesResult.success || !allEntriesResult.data) {
        return allEntriesResult;
      }

      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - daysBack);

      const recentEntries = allEntriesResult.data.filter(entry => {
        const lastModTime = entry.times.lastModTime;
        return lastModTime && lastModTime > cutoffDate;
      }).sort((a, b) => {
        // 按修改时间降序排列
        const timeA = a.times.lastModTime?.getTime() || 0;
        const timeB = b.times.lastModTime?.getTime() || 0;
        return timeB - timeA;
      });

      return {
        success: true,
        data: recentEntries
      };

    } catch (error) {
      logError('getRecentlyModifiedEntries', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'GET_RECENT_ENTRIES_ERROR'
      };
    }
  }

  /**
   * 获取回收站条目
   */
  getRecycleBinEntries(): OperationResult<KdbxEntry[]> {
    try {
      if (!this.database) {
        return {
          success: false,
          error: '数据库未设置',
          errorCode: 'DATABASE_NOT_SET'
        };
      }

      const recycleBinGroup = this.database.meta.recycleBinUuid;
      if (!recycleBinGroup) {
        // 没有回收站，返回空数组
        return {
          success: true,
          data: []
        };
      }

      const recycleBinGroupResult = this.findGroupById(recycleBinGroup.id);
      if (!recycleBinGroupResult.success || !recycleBinGroupResult.data) {
        return {
          success: true,
          data: []
        };
      }

      const entries: KdbxEntry[] = [];
      this.collectEntriesFromGroup(recycleBinGroupResult.data, entries);

      return {
        success: true,
        data: entries
      };

    } catch (error) {
      logError('getRecycleBinEntries', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'GET_RECYCLE_BIN_ENTRIES_ERROR'
      };
    }
  }

  /**
   * 根据组ID获取条目
   */
  getEntriesByGroup(groupId: string): OperationResult<KdbxEntry[]> {
    try {
      const groupResult = this.findGroupById(groupId);
      if (!groupResult.success || !groupResult.data) {
        return {
          success: false,
          error: '组不存在',
          errorCode: 'GROUP_NOT_FOUND'
        };
      }

      const entries: KdbxEntry[] = [];
      this.collectEntriesFromGroup(groupResult.data, entries);

      return {
        success: true,
        data: entries
      };

    } catch (error) {
      logError('getEntriesByGroup', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'GET_GROUP_ENTRIES_ERROR'
      };
    }
  }

  /**
   * 获取组的路径
   */
  getGroupPath_(group: KdbxGroup): string {
    return getGroupPath(group);
  }

  /**
   * 在组中搜索（递归）
   */
  private searchInGroup(group: KdbxGroup, criteria: SearchCriteria, results: SearchResult[]): void {
    // 跳过回收站组 - 搜索不应该包含已删除的条目
    if (group.name === 'Recycle Bin') {
      return;
    }

    // 搜索当前组的条目
    for (let i = 0; i < group.entries.length; i++) {
      const entry = group.entries[i];
      const matchedFields = this.getMatchedFields(entry, criteria);
      
      if (matchedFields.length > 0) {
        results.push({
          entry,
          group,
          matchedFields
        });
      }
    }

    // 递归搜索子组
    for (let i = 0; i < group.groups.length; i++) {
      const childGroup = group.groups[i];
      this.searchInGroup(childGroup, criteria, results);
    }
  }

  /**
   * 获取匹配的字段
   */
  private getMatchedFields(entry: KdbxEntry, criteria: SearchCriteria): string[] {
    const matchedFields: string[] = [];
    const query = criteria.caseSensitive ? criteria.query : criteria.query.toLowerCase();

    // 检查标题
    if (criteria.searchInTitles !== false) {
      const title = getEntryDisplayText(entry, 'Title');
      const searchText = criteria.caseSensitive ? title : title.toLowerCase();
      
      if (this.textMatches(searchText, query, criteria.useRegex)) {
        matchedFields.push('Title');
      }
    }

    // 检查用户名
    if (criteria.searchInUsernames !== false) {
      const username = getEntryDisplayText(entry, 'UserName');
      const searchText = criteria.caseSensitive ? username : username.toLowerCase();
      
      if (this.textMatches(searchText, query, criteria.useRegex)) {
        matchedFields.push('UserName');
      }
    }

    // 检查URL
    if (criteria.searchInUrls !== false) {
      const url = getEntryDisplayText(entry, 'URL');
      const searchText = criteria.caseSensitive ? url : url.toLowerCase();
      
      if (this.textMatches(searchText, query, criteria.useRegex)) {
        matchedFields.push('URL');
      }
    }

    // 检查备注
    if (criteria.searchInNotes !== false) {
      const notes = getEntryDisplayText(entry, 'Notes');
      const searchText = criteria.caseSensitive ? notes : notes.toLowerCase();
      
      if (this.textMatches(searchText, query, criteria.useRegex)) {
        matchedFields.push('Notes');
      }
    }

    return matchedFields;
  }

  /**
   * 文本匹配检查
   */
  private textMatches(text: string, query: string, useRegex?: boolean): boolean {
    if (!text || !query) return false;

    if (useRegex) {
      try {
        const regex = new RegExp(query);
        return regex.test(text);
      } catch {
        // 如果正则表达式无效，回退到普通搜索
        return text.includes(query);
      }
    } else {
      return text.includes(query);
    }
  }

  /**
   * 从组中收集所有条目（递归）
   */
  private collectEntriesFromGroup(group: KdbxGroup, entries: KdbxEntry[]): void {
    // 添加当前组的条目
    for (let i = 0; i < group.entries.length; i++) {
      entries.push(group.entries[i]);
    }

    // 递归处理子组
    for (let i = 0; i < group.groups.length; i++) {
      const childGroup = group.groups[i];
      this.collectEntriesFromGroup(childGroup, entries);
    }
  }

  /**
   * 从组中收集所有组（递归）
   */
  private collectGroupsFromGroup(group: KdbxGroup, groups: KdbxGroup[]): void {
    // 添加当前组
    groups.push(group);

    // 递归处理子组
    for (let i = 0; i < group.groups.length; i++) {
      const childGroup = group.groups[i];
      this.collectGroupsFromGroup(childGroup, groups);
    }
  }

  /**
   * 检查条目是否匹配过滤器
   */
  private matchesEntryFilter(entry: KdbxEntry, filter: EntryFilter): boolean {
    // 检查是否有密码
    if (filter.hasPassword !== undefined) {
      const password = getEntryDisplayText(entry, 'Password');
      const hasPassword = password && password.trim().length > 0;
      if (filter.hasPassword !== hasPassword) {
        return false;
      }
    }

    // 检查是否有URL
    if (filter.hasUrl !== undefined) {
      const url = getEntryDisplayText(entry, 'URL');
      const hasUrl = url && url.trim().length > 0;
      if (filter.hasUrl !== hasUrl) {
        return false;
      }
    }

    // 检查是否有备注
    if (filter.hasNotes !== undefined) {
      const notes = getEntryDisplayText(entry, 'Notes');
      const hasNotes = notes && notes.trim().length > 0;
      if (filter.hasNotes !== hasNotes) {
        return false;
      }
    }

    // 检查创建时间
    if (filter.createdAfter && entry.times && entry.times.creationTime) {
      if (entry.times.creationTime <= filter.createdAfter) {
        return false;
      }
    }

    if (filter.createdBefore && entry.times && entry.times.creationTime) {
      if (entry.times.creationTime >= filter.createdBefore) {
        return false;
      }
    }

    // 检查修改时间
    if (filter.modifiedAfter && entry.times && entry.times.lastModTime) {
      if (entry.times.lastModTime <= filter.modifiedAfter) {
        return false;
      }
    }

    if (filter.modifiedBefore && entry.times && entry.times.lastModTime) {
      if (entry.times.lastModTime >= filter.modifiedBefore) {
        return false;
      }
    }

    return true;
  }

  /**
   * 检查组是否匹配过滤器
   */
  private matchesGroupFilter(group: KdbxGroup, filter: GroupFilter): boolean {
    // 检查是否有条目
    if (filter.hasEntries !== undefined) {
      const hasEntries = group.entries.length > 0;
      if (filter.hasEntries !== hasEntries) {
        return false;
      }
    }

    // 检查是否有子组
    if (filter.hasSubGroups !== undefined) {
      const hasSubGroups = group.groups.length > 0;
      if (filter.hasSubGroups !== hasSubGroups) {
        return false;
      }
    }

    // 检查条目数量范围
    if (filter.minEntryCount !== undefined) {
      if (group.entries.length < filter.minEntryCount) {
        return false;
      }
    }

    if (filter.maxEntryCount !== undefined) {
      if (group.entries.length > filter.maxEntryCount) {
        return false;
      }
    }

    // 检查创建时间
    if (filter.createdAfter && group.times && group.times.creationTime) {
      if (group.times.creationTime <= filter.createdAfter) {
        return false;
      }
    }

    if (filter.createdBefore && group.times && group.times.creationTime) {
      if (group.times.creationTime >= filter.createdBefore) {
        return false;
      }
    }

    return true;
  }
}

export default KdbxQuery; 