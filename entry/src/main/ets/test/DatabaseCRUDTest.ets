import { hilog } from '@kit.PerformanceAnalysisKit';
import { Context } from '@kit.AbilityKit';
import { KdbxCore, KdbxCoreManager } from '../utils/KdbxCore';
import { KdbxGroupManager } from '../utils/KdbxGroupManager';
import { KdbxEntryManager } from '../utils/KdbxEntryManager';
import { KdbxQuery } from '../utils/KdbxQuery';
import { DefaultDatabase } from '../utils/DefaultDatabase';
import { KdbxGroup, KdbxEntry } from '../lib';
import { 
  GroupCreateParams, 
  EntryCreateParams, 
  GroupUpdateParams, 
  EntryUpdateParams,
  DatabaseEventType,
  OperationResult,
  EntryInfo
} from '../utils/KdbxTypes';
import { getEntryDisplayText } from '../utils/KdbxUtils';

const TAG = 'DatabaseCRUDTest';

/**
 * 数据库增删改查完整测试
 */
export class DatabaseCRUDTest {
  private kdbxCore: KdbxCore | null = null;
  private groupManager: KdbxGroupManager | null = null;
  private entryManager: KdbxEntryManager | null = null;
  private kdbxQuery: KdbxQuery | null = null;
  private testResults: string[] = [];
  private databasePassword: string = '';

  /**
   * 初始化测试环境
   */
  async initializeTest(context: Context, existingKdbxCore?: KdbxCore, password?: string): Promise<boolean> {
    try {
      hilog.info(0, TAG, '开始初始化测试环境...');
      
      // 设置数据库密码
      this.databasePassword = password || 'test123456';
      
      if (existingKdbxCore) {
        // 使用已存在的KdbxCore实例
        this.kdbxCore = existingKdbxCore;
        hilog.info(0, TAG, '使用已存在的数据库实例');
      } else {
        // 设置默认数据库管理器的上下文
        const defaultDb = DefaultDatabase.getInstance();
        defaultDb.setContext(context);
        
        // 检查默认数据库是否存在，如果存在则删除
        if (await defaultDb.exists()) {
          await defaultDb.delete();
          hilog.info(0, TAG, '删除已存在的测试数据库');
        }
        
        // 创建新的测试数据库
        const createResult = await defaultDb.create(this.databasePassword);
        if (!createResult.success) {
          throw new Error(`创建测试数据库失败: ${createResult.error}`);
        }
        
        // 打开数据库
        const openResult = await defaultDb.open(this.databasePassword);
        if (!openResult.success || !openResult.data) {
          throw new Error(`打开测试数据库失败: ${openResult.error}`);
        }
        
        this.kdbxCore = openResult.data;
      }
      
      const database = this.kdbxCore.getDatabase();
      if (!database) {
        throw new Error('无法获取数据库实例');
      }
      
      // 初始化管理器
      this.groupManager = new KdbxGroupManager(database, this.onDatabaseEvent.bind(this));
      this.entryManager = new KdbxEntryManager(database, this.onDatabaseEvent.bind(this));
      this.kdbxQuery = new KdbxQuery(database);
      
      hilog.info(0, TAG, '测试环境初始化成功');
      return true;
      
    } catch (error) {
      hilog.error(0, TAG, '初始化测试环境失败: %{public}s', (error as Error).message);
      return false;
    }
  }

  /**
   * 数据库事件监听器
   */
  private onDatabaseEvent(eventType: DatabaseEventType, data?: Record<string, Object>): void {
    hilog.info(0, TAG, '数据库事件: %{public}s', eventType);
    if (data) {
      hilog.debug(0, TAG, '事件数据: %{public}s', JSON.stringify(data));
    }
  }

  /**
   * 获取条目标题的辅助方法（避免使用 `in`、类型守卫与 call/apply）
   */
  private getEntryTitle(entry: KdbxEntry | EntryInfo): string {
    const maybeInfo = entry as EntryInfo;
    if (typeof maybeInfo.title === 'string') {
      // EntryInfo 情况
      return maybeInfo.title.length > 0 ? maybeInfo.title : '未命名条目';
    }

    // 回退处理 KdbxEntry
    return getEntryDisplayText(entry as KdbxEntry, 'Title') || '未命名条目';
  }

  /**
   * 运行完整的CRUD测试
   */
  async runFullCRUDTest(): Promise<boolean> {
    try {
      hilog.info(0, TAG, '开始运行完整的CRUD测试...');
      this.testResults = [];
      
      // 初始状态检查 - 详细检查数据库结构
      await this.logDatabaseState('测试开始');
      await this.logRawDatabaseStructure('测试开始');
      
      // 1. 测试分组CRUD
      await this.testGroupCRUD();
      await this.logDatabaseState('分组CRUD测试后');
      await this.saveDatabase(); // 立即保存分组CRUD结果
      
      // 2. 测试条目CRUD
      await this.testEntryCRUD();
      await this.logDatabaseState('条目CRUD测试后');
      await this.saveDatabase(); // 立即保存条目CRUD结果
      
      // 3. 测试复合操作
      await this.testComplexOperations();
      await this.logDatabaseState('复合操作测试后');
      await this.saveDatabase(); // 立即保存复合操作结果
      
      // 4. 测试数据完整性
      await this.testDataIntegrity();
      await this.logDatabaseState('数据完整性测试后');
      
      // 5. 最终保存数据库
      await this.saveDatabase();
      await this.logDatabaseState('最终数据库保存后');
      
      // 6. 测试数据持久化 - 关闭重新打开验证数据一致性
      await this.testDataPersistence();
      
      // 打印测试结果
      this.printTestResults();
      
      hilog.info(0, TAG, '完整的CRUD测试完成');
      return true;
      
    } catch (error) {
      hilog.error(0, TAG, 'CRUD测试失败: %{public}s', (error as Error).message);
      return false;
    }
  }

  /**
   * 测试分组CRUD操作
   */
  private async testGroupCRUD(): Promise<void> {
    hilog.info(0, TAG, '开始测试分组CRUD操作...');
    
    if (!this.groupManager || !this.kdbxCore) {
      throw new Error('管理器未初始化');
    }

    const database = this.kdbxCore.getDatabase();
    if (!database) {
      throw new Error('数据库未加载');
    }

    const rootGroup = database.getDefaultGroup();
    if (!rootGroup) {
      throw new Error('根组不存在');
    }

    // 1. 创建分组（增）
    hilog.info(0, TAG, '测试创建分组...');
    const createParams: GroupCreateParams = {
      name: '工作账号',
      notes: '存储工作相关的账号信息',
      parentGroup: rootGroup
    };
    
    const createResult = this.groupManager.createGroup(createParams);
    if (!createResult.success || !createResult.data) {
      throw new Error(`创建分组失败: ${createResult.error}`);
    }
    
    const workGroup = createResult.data;
    this.testResults.push('✓ 创建分组成功');
    
    // 创建子分组
    const subGroupParams: GroupCreateParams = {
      name: '开发工具',
      notes: '开发相关的工具账号',
      parentGroup: workGroup
    };
    
    const subGroupResult = this.groupManager.createGroup(subGroupParams);
    if (!subGroupResult.success || !subGroupResult.data) {
      throw new Error(`创建子分组失败: ${subGroupResult.error}`);
    }
    
    const devGroup = subGroupResult.data;
    this.testResults.push('✓ 创建子分组成功');
    
    // 2. 查询分组（查）
    hilog.info(0, TAG, '测试查询分组...');
    const groupsResult = this.kdbxQuery!.getAllGroups();
    if (!groupsResult.success || !groupsResult.data) {
      throw new Error(`查询分组失败: ${groupsResult.error}`);
    }
    
    const groups: KdbxGroup[] = groupsResult.data;
    hilog.info(0, TAG, '找到 %{public}d 个分组', groups.length);
    this.testResults.push(`✓ 查询分组成功，共找到 ${groups.length} 个分组`);
    
    // 3. 更新分组（改）
    hilog.info(0, TAG, '测试更新分组...');
    const updateParams: GroupUpdateParams = {
      name: '工作账号 (已更新)',
      notes: '更新后的工作账号描述'
    };
    
    const updateResult = this.groupManager.updateGroup(workGroup, updateParams);
    if (!updateResult.success) {
      throw new Error(`更新分组失败: ${updateResult.error}`);
    }
    
    this.testResults.push('✓ 更新分组成功');
    
    // 4. 移动分组
    hilog.info(0, TAG, '测试移动分组...');
    const moveResult = this.groupManager.moveGroup(devGroup, rootGroup);
    if (!moveResult.success) {
      throw new Error(`移动分组失败: ${moveResult.error}`);
    }
    
    this.testResults.push('✓ 移动分组成功');
    
    // 5. 删除分组（删）
    hilog.info(0, TAG, '测试删除分组...');
    const deleteResult = this.groupManager.deleteGroup(devGroup);
    if (!deleteResult.success) {
      throw new Error(`删除分组失败: ${deleteResult.error}`);
    }
    
    this.testResults.push('✓ 删除分组成功');
    
    hilog.info(0, TAG, '分组CRUD操作测试完成');
  }

  /**
   * 测试条目CRUD操作
   */
  private async testEntryCRUD(): Promise<void> {
    hilog.info(0, TAG, '开始测试条目CRUD操作...');
    
    if (!this.entryManager || !this.kdbxCore) {
      throw new Error('管理器未初始化');
    }

    const database = this.kdbxCore.getDatabase();
    if (!database) {
      throw new Error('数据库未加载');
    }

    const rootGroup = database.getDefaultGroup();
    if (!rootGroup) {
      throw new Error('根组不存在');
    }

    // 1. 创建条目（增）
    hilog.info(0, TAG, '测试创建条目...');
    const createParams: EntryCreateParams = {
      title: '测试邮箱',
      username: 'test@example.com',
      password: 'password123',
      url: 'https://mail.example.com',
      notes: '这是一个测试邮箱账号',
      parentGroup: rootGroup
    };
    
    const createResult = this.entryManager.createEntry(createParams);
    if (!createResult.success || !createResult.data) {
      throw new Error(`创建条目失败: ${createResult.error}`);
    }
    
    const testEntry = createResult.data;
    this.testResults.push('✓ 创建条目成功');
    
    // 创建另一个条目
    const createParams2: EntryCreateParams = {
      title: '测试数据库',
      username: 'admin',
      password: 'dbpass456',
      url: 'http://localhost:3306',
      notes: '测试数据库连接信息',
      parentGroup: rootGroup
    };
    
    const createResult2 = this.entryManager.createEntry(createParams2);
    if (!createResult2.success || !createResult2.data) {
      throw new Error(`创建第二个条目失败: ${createResult2.error}`);
    }
    
    const testEntry2 = createResult2.data;
    this.testResults.push('✓ 创建第二个条目成功');
    
    // 2. 查询条目（查）
    hilog.info(0, TAG, '测试查询条目...');
    const entriesResult = this.entryManager.getEntriesInGroup(rootGroup.uuid.id);
    if (!entriesResult.success || !entriesResult.data) {
      throw new Error(`查询条目失败: ${entriesResult.error}`);
    }
    
    const entries = entriesResult.data;
    hilog.info(0, TAG, '找到 %{public}d 个条目', entries.length);
    this.testResults.push(`✓ 查询条目成功，共找到 ${entries.length} 个条目`);
    
    // 3. 更新条目（改）
    hilog.info(0, TAG, '测试更新条目...');
    const updateParams: EntryUpdateParams = {
      title: '测试邮箱 (已更新)',
      username: 'updated@example.com',
      password: 'newpassword789',
      notes: '更新后的邮箱账号信息'
    };
    
    const updateResult = this.entryManager.updateEntry(testEntry, updateParams);
    if (!updateResult.success) {
      throw new Error(`更新条目失败: ${updateResult.error}`);
    }
    
    this.testResults.push('✓ 更新条目成功');
    
    // 4. 移动条目
    hilog.info(0, TAG, '测试移动条目...');
    // 首先创建一个目标分组
    const targetGroupParams: GroupCreateParams = {
      name: '个人账号',
      notes: '个人使用的账号',
      parentGroup: rootGroup
    };
    
    const targetGroupResult = this.groupManager!.createGroup(targetGroupParams);
    if (!targetGroupResult.success || !targetGroupResult.data) {
      throw new Error(`创建目标分组失败: ${targetGroupResult.error}`);
    }
    
    const targetGroup = targetGroupResult.data;
    
    const moveResult = this.entryManager.moveEntry(testEntry2, targetGroup);
    if (!moveResult.success) {
      throw new Error(`移动条目失败: ${moveResult.error}`);
    }
    
    this.testResults.push('✓ 移动条目成功');
    
    // 5. 删除条目（删）
    hilog.info(0, TAG, '测试删除条目...');
    const deleteResult = this.entryManager.deleteEntry(testEntry2);
    if (!deleteResult.success) {
      throw new Error(`删除条目失败: ${deleteResult.error}`);
    }
    
    this.testResults.push('✓ 删除条目成功');
    
    hilog.info(0, TAG, '条目CRUD操作测试完成');
  }

  /**
   * 测试复合操作
   */
  private async testComplexOperations(): Promise<void> {
    hilog.info(0, TAG, '开始测试复合操作...');
    
    if (!this.groupManager || !this.entryManager || !this.kdbxCore) {
      throw new Error('管理器未初始化');
    }

    const database = this.kdbxCore.getDatabase();
    if (!database) {
      throw new Error('数据库未加载');
    }

    const rootGroup = database.getDefaultGroup();
    if (!rootGroup) {
      throw new Error('根组不存在');
    }

    // 1. 批量创建分组和条目
    hilog.info(0, TAG, '测试批量创建...');
    
    const categories = ['社交媒体', '银行金融', '购物网站', '游戏娱乐'];
    const createdGroups: KdbxGroup[] = [];
    
    for (const category of categories) {
      const groupParams: GroupCreateParams = {
        name: category,
        notes: `${category}相关账号`,
        parentGroup: rootGroup
      };
      
      const groupResult = this.groupManager.createGroup(groupParams);
      if (!groupResult.success || !groupResult.data) {
        throw new Error(`创建分组 ${category} 失败: ${groupResult.error}`);
      }
      
      createdGroups.push(groupResult.data);
      
      // 为每个分组创建2个条目
      for (let i = 1; i <= 2; i++) {
        const entryParams: EntryCreateParams = {
          title: `${category} 账号 ${i}`,
          username: `user${i}@${category.toLowerCase()}.com`,
          password: `password${i}${category.length}`,
          url: `https://www.${category.toLowerCase()}${i}.com`,
          notes: `${category} 第${i}个账号`,
          parentGroup: groupResult.data
        };
        
        const entryResult = this.entryManager.createEntry(entryParams);
        if (!entryResult.success) {
          throw new Error(`创建条目 ${entryParams.title} 失败: ${entryResult.error}`);
        }
      }
    }
    
    this.testResults.push(`✓ 批量创建成功：${categories.length} 个分组，每个分组 2 个条目`);
    
    // 2. 测试递归删除
    hilog.info(0, TAG, '测试递归删除...');
    const deleteTarget: KdbxGroup = createdGroups[0]; // 删除第一个分组
    const deleteResult = this.groupManager.deleteGroupRecursive(deleteTarget);
    if (!deleteResult.success) {
      throw new Error(`递归删除失败: ${deleteResult.error}`);
    }
    
    this.testResults.push('✓ 递归删除成功');
    
    hilog.info(0, TAG, '复合操作测试完成');
  }

  /**
   * 测试数据完整性
   */
  private async testDataIntegrity(): Promise<void> {
    hilog.info(0, TAG, '开始测试数据完整性...');
    
    if (!this.groupManager || !this.entryManager || !this.kdbxCore) {
      throw new Error('管理器未初始化');
    }

    const database = this.kdbxCore.getDatabase();
    if (!database) {
      throw new Error('数据库未加载');
    }

    const rootGroup = database.getDefaultGroup();
    if (!rootGroup) {
      throw new Error('根组不存在');
    }

    // 1. 统计数据
    const groupsResult = this.kdbxQuery!.getAllGroups();
    if (!groupsResult.success || !groupsResult.data) {
      throw new Error(`获取分组列表失败: ${groupsResult.error}`);
    }
    
    const totalGroups: number = groupsResult.data.length;
    let totalEntries: number = 0;
    
    // 计算总条目数
    for (const group of groupsResult.data) {
      const entriesResult = this.entryManager.getEntriesInGroup(group.uuid.id);
      if (entriesResult.success && entriesResult.data) {
        totalEntries += entriesResult.data.length;
      }
    }
    
    hilog.info(0, TAG, '数据统计: %{public}d 个分组, %{public}d 个条目', totalGroups, totalEntries);
    this.testResults.push(`✓ 数据完整性检查通过：${totalGroups} 个分组，${totalEntries} 个条目`);
    
    // 2. 验证数据库完整性（通过检查数据库是否正常加载）
    if (this.kdbxCore.isLoaded_()) {
      this.testResults.push('✓ 数据库完整性验证通过');
    } else {
      throw new Error('数据库未正常加载，完整性验证失败');
    }
    
    hilog.info(0, TAG, '数据完整性测试完成');
  }

  /**
   * 测试数据持久化 - 保存关闭重新打开验证数据一致性
   */
  private async testDataPersistence(): Promise<void> {
    hilog.info(0, TAG, '开始测试数据持久化...');
    
    if (!this.kdbxCore || !this.kdbxQuery) {
      throw new Error('核心组件未初始化');
    }

    // 1. 记录保存前的数据状态 - 重新统计确保准确性
    const beforeGroups = this.kdbxQuery.getAllGroups();
    if (!beforeGroups.success || !beforeGroups.data) {
      throw new Error(`获取保存前分组数据失败: ${beforeGroups.error}`);
    }
    
    const beforeGroupsCount = beforeGroups.data.length;
    let beforeEntriesCount = 0;
    const beforeEntriesMap = new Map<string, number>(); // groupId -> entryCount
    const beforeGroupDetails: string[] = [];
    
    // 统计每个分组的条目数 - 增加详细日志
    for (const group of beforeGroups.data) {
      const entriesResult = this.entryManager!.getEntriesInGroup(group.uuid.id);
      if (entriesResult.success && entriesResult.data) {
        const count = entriesResult.data.length;
        beforeEntriesCount += count;
        beforeEntriesMap.set(group.uuid.id, count);
        
        const groupInfo = `${group.name || '未命名'}(${count}个条目)`;
        beforeGroupDetails.push(groupInfo);
        hilog.debug(0, TAG, '分组 %{public}s 有 %{public}d 个条目', group.name || '未命名', count);
      }
    }
    
    hilog.info(0, TAG, '保存前数据统计: %{public}d 个分组, %{public}d 个条目', beforeGroupsCount, beforeEntriesCount);
    hilog.info(0, TAG, '分组详情: %{public}s', beforeGroupDetails.join(', '));
    
    // 2. 保存并关闭数据库
    const defaultDb = DefaultDatabase.getInstance();
    const saveResult = await defaultDb.saveDatabase(this.kdbxCore);
    if (!saveResult.success) {
      throw new Error(`最终保存数据库失败: ${saveResult.error}`);
    }
    
    hilog.info(0, TAG, '数据库已保存，准备关闭并重新打开...');
    
    // 验证文件确实存在并且有内容
    const existsCheck = await defaultDb.exists();
    if (!existsCheck) {
      throw new Error('保存验证失败：数据库文件不存在');
    }
    
    // 3. 清理当前数据库连接
    const originalKdbxCore = this.kdbxCore; // 保存原始引用
    // 清理全局引用，避免UI继续使用旧实例
    KdbxCoreManager.getInstance().clearCurrentKdbxCore();
    this.kdbxCore = null;
    this.groupManager = null;
    this.entryManager = null;
    this.kdbxQuery = null;
    
    // 等待一段时间确保保存完成
    await new Promise<void>((resolve) => setTimeout(resolve, 300));
    
    // 4. 重新打开数据库
    hilog.info(0, TAG, '开始重新打开数据库，使用密码验证...');
    const reopenResult = await defaultDb.open(this.databasePassword); // 使用实际密码
    if (!reopenResult.success || !reopenResult.data) {
      // 恢复原始连接
      this.kdbxCore = originalKdbxCore;
      if (this.kdbxCore) {
        const database = this.kdbxCore.getDatabase();
        if (database) {
          this.groupManager = new KdbxGroupManager(database, this.onDatabaseEvent.bind(this));
          this.entryManager = new KdbxEntryManager(database, this.onDatabaseEvent.bind(this));
          this.kdbxQuery = new KdbxQuery(database);
        }
      }
      throw new Error(`重新打开数据库失败: ${reopenResult.error}`);
    }
    
    this.kdbxCore = reopenResult.data;
    // 更新全局KdbxCore，使UI立即使用新的数据库实例
    KdbxCoreManager.getInstance().setCurrentKdbxCore(this.kdbxCore);
    const database = this.kdbxCore.getDatabase();
    if (!database) {
      throw new Error('重新打开后无法获取数据库实例');
    }
    
    // 重新初始化管理器
    this.groupManager = new KdbxGroupManager(database, this.onDatabaseEvent.bind(this));
    this.entryManager = new KdbxEntryManager(database, this.onDatabaseEvent.bind(this));
    this.kdbxQuery = new KdbxQuery(database);
    
    hilog.info(0, TAG, '数据库重新打开成功，开始验证数据...');
    
    // 5. 详细检查重新打开后的原始数据库结构
    await this.logRawDatabaseStructure('重新打开后');
    
    // 6. 验证重新打开后的数据
    const afterGroups = this.kdbxQuery.getAllGroups();
    if (!afterGroups.success || !afterGroups.data) {
      throw new Error(`获取重新打开后分组数据失败: ${afterGroups.error}`);
    }
    
    const afterGroupsCount = afterGroups.data.length;
    let afterEntriesCount = 0;
    const afterGroupDetails: string[] = [];
    
    // 统计重新打开后的条目数 - 增加详细日志
    for (const group of afterGroups.data) {
      const entriesResult = this.entryManager.getEntriesInGroup(group.uuid.id);
      if (entriesResult.success && entriesResult.data) {
        const count = entriesResult.data.length;
        afterEntriesCount += count;
        
        const groupInfo = `${group.name || '未命名'}(${count}个条目)`;
        afterGroupDetails.push(groupInfo);
        
        // 验证每个分组的条目数是否一致
        const beforeCount = beforeEntriesMap.get(group.uuid.id) || 0;
        if (count !== beforeCount) {
          hilog.warn(0, TAG, '分组 %{public}s 条目数不一致: 保存前 %{public}d, 重新打开后 %{public}d', 
            group.name || '未命名', beforeCount, count);
        } else {
          hilog.debug(0, TAG, '分组 %{public}s 条目数一致: %{public}d', group.name || '未命名', count);
        }
      }
    }
    
    hilog.info(0, TAG, '重新打开后数据统计: %{public}d 个分组, %{public}d 个条目', afterGroupsCount, afterEntriesCount);
    hilog.info(0, TAG, '分组详情: %{public}s', afterGroupDetails.join(', '));
    
    // 6. 验证数据一致性
    if (afterGroupsCount !== beforeGroupsCount) {
      hilog.error(0, TAG, '分组数量不一致: 保存前 %{public}d, 重新打开后 %{public}d', beforeGroupsCount, afterGroupsCount);
      throw new Error(`分组数量不一致: 保存前 ${beforeGroupsCount}, 重新打开后 ${afterGroupsCount}`);
    }
    
    if (afterEntriesCount !== beforeEntriesCount) {
      hilog.error(0, TAG, '条目数量不一致: 保存前 %{public}d, 重新打开后 %{public}d', beforeEntriesCount, afterEntriesCount);
      hilog.error(0, TAG, '保存前分组详情: %{public}s', beforeGroupDetails.join(', '));
      hilog.error(0, TAG, '重新打开后分组详情: %{public}s', afterGroupDetails.join(', '));
      
      // 检查是否有条目被移动到回收站
      const recycleBin = this.findRecycleBin();
      if (recycleBin) {
        const recycleBinEntries = this.entryManager.getEntriesInGroup(recycleBin.uuid.id);
        if (recycleBinEntries.success && recycleBinEntries.data) {
          hilog.error(0, TAG, '回收站中的条目数量: %{public}d', recycleBinEntries.data.length);
          if (recycleBinEntries.data.length > 0) {
            hilog.error(0, TAG, '回收站条目: %{public}s', 
              recycleBinEntries.data.map(e => e.title).join(', '));
          }
        }
      }
      
      throw new Error(`条目数量不一致: 保存前 ${beforeEntriesCount}, 重新打开后 ${afterEntriesCount}`);
    }
    
    // 7. 验证特定测试数据是否存在
    const testDataVerification = await this.verifyTestDataExists();
    if (!testDataVerification.success) {
      throw new Error(`测试数据验证失败: ${testDataVerification.error}`);
    }
    
    this.testResults.push(`✓ 数据持久化验证通过：${afterGroupsCount} 个分组，${afterEntriesCount} 个条目保持一致`);
    this.testResults.push('✓ 数据库关闭重新打开后所有测试数据完整保存');
    
    hilog.info(0, TAG, '数据持久化测试完成 - 所有数据验证通过！');
  }

  /**
   * 记录原始数据库结构 - 用于深度调试
   */
  private async logRawDatabaseStructure(stage: string): Promise<void> {
    if (!this.kdbxCore) {
      hilog.warn(0, TAG, '[%{public}s] KdbxCore未初始化', stage);
      return;
    }

    try {
      const database = this.kdbxCore.getDatabase();
      if (!database) {
        hilog.warn(0, TAG, '[%{public}s] 数据库未加载', stage);
        return;
      }

      const rootGroup = database.getDefaultGroup();
      if (!rootGroup) {
        hilog.warn(0, TAG, '[%{public}s] 根分组不存在', stage);
        return;
      }

      // 检查根分组原始属性
      hilog.info(0, TAG, '[%{public}s] 根分组原始属性:', stage);
      hilog.info(0, TAG, '  名称: "%{public}s"', rootGroup.name || 'null');
      hilog.info(0, TAG, '  UUID: %{public}s', rootGroup.uuid?.id || 'null');
      hilog.info(0, TAG, '  子分组数量: %{public}d', rootGroup.groups?.length || 0);
      hilog.info(0, TAG, '  条目数量: %{public}d', rootGroup.entries?.length || 0);

      // 递归检查所有分组的原始属性
      this.logGroupHierarchy(rootGroup, stage, 0);

    } catch (error) {
      hilog.error(0, TAG, '[%{public}s] 记录原始数据库结构失败: %{public}s', stage, (error as Error).message);
    }
  }

  /**
   * 递归记录分组层次结构
   */
  private logGroupHierarchy(group: KdbxGroup, stage: string, depth: number): void {
    const indent = '  '.repeat(depth + 1);
    
    // 记录当前分组
    hilog.info(0, TAG, '[%{public}s] %{public}s分组: "%{public}s" (UUID: %{public}s)', 
      stage, indent, group.name || 'null', group.uuid?.id || 'null');
    
    // 记录分组的条目
    if (group.entries && group.entries.length > 0) {
      for (let i = 0; i < group.entries.length; i++) {
        const entry = group.entries[i];
        const entryTitle = this.getEntryTitle(entry);
        hilog.info(0, TAG, '[%{public}s] %{public}s  条目: "%{public}s" (UUID: %{public}s)', 
          stage, indent, entryTitle || 'null', entry.uuid?.id || 'null');
      }
    }

    // 递归处理子分组
    if (group.groups && group.groups.length > 0) {
      for (let i = 0; i < group.groups.length; i++) {
        this.logGroupHierarchy(group.groups[i], stage, depth + 1);
      }
    }
  }

  /**
   * 记录数据库状态 - 用于调试
   */
  private async logDatabaseState(stage: string): Promise<void> {
    if (!this.kdbxCore || !this.kdbxQuery || !this.entryManager) {
      hilog.warn(0, TAG, '[%{public}s] 核心组件未初始化', stage);
      return;
    }

    try {
      const database = this.kdbxCore.getDatabase();
      if (!database) {
        hilog.warn(0, TAG, '[%{public}s] 数据库未加载', stage);
        return;
      }

      // 获取所有分组
      const groupsResult = this.kdbxQuery.getAllGroups();
      if (!groupsResult.success || !groupsResult.data) {
        hilog.warn(0, TAG, '[%{public}s] 无法获取分组列表: %{public}s', stage, groupsResult.error);
        return;
      }

      const groups = groupsResult.data;
      let totalEntries = 0;
      const groupDetails: string[] = [];

      // 统计每个分组的条目数
      for (const group of groups) {
        const entriesResult = this.entryManager.getEntriesInGroup(group.uuid.id);
        let entryCount = 0;
        let entryTitles: string[] = [];

        if (entriesResult.success && entriesResult.data) {
          entryCount = entriesResult.data.length;
          totalEntries += entryCount;
          entryTitles = entriesResult.data.map(e => this.getEntryTitle(e));
        }

        const groupName = group.name || '未命名';
        const groupInfo = `${groupName}(${entryCount}条目)`;
        if (entryCount > 0) {
          groupDetails.push(`${groupInfo}[${entryTitles.join(',')}]`);
        } else {
          groupDetails.push(groupInfo);
        }
      }

      // 检查回收站
      const recycleBin = this.findRecycleBin();
      let recycleBinInfo = '';
      if (recycleBin) {
        const recycleBinEntries = this.entryManager.getEntriesInGroup(recycleBin.uuid.id);
        if (recycleBinEntries.success && recycleBinEntries.data) {
          recycleBinInfo = ` 回收站: ${recycleBinEntries.data.length}条目`;
        }
      }

      hilog.info(0, TAG, '[%{public}s] 数据库状态: %{public}d个分组, %{public}d条目%{public}s', 
        stage, groups.length, totalEntries, recycleBinInfo);
      hilog.info(0, TAG, '[%{public}s] 分组详情: %{public}s', stage, groupDetails.join(' | '));

    } catch (error) {
      hilog.error(0, TAG, '[%{public}s] 记录数据库状态失败: %{public}s', stage, (error as Error).message);
    }
  }

  /**
   * 查找回收站分组
   */
  private findRecycleBin(): KdbxGroup | null {
    if (!this.kdbxCore) {
      return null;
    }
    
    const database = this.kdbxCore.getDatabase();
    if (!database) {
      return null;
    }
    
    // 尝试获取回收站分组
    const recycleBinUuid = database.meta.recycleBinUuid;
    if (recycleBinUuid) {
      const allGroups = this.kdbxQuery!.getAllGroups();
      if (allGroups.success && allGroups.data) {
        return allGroups.data.find(group => group.uuid.id === recycleBinUuid.id) || null;
      }
    }
    
    return null;
  }

  /**
   * 验证测试数据是否存在
   */
  private async verifyTestDataExists(): Promise<OperationResult<void>> {
    try {
      if (!this.kdbxQuery || !this.entryManager) {
        return {
          success: false,
          error: '查询组件未初始化',
          errorCode: 'QUERY_NOT_INITIALIZED'
        };
      }

      // 验证是否存在测试创建的分组
      const allGroups = this.kdbxQuery.getAllGroups();
      if (!allGroups.success || !allGroups.data) {
        return {
          success: false,
          error: '无法获取分组列表',
          errorCode: 'GET_GROUPS_FAILED'
        };
      }
      
      const groupNames = allGroups.data.map(g => g.name || '');
      const expectedGroups = ['工作账号 (已更新)', '个人账号', '银行金融', '购物网站', '游戏娱乐'];
      const missingGroups: string[] = [];
      
      for (const expectedGroup of expectedGroups) {
        if (!groupNames.includes(expectedGroup)) {
          missingGroups.push(expectedGroup);
        }
      }
      
      if (missingGroups.length > 0) {
        return {
          success: false,
          error: `缺失预期分组: ${missingGroups.join(', ')}`,
          errorCode: 'MISSING_GROUPS'
        };
      }
      
      // 验证是否存在测试条目
      let foundTestEntries = 0;
      for (const group of allGroups.data) {
        const entriesResult = this.entryManager.getEntriesInGroup(group.uuid.id);
        if (entriesResult.success && entriesResult.data) {
          for (const entry of entriesResult.data) {
            const entryTitle = this.getEntryTitle(entry);
            if (entryTitle.includes('测试') || entryTitle.includes('账号')) {
              foundTestEntries++;
            }
          }
        }
      }
      
      if (foundTestEntries === 0) {
        return {
          success: false,
          error: '未找到任何测试条目',
          errorCode: 'NO_TEST_ENTRIES'
        };
      }
      
      hilog.info(0, TAG, '数据验证通过: 找到 %{public}d 个预期分组, %{public}d 个测试条目', 
        expectedGroups.length, foundTestEntries);
      
      return {
        success: true
      };
      
    } catch (error) {
      return {
        success: false,
        error: (error as Error).message,
        errorCode: 'VERIFICATION_ERROR'
      };
    }
  }

  /**
   * 保存数据库
   */
  private async saveDatabase(): Promise<void> {
    hilog.info(0, TAG, '开始保存数据库...');
    
    if (!this.kdbxCore) {
      throw new Error('数据库未初始化');
    }

    try {
      // 记录保存前的状态
      const database = this.kdbxCore.getDatabase();
      if (!database) {
        throw new Error('无法获取数据库实例');
      }

      // 使用DefaultDatabase保存数据库到文件
      const defaultDb = DefaultDatabase.getInstance();
      const saveResult = await defaultDb.saveDatabase(this.kdbxCore);
      if (!saveResult.success) {
        throw new Error(`保存数据库失败: ${saveResult.error}`);
      }
      
      // 验证保存是否成功 - 检查文件是否确实存在且有内容
      await new Promise<void>((resolve) => setTimeout(resolve, 150)); // 等待150ms确保文件写入完成
      
      const verifyResult = await defaultDb.exists();
      if (!verifyResult) {
        throw new Error('保存验证失败：数据库文件不存在');
      }
      
      hilog.info(0, TAG, '数据库保存成功，文件路径: %{public}s', saveResult.data || 'unknown');
      
      // 记录保存后的状态（用于调试）
      if (this.kdbxQuery && this.entryManager) {
        const afterSaveGroups = this.kdbxQuery.getAllGroups();
        if (afterSaveGroups.success && afterSaveGroups.data) {
          let totalEntries = 0;
          for (const group of afterSaveGroups.data) {
            const entriesResult = this.entryManager.getEntriesInGroup(group.uuid.id);
            if (entriesResult.success && entriesResult.data) {
              totalEntries += entriesResult.data.length;
            }
          }
          hilog.info(0, TAG, '保存后数据验证: %{public}d个分组, %{public}d条目', 
            afterSaveGroups.data.length, totalEntries);
        }
      }
      
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      hilog.error(0, TAG, '保存数据库时发生错误: %{public}s', errorMsg);
      throw new Error(errorMsg);
    }
  }

  /**
   * 打印测试结果
   */
  private printTestResults(): void {
    hilog.info(0, TAG, '=== 测试结果汇总 ===');
    for (const result of this.testResults) {
      hilog.info(0, TAG, result);
    }
    hilog.info(0, TAG, '=== 测试结果汇总结束 ===');
  }

  /**
   * 清理测试环境
   */
  async cleanup(): Promise<void> {
    try {
      hilog.info(0, TAG, '开始清理测试环境...');
      
      // 注意：不清理kdbxCore引用，因为主程序还需要使用它
      this.groupManager = null;
      this.entryManager = null;
      this.kdbxQuery = null;
      this.testResults = [];
      
      // 注意：不删除数据库，保留测试结果
      hilog.info(0, TAG, '测试环境清理完成，数据库已保留');
      
    } catch (error) {
      hilog.error(0, TAG, '清理测试环境失败: %{public}s', (error as Error).message);
    }
  }
}

/**
 * 执行完整的数据库CRUD测试
 */
export async function runDatabaseCRUDTest(context: Context, existingKdbxCore?: KdbxCore, password?: string): Promise<boolean> {
  const test = new DatabaseCRUDTest();
  
  try {
    // 初始化测试环境
    if (!(await test.initializeTest(context, existingKdbxCore, password))) {
      return false;
    }
    
    // 运行测试
    const result = await test.runFullCRUDTest();
    
    // 清理测试环境
    await test.cleanup();
    
    return result;
    
  } catch (error) {
    hilog.error(0, TAG, '测试执行失败: %{public}s', (error as Error).message);
    await test.cleanup();
    return false;
  }
} 