import { hilog } from '@kit.PerformanceAnalysisKit';
import { Kdbx, KdbxEntry, KdbxGroup, KdbxUuid, ProtectedValue } from '../lib';
import { 
  EntryCreateParams, 
  EntryUpdateParams, 
  OperationResult,
  DatabaseEventType,
  EntryInfo,
  LogParams,
  EventData
} from './KdbxTypes';
import { 
  setEntryField,
  getEntryDisplayText,
  isValidEntryTitle,
  cleanText,
  logOperation,
  logError,
  getGroupPath
} from './KdbxUtils';

const TAG = 'KdbxEntryManager';

// ArkTS 限制：不直接修改内部 private 字段

/**
 * KDBX条目管理类
 */
export class KdbxEntryManager {
  private database: Kdbx | null = null;
  private onEvent?: (eventType: DatabaseEventType, data?: EventData) => void;

  /**
   * 构造函数
   */
  constructor(database?: Kdbx, onEvent?: (eventType: DatabaseEventType, data?: EventData) => void) {
    this.database = database || null;
    this.onEvent = onEvent;
  }

  /**
   * 设置数据库实例
   */
  setDatabase(database: Kdbx): void {
    this.database = database;
  }

  /**
   * 设置事件回调
   */
  setEventCallback(onEvent: (eventType: DatabaseEventType, data?: EventData) => void): void {
    this.onEvent = onEvent;
  }

  /**
   * 创建新条目
   */
  createEntry(params: EntryCreateParams): OperationResult<KdbxEntry> {
    try {
      if (!this.database) {
        return {
          success: false,
          error: '数据库未设置',
          errorCode: 'DATABASE_NOT_SET'
        };
      }

      logOperation('createEntry', { title: params.title });

      // 验证标题
      if (!isValidEntryTitle(params.title)) {
        return {
          success: false,
          error: '条目标题无效',
          errorCode: 'INVALID_TITLE'
        };
      }

      // 获取父组
      let parentGroup = params.parentGroup;
      if (!parentGroup) {
        parentGroup = this.database.getDefaultGroup();
        if (!parentGroup) {
          return {
            success: false,
            error: '无法获取默认组',
            errorCode: 'NO_DEFAULT_GROUP'
          };
        }
      }

      // 创建新条目
      const entry = this.database.createEntry(parentGroup);
      if (!entry) {
        return {
          success: false,
          error: '创建条目失败',
          errorCode: 'CREATE_FAILED'
        };
      }

      // 设置字段
      this.setEntryFields(entry, params);

      // 更新时间戳
      if (entry.times) {
        const now = new Date();
        entry.times.creationTime = now;
        entry.times.lastModTime = now;
        entry.times.lastAccessTime = now;
      }

      // 标记数据库已修改
      this.markModified();

      hilog.info(0, TAG, '条目创建成功: %{public}s', params.title);

      // 触发事件
      if (this.onEvent) {
        const eventData: EventData = {
          entryId: entry.uuid.id,
          title: params.title,
          groupId: parentGroup.uuid.id
        };
        this.onEvent(DatabaseEventType.ENTRY_CREATED, eventData);
      }

      return {
        success: true,
        data: entry
      };

    } catch (error) {
      logError('createEntry', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'CREATE_ERROR'
      };
    }
  }

  /**
   * 更新条目
   */
  updateEntry(entry: KdbxEntry, params: EntryUpdateParams): OperationResult<KdbxEntry> {
    try {
      if (!this.database) {
        return {
          success: false,
          error: '数据库未设置',
          errorCode: 'DATABASE_NOT_SET'
        };
      }

      logOperation('updateEntry', { entryId: entry.uuid.id });

      // 验证标题（如果提供）
      if (params.title !== undefined && !isValidEntryTitle(params.title)) {
        return {
          success: false,
          error: '条目标题无效',
          errorCode: 'INVALID_TITLE'
        };
      }

      // 更新字段
      this.updateEntryFields(entry, params);

      // 更新时间戳
      if (entry.times) {
        entry.times.lastModTime = new Date();
      }

      // 标记数据库已修改
      this.markModified();

      hilog.info(0, TAG, '条目更新成功: %{public}s', entry.uuid.id);

      // 触发事件
      if (this.onEvent) {
        const eventData: EventData = {
          entryId: entry.uuid.id,
          changes: Object.keys(params)
        };
        this.onEvent(DatabaseEventType.ENTRY_UPDATED, eventData);
      }

      return {
        success: true,
        data: entry
      };

    } catch (error) {
      logError('updateEntry', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'UPDATE_ERROR'
      };
    }
  }

  /**
   * 删除条目
   */
  deleteEntry(entry: KdbxEntry): OperationResult<void> {
    try {
      if (!this.database) {
        return {
          success: false,
          error: '数据库未设置',
          errorCode: 'DATABASE_NOT_SET'
        };
      }

      logOperation('deleteEntry', { entryId: entry.uuid.id });

      const parentGroup = entry.parentGroup;
      if (!parentGroup) {
        return {
          success: false,
          error: '条目没有父组',
          errorCode: 'NO_PARENT_GROUP'
        };
      }

      // 这个检查是为了防止删除回收站组本身，但不应该阻止删除回收站中的条目
      // 所以这个检查应该移除，因为我们要删除的是条目，不是组

      const inRecycle = this.isInRecycleBin(parentGroup);

      hilog.info(0, TAG, '删除条目: %{public}s, 父组: %{public}s, 是否在回收站: %{public}s', 
        entry.uuid.id, parentGroup.name || '未知', inRecycle ? '是' : '否');

      if (!inRecycle) {
        // 软删除：移动到回收站
        hilog.info(0, TAG, '执行软删除，移动到回收站');
        this.database.remove(entry);
      } else {
        // 真正删除（仅限回收站内部）
        hilog.info(0, TAG, '执行硬删除，直接删除条目');
        const entryIndex = parentGroup.entries.indexOf(entry);
        if (entryIndex === -1) {
          hilog.error(0, TAG, '条目不在父组中，删除失败');
          return {
            success: false,
            error: '条目不在父组中',
            errorCode: 'ENTRY_NOT_IN_GROUP'
          };
        }
        parentGroup.entries.splice(entryIndex, 1);
        hilog.info(0, TAG, '硬删除完成，已从父组中移除条目');
      }

      // 标记数据库已修改
      this.markModified();

      hilog.info(0, TAG, '条目删除成功: %{public}s', entry.uuid.id);

      // 触发事件
      if (this.onEvent) {
        const eventData: EventData = {
          entryId: entry.uuid.id,
          title: getEntryDisplayText(entry, 'Title'),
          groupId: parentGroup.uuid.id
        };
        this.onEvent(DatabaseEventType.ENTRY_DELETED, eventData);
      }

      return {
        success: true
      };

    } catch (error) {
      logError('deleteEntry', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'DELETE_ERROR'
      };
    }
  }

  /**
   * 移动条目到另一个组
   */
  moveEntry(entry: KdbxEntry, targetGroup: KdbxGroup): OperationResult<void> {
    try {
      if (!this.database) {
        return {
          success: false,
          error: '数据库未设置',
          errorCode: 'DATABASE_NOT_SET'
        };
      }

      logOperation('moveEntry', {
        entryId: entry.uuid.id,
        targetGroupId: targetGroup.uuid.id
      });

      const currentGroup = entry.parentGroup;
      if (!currentGroup) {
        return {
          success: false,
          error: '条目没有当前组',
          errorCode: 'NO_CURRENT_GROUP'
        };
      }

      if (currentGroup === targetGroup) {
        return {
          success: true // 已经在目标组中
        };
      }

      // 从当前组中移除
      const entryIndex = currentGroup.entries.indexOf(entry);
      if (entryIndex === -1) {
        return {
          success: false,
          error: '条目不在当前组中',
          errorCode: 'ENTRY_NOT_IN_CURRENT_GROUP'
        };
      }

      currentGroup.entries.splice(entryIndex, 1);

      // 添加到目标组
      targetGroup.entries.push(entry);
      entry.parentGroup = targetGroup;

      // 更新时间戳
      if (entry.times) {
        entry.times.lastModTime = new Date();
      }

      hilog.info(0, TAG, '条目移动成功: %{public}s', entry.uuid.id);

      // 触发事件
      if (this.onEvent) {
        const eventData: EventData = {
          entryId: entry.uuid.id,
          action: 'moved',
          fromGroupId: currentGroup.uuid.id,
          toGroupId: targetGroup.uuid.id
        };
        this.onEvent(DatabaseEventType.ENTRY_UPDATED, eventData);
      }

      return {
        success: true
      };

    } catch (error) {
      logError('moveEntry', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'MOVE_ERROR'
      };
    }
  }

  /**
   * 获取指定组的条目
   */
  getEntriesInGroup(groupId: string): OperationResult<EntryInfo[]> {
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

      // 查找指定组
      const targetGroup = this.findGroupById(rootGroup, groupId);
      if (!targetGroup) {
        return {
          success: false,
          error: '组不存在',
          errorCode: 'GROUP_NOT_FOUND'
        };
      }

      // 转换条目为EntryInfo
      const entryInfos: EntryInfo[] = [];
      for (let i = 0; i < targetGroup.entries.length; i++) {
        const entry = targetGroup.entries[i];
        const entryInfo: EntryInfo = {
          id: entry.uuid.id,
          title: getEntryDisplayText(entry, 'Title') || '未命名条目',
          username: getEntryDisplayText(entry, 'UserName') || undefined,
          password: getEntryDisplayText(entry, 'Password') || undefined,
          url: getEntryDisplayText(entry, 'URL') || undefined,
          notes: getEntryDisplayText(entry, 'Notes') || undefined,
          groupId: targetGroup.uuid.id,
          groupPath: getGroupPath(targetGroup),
          hasPassword: !!entry.fields.get('Password'),
          customFields: this.getCustomFields(entry),
          creationTime: entry.times?.creationTime || undefined,
          lastModTime: entry.times?.lastModTime || undefined,
          lastAccessTime: entry.times?.lastAccessTime || undefined
        };
        entryInfos.push(entryInfo);
      }

      return {
        success: true,
        data: entryInfos
      };

    } catch (error) {
      logError('getEntriesInGroup', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'GET_ENTRIES_IN_GROUP_ERROR'
      };
    }
  }

  /**
   * 根据ID查找组
   */
  private findGroupById(group: KdbxGroup, groupId: string): KdbxGroup | null {
    if (group.uuid.id === groupId) {
      return group;
    }

    for (let i = 0; i < group.groups.length; i++) {
      const found = this.findGroupById(group.groups[i], groupId);
      if (found) return found;
    }

    return null;
  }

  /**
   * 获取自定义字段
   */
  private getCustomFields(entry: KdbxEntry): Record<string, string> {
    const customFields: Record<string, string> = {};
    const standardFields = ['Title', 'UserName', 'Password', 'URL', 'Notes'];
    
    const fieldEntries = Array.from(entry.fields.entries());
    for (let i = 0; i < fieldEntries.length; i++) {
      const key = fieldEntries[i][0];
      const value = fieldEntries[i][1];
      
      if (!standardFields.includes(key)) {
        if (value instanceof ProtectedValue) {
          customFields[key] = value.getText();
        } else {
          customFields[key] = value as string;
        }
      }
    }
    
    return customFields;
  }

  /**
   * 复制条目
   */
  copyEntry(entry: KdbxEntry, targetGroup?: KdbxGroup): OperationResult<KdbxEntry> {
    try {
      if (!this.database) {
        return {
          success: false,
          error: '数据库未设置',
          errorCode: 'DATABASE_NOT_SET'
        };
      }

      logOperation('copyEntry', { entryId: entry.uuid.id });

      // 确定目标组
      let group = targetGroup;
      if (!group) {
        group = entry.parentGroup;
        if (!group) {
          group = this.database.getDefaultGroup();
          if (!group) {
            return {
              success: false,
              error: '无法确定目标组',
              errorCode: 'NO_TARGET_GROUP'
            };
          }
        }
      }

      // 创建新条目
      const newEntry = this.database.createEntry(group);
      if (!newEntry) {
        return {
          success: false,
          error: '创建新条目失败',
          errorCode: 'CREATE_COPY_FAILED'
        };
      }

      // 复制字段
      const fieldEntries = Array.from(entry.fields.entries());
      for (let i = 0; i < fieldEntries.length; i++) {
        const key = fieldEntries[i][0];
        const value = fieldEntries[i][1];
        
        if (value instanceof ProtectedValue) {
          newEntry.fields.set(key, ProtectedValue.fromString(value.getText()));
        } else {
          newEntry.fields.set(key, value as string);
        }
      }

      // 复制自定义数据
      if (entry.customData) {
        if (!newEntry.customData) {
          newEntry.customData = new Map();
        }
        const customEntries = Array.from(entry.customData.entries());
        for (let i = 0; i < customEntries.length; i++) {
          const key = customEntries[i][0];
          const value = customEntries[i][1];
          newEntry.customData.set(key, value);
        }
      }

      // 更新标题以表明这是副本
      const originalTitle = getEntryDisplayText(entry, 'Title');
      setEntryField(newEntry, 'Title', `${originalTitle} - 副本`);

      // 设置时间戳
      if (newEntry.times) {
        const now = new Date();
        newEntry.times.creationTime = now;
        newEntry.times.lastModTime = now;
        newEntry.times.lastAccessTime = now;
      }

      hilog.info(0, TAG, '条目复制成功: %{public}s', newEntry.uuid.id);

      // 触发事件
      if (this.onEvent) {
        const eventData: EventData = {
          entryId: newEntry.uuid.id,
          action: 'copied',
          sourceEntryId: entry.uuid.id,
          groupId: group.uuid.id
        };
        this.onEvent(DatabaseEventType.ENTRY_CREATED, eventData);
      }

      return {
        success: true,
        data: newEntry
      };

    } catch (error) {
      logError('copyEntry', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'COPY_ERROR'
      };
    }
  }

  /**
   * 设置条目字段
   */
  private setEntryFields(entry: KdbxEntry, params: EntryCreateParams): void {
    // 设置标题
    setEntryField(entry, 'Title', cleanText(params.title));

    // 设置用户名
    if (params.username !== undefined) {
      setEntryField(entry, 'UserName', cleanText(params.username));
    }

    // 设置密码（受保护）
    if (params.password !== undefined) {
      setEntryField(entry, 'Password', params.password, true);
    }

    // 设置URL
    if (params.url !== undefined) {
      setEntryField(entry, 'URL', cleanText(params.url));
    }

    // 设置备注
    if (params.notes !== undefined) {
      setEntryField(entry, 'Notes', cleanText(params.notes));
    }

    // 设置自定义字段
    if (params.customFields) {
      const customEntries = Array.from(params.customFields.entries());
      for (let i = 0; i < customEntries.length; i++) {
        const key = customEntries[i][0];
        const value = customEntries[i][1];
        
        if (value instanceof ProtectedValue) {
          entry.fields.set(key, value);
        } else {
          entry.fields.set(key, cleanText(value as string));
        }
      }
    }
  }

  /**
   * 更新条目字段
   */
  private updateEntryFields(entry: KdbxEntry, params: EntryUpdateParams): void {
    // 更新标题
    if (params.title !== undefined) {
      setEntryField(entry, 'Title', cleanText(params.title));
    }

    // 更新用户名
    if (params.username !== undefined) {
      setEntryField(entry, 'UserName', cleanText(params.username));
    }

    // 更新密码（受保护）
    if (params.password !== undefined) {
      setEntryField(entry, 'Password', params.password, true);
    }

    // 更新URL
    if (params.url !== undefined) {
      setEntryField(entry, 'URL', cleanText(params.url));
    }

    // 更新备注
    if (params.notes !== undefined) {
      setEntryField(entry, 'Notes', cleanText(params.notes));
    }

    // 更新自定义字段
    if (params.customFields) {
      const customEntries = Array.from(params.customFields.entries());
      for (let i = 0; i < customEntries.length; i++) {
        const key = customEntries[i][0];
        const value = customEntries[i][1];
        
        if (value instanceof ProtectedValue) {
          entry.fields.set(key, value);
        } else {
          entry.fields.set(key, cleanText(value as string));
        }
      }
    }
  }

  /**
   * 标记数据库已修改
   */
  private markModified(): void {
    if (!this.database) {
      return;
    }
    if (this.database.meta) {
      this.database.meta.settingsChanged = new Date();
      this.database.meta.headerHash = undefined; // 触发完整序列化
    }
  }

  /**
   * 判断给定组是否位于回收站中
   */
  private isInRecycleBin(group?: KdbxGroup): boolean {
    if (!this.database || !group) {
      return false;
    }
    const recycleUuid = this.database.meta?.recycleBinUuid;
    let current: KdbxGroup | undefined = group;
    while (current) {
      if (recycleUuid && current.uuid.id === recycleUuid.id) {
        return true;
      }
      current = current.parentGroup;
    }
    return false;
  }

  /**
   * 检查条目是否已加星
   */
  isEntryStarred(entry: KdbxEntry): boolean {
    try {
      // 检查标签
      if (entry.tags && entry.tags.length > 0) {
        const hasStarTag = entry.tags.some(tag => 
          tag.toLowerCase().includes('star') || 
          tag.toLowerCase().includes('favorite')
        );
        if (hasStarTag) {
          return true;
        }
      }
      
      // 检查自定义字段
      const customFields = entry.fields;
      for (const fieldEntry of customFields.entries()) {
        const key = fieldEntry[0];
        const value = fieldEntry[1];
        if (key.toLowerCase().includes('star') || key.toLowerCase().includes('favorite')) {
          const fieldValue = (value && typeof value === 'object' && (value as ESObject).getText) ? 
            (value as ESObject).getText() as string : value;
          if (fieldValue && fieldValue.toString().toLowerCase() === 'true') {
            return true;
          }
        }
      }
      
      return false;
    } catch (error) {
      logError('isEntryStarred', error as Error);
      return false;
    }
  }

  /**
   * 添加条目星标
   */
  addStarToEntry(entry: KdbxEntry): OperationResult<KdbxEntry> {
    try {
      if (!this.database) {
        return {
          success: false,
          error: '数据库未设置',
          errorCode: 'DATABASE_NOT_SET'
        };
      }

      // 检查是否已经加星
      if (this.isEntryStarred(entry)) {
        return {
          success: true,
          data: entry
        };
      }

      // 添加星标标签
      const starTag = 'star';
      if (!entry.tags.includes(starTag)) {
        entry.tags.push(starTag);
      }

      // 更新时间戳
      if (entry.times) {
        entry.times.lastModTime = new Date();
      }

      // 标记数据库已修改
      this.markModified();

      hilog.info(0, TAG, '条目添加星标成功: %{public}s', entry.uuid.id);

      // 触发事件
      if (this.onEvent) {
        const eventData: EventData = {
          entryId: entry.uuid.id,
          action: 'starred'
        };
        this.onEvent(DatabaseEventType.ENTRY_UPDATED, eventData);
      }

      return {
        success: true,
        data: entry
      };

    } catch (error) {
      logError('addStarToEntry', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'ADD_STAR_ERROR'
      };
    }
  }

  /**
   * 移除条目星标
   */
  removeStarFromEntry(entry: KdbxEntry): OperationResult<KdbxEntry> {
    try {
      if (!this.database) {
        return {
          success: false,
          error: '数据库未设置',
          errorCode: 'DATABASE_NOT_SET'
        };
      }

      // 移除星标标签
      entry.tags = entry.tags.filter(tag => 
        !tag.toLowerCase().includes('star') && 
        !tag.toLowerCase().includes('favorite')
      );

      // 移除星标相关的自定义字段
      const fieldsToRemove: string[] = [];
      for (const fieldEntry of entry.fields.entries()) {
        const key = fieldEntry[0];
        if (key.toLowerCase().includes('star') || key.toLowerCase().includes('favorite')) {
          fieldsToRemove.push(key);
        }
      }
      
      for (const key of fieldsToRemove) {
        entry.fields.delete(key);
      }

      // 更新时间戳
      if (entry.times) {
        entry.times.lastModTime = new Date();
      }

      // 标记数据库已修改
      this.markModified();

      hilog.info(0, TAG, '条目移除星标成功: %{public}s', entry.uuid.id);

      // 触发事件
      if (this.onEvent) {
        const eventData: EventData = {
          entryId: entry.uuid.id,
          action: 'unstarred'
        };
        this.onEvent(DatabaseEventType.ENTRY_UPDATED, eventData);
      }

      return {
        success: true,
        data: entry
      };

    } catch (error) {
      logError('removeStarFromEntry', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'REMOVE_STAR_ERROR'
      };
    }
  }

  /**
   * 切换条目星标状态
   */
  toggleEntryStarred(entry: KdbxEntry): OperationResult<KdbxEntry> {
    try {
      if (this.isEntryStarred(entry)) {
        return this.removeStarFromEntry(entry);
      } else {
        return this.addStarToEntry(entry);
      }
    } catch (error) {
      logError('toggleEntryStarred', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'TOGGLE_STAR_ERROR'
      };
    }
  }
}

export default KdbxEntryManager; 