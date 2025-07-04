import { hilog } from '@kit.PerformanceAnalysisKit';
import { Kdbx, KdbxGroup, KdbxEntry, KdbxUuid } from '../lib';
import { 
  GroupCreateParams, 
  GroupUpdateParams, 
  OperationResult,
  DatabaseEventType 
} from './KdbxTypes';
import { 
  isValidGroupName,
  cleanText,
  getGroupPath,
  logOperation,
  logError 
} from './KdbxUtils';

const TAG = 'KdbxGroupManager';

/**
 * KDBX组管理类
 */
export class KdbxGroupManager {
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
   * 创建新组
   */
  createGroup(params: GroupCreateParams): OperationResult<KdbxGroup> {
    try {
      if (!this.database) {
        return {
          success: false,
          error: '数据库未设置',
          errorCode: 'DATABASE_NOT_SET'
        };
      }

      logOperation('createGroup', { name: params.name });

      // 验证组名
      if (!isValidGroupName(params.name)) {
        return {
          success: false,
          error: '组名无效',
          errorCode: 'INVALID_GROUP_NAME'
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

      // 检查同名组
      const existingGroup = this.findChildGroupByName(parentGroup, params.name);
      if (existingGroup) {
        return {
          success: false,
          error: '同名组已存在',
          errorCode: 'GROUP_NAME_EXISTS'
        };
      }

      // 创建新组
      const group = this.database.createGroup(parentGroup, params.name);
      if (!group) {
        return {
          success: false,
          error: '创建组失败',
          errorCode: 'CREATE_FAILED'
        };
      }

      // 设置组属性
      group.name = cleanText(params.name);
      if (params.notes) {
        group.notes = cleanText(params.notes);
      }

      // 更新时间戳
      if (group.times) {
        const now = new Date();
        group.times.creationTime = now;
        group.times.lastModTime = now;
        group.times.lastAccessTime = now;
      }

      hilog.info(0, TAG, '组创建成功: %{public}s', params.name);

      // 触发事件
      if (this.onEvent) {
        this.onEvent(DatabaseEventType.GROUP_CREATED, {
          groupId: group.uuid.id,
          name: params.name,
          parentGroupId: parentGroup.uuid.id,
          path: getGroupPath(group)
        });
      }

      return {
        success: true,
        data: group
      };

    } catch (error) {
      logError('createGroup', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'CREATE_ERROR'
      };
    }
  }

  /**
   * 更新组
   */
  updateGroup(group: KdbxGroup, params: GroupUpdateParams): OperationResult<KdbxGroup> {
    try {
      if (!this.database) {
        return {
          success: false,
          error: '数据库未设置',
          errorCode: 'DATABASE_NOT_SET'
        };
      }

      logOperation('updateGroup', { groupId: group.uuid.id });

      // 验证组名（如果提供）
      if (params.name !== undefined && !isValidGroupName(params.name)) {
        return {
          success: false,
          error: '组名无效',
          errorCode: 'INVALID_GROUP_NAME'
        };
      }

      // 检查同名组（如果更改了名称）
      if (params.name !== undefined && params.name !== group.name) {
        const parentGroup = group.parentGroup;
        if (parentGroup) {
          const existingGroup = this.findChildGroupByName(parentGroup, params.name);
          if (existingGroup && existingGroup !== group) {
            return {
              success: false,
              error: '同名组已存在',
              errorCode: 'GROUP_NAME_EXISTS'
            };
          }
        }
      }

      // 更新属性
      if (params.name !== undefined) {
        group.name = cleanText(params.name);
      }

      if (params.notes !== undefined) {
        group.notes = cleanText(params.notes);
      }

      // 更新时间戳
      if (group.times) {
        group.times.lastModTime = new Date();
      }

      hilog.info(0, TAG, '组更新成功: %{public}s', group.uuid.id);

      // 触发事件
      if (this.onEvent) {
        this.onEvent(DatabaseEventType.GROUP_UPDATED, {
          groupId: group.uuid.id,
          changes: Object.keys(params),
          path: getGroupPath(group)
        });
      }

      return {
        success: true,
        data: group
      };

    } catch (error) {
      logError('updateGroup', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'UPDATE_ERROR'
      };
    }
  }

  /**
   * 删除组
   */
  deleteGroup(group: KdbxGroup): OperationResult<void> {
    try {
      if (!this.database) {
        return {
          success: false,
          error: '数据库未设置',
          errorCode: 'DATABASE_NOT_SET'
        };
      }

      logOperation('deleteGroup', { groupId: group.uuid.id });

      // 检查是否是根组
      const rootGroup = this.database.getDefaultGroup();
      if (group === rootGroup) {
        return {
          success: false,
          error: '不能删除根组',
          errorCode: 'CANNOT_DELETE_ROOT_GROUP'
        };
      }

      const parentGroup = group.parentGroup;
      if (!parentGroup) {
        return {
          success: false,
          error: '组没有父组',
          errorCode: 'NO_PARENT_GROUP'
        };
      }

      // 检查组是否为空
      if (group.entries.length > 0 || group.groups.length > 0) {
        return {
          success: false,
          error: '组不为空，无法删除',
          errorCode: 'GROUP_NOT_EMPTY'
        };
      }

      // 从父组中移除
      const groupIndex = parentGroup.groups.indexOf(group);
      if (groupIndex === -1) {
        return {
          success: false,
          error: '组不在父组中',
          errorCode: 'GROUP_NOT_IN_PARENT'
        };
      }

      parentGroup.groups.splice(groupIndex, 1);

      hilog.info(0, TAG, '组删除成功: %{public}s', group.uuid.id);

      // 触发事件
      if (this.onEvent) {
        this.onEvent(DatabaseEventType.GROUP_DELETED, {
          groupId: group.uuid.id,
          name: group.name,
          parentGroupId: parentGroup.uuid.id
        });
      }

      return {
        success: true
      };

    } catch (error) {
      logError('deleteGroup', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'DELETE_ERROR'
      };
    }
  }

  /**
   * 删除组（递归删除所有内容）
   */
  deleteGroupRecursive(group: KdbxGroup): OperationResult<void> {
    try {
      if (!this.database) {
        return {
          success: false,
          error: '数据库未设置',
          errorCode: 'DATABASE_NOT_SET'
        };
      }

      logOperation('deleteGroupRecursive', { groupId: group.uuid.id });

      // 检查是否是根组
      const rootGroup = this.database.getDefaultGroup();
      if (group === rootGroup) {
        return {
          success: false,
          error: '不能删除根组',
          errorCode: 'CANNOT_DELETE_ROOT_GROUP'
        };
      }

      const parentGroup = group.parentGroup;
      if (!parentGroup) {
        return {
          success: false,
          error: '组没有父组',
          errorCode: 'NO_PARENT_GROUP'
        };
      }

      // 统计要删除的内容
      const stats = this.countGroupContents(group);
      
      // 从父组中移除
      const groupIndex = parentGroup.groups.indexOf(group);
      if (groupIndex === -1) {
        return {
          success: false,
          error: '组不在父组中',
          errorCode: 'GROUP_NOT_IN_PARENT'
        };
      }

      parentGroup.groups.splice(groupIndex, 1);

      hilog.info(0, TAG, '组递归删除成功: %{public}s (包含 %{public}d 个条目, %{public}d 个子组)', 
        group.uuid.id, stats.entries, stats.groups - 1);

      // 触发事件
      if (this.onEvent) {
        this.onEvent(DatabaseEventType.GROUP_DELETED, {
          groupId: group.uuid.id,
          name: group.name,
          parentGroupId: parentGroup.uuid.id,
          recursive: true,
          deletedEntries: stats.entries,
          deletedGroups: stats.groups
        });
      }

      return {
        success: true
      };

    } catch (error) {
      logError('deleteGroupRecursive', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'DELETE_RECURSIVE_ERROR'
      };
    }
  }

  /**
   * 移动组到另一个父组
   */
  moveGroup(group: KdbxGroup, targetParentGroup: KdbxGroup): OperationResult<void> {
    try {
      if (!this.database) {
        return {
          success: false,
          error: '数据库未设置',
          errorCode: 'DATABASE_NOT_SET'
        };
      }

      logOperation('moveGroup', { 
        groupId: group.uuid.id, 
        targetParentGroupId: targetParentGroup.uuid.id 
      });

      // 检查是否是根组
      const rootGroup = this.database.getDefaultGroup();
      if (group === rootGroup) {
        return {
          success: false,
          error: '不能移动根组',
          errorCode: 'CANNOT_MOVE_ROOT_GROUP'
        };
      }

      const currentParentGroup = group.parentGroup;
      if (!currentParentGroup) {
        return {
          success: false,
          error: '组没有当前父组',
          errorCode: 'NO_CURRENT_PARENT_GROUP'
        };
      }

      if (currentParentGroup === targetParentGroup) {
        return {
          success: true // 已经在目标父组中
        };
      }

      // 检查是否会形成循环引用
      if (this.wouldCreateCircularReference(group, targetParentGroup)) {
        return {
          success: false,
          error: '移动会形成循环引用',
          errorCode: 'CIRCULAR_REFERENCE'
        };
      }

      // 检查目标父组中是否已有同名组
      const existingGroup = this.findChildGroupByName(targetParentGroup, group.name);
      if (existingGroup) {
        return {
          success: false,
          error: '目标组中已有同名组',
          errorCode: 'GROUP_NAME_EXISTS_IN_TARGET'
        };
      }

      // 从当前父组中移除
      const groupIndex = currentParentGroup.groups.indexOf(group);
      if (groupIndex === -1) {
        return {
          success: false,
          error: '组不在当前父组中',
          errorCode: 'GROUP_NOT_IN_CURRENT_PARENT'
        };
      }

      currentParentGroup.groups.splice(groupIndex, 1);

      // 添加到目标父组
      targetParentGroup.groups.push(group);
      group.parentGroup = targetParentGroup;

      // 更新时间戳
      if (group.times) {
        group.times.lastModTime = new Date();
      }

      hilog.info(0, TAG, '组移动成功: %{public}s', group.uuid.id);

      // 触发事件
      if (this.onEvent) {
        this.onEvent(DatabaseEventType.GROUP_UPDATED, {
          groupId: group.uuid.id,
          action: 'moved',
          fromParentGroupId: currentParentGroup.uuid.id,
          toParentGroupId: targetParentGroup.uuid.id,
          newPath: getGroupPath(group)
        });
      }

      return {
        success: true
      };

    } catch (error) {
      logError('moveGroup', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'MOVE_ERROR'
      };
    }
  }

  /**
   * 复制组
   */
  copyGroup(group: KdbxGroup, targetParentGroup?: KdbxGroup): OperationResult<KdbxGroup> {
    try {
      if (!this.database) {
        return {
          success: false,
          error: '数据库未设置',
          errorCode: 'DATABASE_NOT_SET'
        };
      }

      logOperation('copyGroup', { groupId: group.uuid.id });

      // 确定目标父组
      let parentGroup = targetParentGroup;
      if (!parentGroup) {
        parentGroup = group.parentGroup;
        if (!parentGroup) {
          parentGroup = this.database.getDefaultGroup();
          if (!parentGroup) {
            return {
              success: false,
              error: '无法确定目标父组',
              errorCode: 'NO_TARGET_PARENT_GROUP'
            };
          }
        }
      }

      // 生成新的组名
      let newName = `${group.name} - 副本`;
      let counter = 1;
      while (this.findChildGroupByName(parentGroup, newName)) {
        counter++;
        newName = `${group.name} - 副本 ${counter}`;
      }

      // 创建新组
      const newGroup = this.database.createGroup(parentGroup, newName);
      if (!newGroup) {
        return {
          success: false,
          error: '创建新组失败',
          errorCode: 'CREATE_COPY_FAILED'
        };
      }

      // 复制属性
      newGroup.name = newName;
      if (group.notes) {
        newGroup.notes = group.notes;
      }

      // 递归复制子组和条目
      this.copyGroupContents(group, newGroup);

      // 设置时间戳
      if (newGroup.times) {
        const now = new Date();
        newGroup.times.creationTime = now;
        newGroup.times.lastModTime = now;
        newGroup.times.lastAccessTime = now;
      }

      hilog.info(0, TAG, '组复制成功: %{public}s', newGroup.uuid.id);

      // 触发事件
      if (this.onEvent) {
        this.onEvent(DatabaseEventType.GROUP_CREATED, {
          groupId: newGroup.uuid.id,
          action: 'copied',
          sourceGroupId: group.uuid.id,
          name: newName,
          parentGroupId: parentGroup.uuid.id,
          path: getGroupPath(newGroup)
        });
      }

      return {
        success: true,
        data: newGroup
      };

    } catch (error) {
      logError('copyGroup', error as Error);
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'COPY_ERROR'
      };
    }
  }

  /**
   * 在子组中查找指定名称的组
   */
  private findChildGroupByName(parentGroup: KdbxGroup, name: string): KdbxGroup | null {
    for (let i = 0; i < parentGroup.groups.length; i++) {
      const childGroup = parentGroup.groups[i];
      if (childGroup.name === name) {
        return childGroup;
      }
    }
    return null;
  }

  /**
   * 检查是否会形成循环引用
   */
  private wouldCreateCircularReference(group: KdbxGroup, targetParentGroup: KdbxGroup): boolean {
    let current: KdbxGroup | null = targetParentGroup;
    while (current) {
      if (current === group) {
        return true;
      }
      current = current.parentGroup;
    }
    return false;
  }

  /**
   * 统计组内容
   */
  private countGroupContents(group: KdbxGroup): { entries: number; groups: number } {
    let entries = group.entries.length;
    let groups = 1; // 当前组

    for (let i = 0; i < group.groups.length; i++) {
      const childGroup = group.groups[i];
      const childStats = this.countGroupContents(childGroup);
      entries += childStats.entries;
      groups += childStats.groups;
    }

    return { entries, groups };
  }

  /**
   * 复制组内容（递归）
   */
  private copyGroupContents(sourceGroup: KdbxGroup, targetGroup: KdbxGroup): void {
    if (!this.database) return;

    // 复制条目
    for (let i = 0; i < sourceGroup.entries.length; i++) {
      const sourceEntry = sourceGroup.entries[i];
      const newEntry = this.database.createEntry(targetGroup);
      if (newEntry) {
        // 复制字段
        const fieldEntries = Array.from(sourceEntry.fields.entries());
        for (let j = 0; j < fieldEntries.length; j++) {
          const key = fieldEntries[j][0];
          const value = fieldEntries[j][1];
          newEntry.fields.set(key, value);
        }

        // 复制自定义数据
        if (sourceEntry.customData) {
          if (!newEntry.customData) {
            newEntry.customData = new Map();
          }
          const customEntries = Array.from(sourceEntry.customData.entries());
          for (let j = 0; j < customEntries.length; j++) {
            const key = customEntries[j][0];
            const value = customEntries[j][1];
            newEntry.customData.set(key, value);
          }
        }

        // 设置时间戳
        if (newEntry.times) {
          const now = new Date();
          newEntry.times.creationTime = now;
          newEntry.times.lastModTime = now;
          newEntry.times.lastAccessTime = now;
        }
      }
    }

    // 递归复制子组
    for (let i = 0; i < sourceGroup.groups.length; i++) {
      const sourceChildGroup = sourceGroup.groups[i];
      const newChildGroup = this.database.createGroup(targetGroup, sourceChildGroup.name);
      if (newChildGroup) {
        if (sourceChildGroup.notes) {
          newChildGroup.notes = sourceChildGroup.notes;
        }
        this.copyGroupContents(sourceChildGroup, newChildGroup);
      }
    }
  }
}

export default KdbxGroupManager; 