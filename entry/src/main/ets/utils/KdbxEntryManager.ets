import { hilog } from '@kit.PerformanceAnalysisKit';
import { Kdbx, KdbxEntry, KdbxGroup, KdbxUuid, ProtectedValue } from '../lib';
import { 
  EntryCreateParams, 
  EntryUpdateParams, 
  OperationResult,
  DatabaseEventType 
} from './KdbxTypes';
import { 
  setEntryField,
  getEntryDisplayText,
  isValidEntryTitle,
  cleanText,
  logOperation,
  logError 
} from './KdbxUtils';

const TAG = 'KdbxEntryManager';

/**
 * KDBX条目管理类
 */
export class KdbxEntryManager {
  private database: Kdbx | null = null;
  private onEvent?: (eventType: DatabaseEventType, data?: any) => void;

  /**
   * 构造函数
   */
  constructor(database?: Kdbx, onEvent?: (eventType: DatabaseEventType, data?: any) => void) {
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
  setEventCallback(onEvent: (eventType: DatabaseEventType, data?: any) => void): void {
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

      hilog.info(0, TAG, '条目创建成功: %{public}s', params.title);

      // 触发事件
      if (this.onEvent) {
        this.onEvent(DatabaseEventType.ENTRY_CREATED, {
          entryId: entry.uuid.id,
          title: params.title,
          groupId: parentGroup.uuid.id
        });
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

      hilog.info(0, TAG, '条目更新成功: %{public}s', entry.uuid.id);

      // 触发事件
      if (this.onEvent) {
        this.onEvent(DatabaseEventType.ENTRY_UPDATED, {
          entryId: entry.uuid.id,
          changes: Object.keys(params)
        });
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

      // 从父组中移除条目
      const entryIndex = parentGroup.entries.indexOf(entry);
      if (entryIndex === -1) {
        return {
          success: false,
          error: '条目不在父组中',
          errorCode: 'ENTRY_NOT_IN_GROUP'
        };
      }

      parentGroup.entries.splice(entryIndex, 1);

      hilog.info(0, TAG, '条目删除成功: %{public}s', entry.uuid.id);

      // 触发事件
      if (this.onEvent) {
        this.onEvent(DatabaseEventType.ENTRY_DELETED, {
          entryId: entry.uuid.id,
          title: getEntryDisplayText(entry, 'Title'),
          groupId: parentGroup.uuid.id
        });
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
        this.onEvent(DatabaseEventType.ENTRY_UPDATED, {
          entryId: entry.uuid.id,
          action: 'moved',
          fromGroupId: currentGroup.uuid.id,
          toGroupId: targetGroup.uuid.id
        });
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
        this.onEvent(DatabaseEventType.ENTRY_CREATED, {
          entryId: newEntry.uuid.id,
          action: 'copied',
          sourceEntryId: entry.uuid.id,
          groupId: group.uuid.id
        });
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
}

export default KdbxEntryManager; 